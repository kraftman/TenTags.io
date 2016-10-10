

local chunk_size = 4096
local dataDir = "/var/www/icons/"


local function my_get_file_name()
  return '/var/www/icons/test'..math.random(100000)..'.jpg'

end

local m = {}

m.restyUpload = require "resty.upload"

function m:GetFileNameFromFormHeader(fileInfo,res)
  local fileName
  for _,header in pairs(res) do
    fileName = header:find('filename="(.-)"')
    if fileName then
      fileInfo.fileName,fileInfo.fileExtension = header:match('filename="(.+)(%..+)"')
      -- deal with lack of file extension
      if not fileInfo.fileName then
        fileInfo.fileName = header:match('filename="(.+)"')
        fileInfo.fileExtension = ''
      end
    end
  end
end


function m:WriteFormUpload(fileInfo,fileDirectory)
  local file
  local fileLocation
  local form,err = self.restyUpload:new(chunk_size)

  if not form then
    ngx.log(ngx.ERR, 'unable to load form: ',err)
    error(400018)
  end

  while true do
    local typ, res
    typ, res, err = form:read()

    if err then
      ngx.log(ngx.ERR, 'error reading from form: ',err)
      error(500001)
    end

    if typ == "header" then
      self:GetFileNameFromFormHeader(fileInfo,res)

      if fileInfo.fileName and (not file) then
        fileLocation = fileDirectory..fileInfo.fileName..fileInfo.fileExtension
        file,err = io.open(fileLocation,'w+')
        if not file then
          ngx.log(ngx.ERR,err)
          error(500001)
        end
      end
    elseif typ == "body" then
      if file then
        file:write(res)
      end
    elseif typ == "part_end" then
      if file then
        fileInfo.size = file:seek("end")
        file:close()
        file = nil
      end
    else
      break
    end
  end
end

function m:GetFileNameFromHeader(fileInfo, headers)
  for header,value in pairs(headers) do
    header = header:lower()
    if header == 'content-disposition' then

      fileInfo.fileName,fileInfo.fileExtension =
          value:match('filename="(.+)(%..+)"')
      if not fileInfo.fileName then
        fileInfo.fileName = value:match('filename="(.+)"')
        fileInfo.fileExtension = ''
      end
      return
    end
  end
end

function m:WriteChunkedUpload(fileInfo,fileDirectory)

  local saveLocation = fileDirectory..fileInfo.fileName..fileInfo.fileExtension
  ngx.req.read_body()
  local memData = ngx.req.get_body_data()
  local file

  if memData then
    print('writing memdata')
    file = io.open(saveLocation, 'w+')
    file:write(memData)
  else
    print('copying file')
    local fileLocation = ngx.req.get_body_file()
    if fileLocation then
      print('body file found')
      os.execute('cp '..fileLocation..' '..saveLocation)
      file = io.open(saveLocation, 'r')
    else
      ngx.log(ngx.ERR, 'no body file found')
      error(400004)
    end
  end

  local size = file:seek('end')
  file:close()
  fileInfo.size = size
end

function m:CreateFileDirectory(fileID)
  fileID = fileID..''
  local a,b,c = fileID:match('^(.)(.)(.)')
  local splitPath = (a..'/'..a..b..'/'..a..b..c..'/')

  --local msg = io.popen('mkdir -p '..dataDir..splitPath):read('*all')
  if msg and msg ~= '' then
    --ngx.log(ngx.ERR, msg,type(msg))
  end
  return dataDir--..splitPath
end



function m:Run()
  local headers = ngx.req.get_headers()
  local fileInfo = {fileID = math.random(2030000000),createdAt = ngx.time()}
  local fileDirectory = self:CreateFileDirectory(fileInfo.fileID)
  if headers['Transfer-Encoding'] or (headers['content-length']
    and not (headers['content-type']:lower():find('multipart'))) then
      ngx.log(ngx.ERR, 'chunked')
    self:GetFileNameFromHeader(fileInfo, headers)
    self:WriteChunkedUpload(fileInfo,fileDirectory)
  else
    ngx.log(ngx.ERR, 'form')
    self:WriteFormUpload(fileInfo,fileDirectory)
  end
end

return m
