
local http = require 'lib.http'
local str = require 'resty.string'
local resty_sha1 = require 'resty.sha1'

local to_json = (require 'lapis.util').to_json
local from_json = (require 'lapis.util').from_json

local bucketID = os.getenv('BB_BUCKETID')


local accountID, authKey = os.getenv('BB_ACCOUNTID'), os.getenv('BB_KEY')
if not accountID then
  ngx.log(ngx.ERR, 'couldnt find backblaze account id in env variable')
end
if not authKey then
  ngx.log(ngx.ERR, 'couldnt find backblaze account id in env variable')
end

local bb = {}
local authToken
local apiUrl
local authedAt
local uploadAuthedAt, uploadToken, uploadUrl
local downloadUrl


local function GetHash(values)
  local sha1 = resty_sha1:new()

  local ok, err = sha1:update(values)
  if not ok then
    ngx.log(ngx.ERR, 'unable to sha1: ',err)
    return nil
  end

  local digest = sha1:final()

  return str.to_hex(digest)
end

function bb:GetAuthToken()
  local currTime = ngx.time()
  if authedAt and authedAt > (currTime - 86400) then
    return
  end


  local httpc = http.new()

  local authUrl = 'https://api.backblaze.com/b2api/v1/b2_authorize_account'
  local authstring = 'Basic '..ngx.encode_base64(accountID..':'..authKey)

  local res, err = httpc:request_uri(authUrl, {
    method = 'GET',
    headers = {
      Authorization = authstring
    }
  })
  if (res.status ~= 200) then
    return nil, 'failed to auth: '..(res and res.status)
  end

  authedAt = currTime

  local body = from_json(res.body)
  apiUrl = body.apiUrl
  authToken = body.authorizationToken
  downloadUrl = body.downloadUrl

  return true

end

function bb:GetDownloadUrl()
  if not downloadUrl then
    local ok, err = self:GetAuthToken()
    if not ok then
      return ok, err
    end
  end

  return downloadUrl
end

function bb:GetUploadUrl()
  local currTime = ngx.time()
  if uploadAuthedAt and uploadAuthedAt > (currTime - 86400) then
    return
  end

  local httpc = http.new()

  local res, err = httpc:request_uri(apiUrl..'/b2api/v1/b2_get_upload_url', {
    method = 'POST',
    headers = {
      Authorization = authToken
    },
    body = to_json({bucketId = bucketID})
  })
  if (res and res.status ~= 200) then
    return nil, 'failed to auth: '
  end

  uploadAuthedAt = currTime

  local body = from_json(res.body)
  uploadToken = body.authorizationToken
  uploadUrl = body.uploadUrl
  return true
end

function bb:Upload(fileName, fileContent)

  local httpc = http.new()
  local res, err = httpc:request_uri(uploadUrl, {
    method = 'POST',
    headers = {
      Authorization = uploadToken,
      ['X-Bz-File-Name'] = fileName,
      ['Content-Type'] = 'b2/x-auto',
      ['Content-Length'] = #fileContent,
      ['X-Bz-Content-Sha1'] = GetHash(fileContent)

    },
    body = fileContent
  })
  if not res then
    print(err)
    return nil, err
  end
  if (res and res.status ~= 200) then
    print(res.body)
    return nil, 'failed to auth: '
  end
  local body = from_json(res.body)
  return body.fileId
end

function bb:UploadImage(fileName, fileContent)
  -- check filename
  local ok, err = self:GetAuthToken()
  if not ok then
    ngx.log(ngx.ERR, 'err')
    return nil, err
  end

  ok, err = self:GetUploadUrl()
  if not ok then
    ngx.log(ngx.ERR, 'err')
    return nil, err
  end

  ok, err = self:Upload(fileName, fileContent)
  if not ok then
    ngx.log(ngx.ERR, 'err')
    return nil, err
  end

  return ok

end

function bb:GetImageFromBB(imageID)
  local httpc = http.new()
  httpc:set_timeout(10000)
  local res, err = httpc:request_uri(downloadUrl..'/b2api/v1/b2_download_file_by_id?fileId='..imageID, {
    headers = {
      Authorization = authToken,
    },
    --query = '?fileId='..imageID
  })

  --print(to_json(res.headers))
  if not res or res.status ~= 200 then
    print(res and res.status, err)
    return nil, err
  end
  --print(to_json(res))
  local imageInfo = {
    ['Content-Type'] = res.headers['Content-Type'],
    filename = res.headers['x-bz-file-name'],
    data = res.body
  }

  return imageInfo, err
end

function bb:GetImage(imageID)

  local ok, err = self:GetAuthToken()
  if not ok then
    ngx.log(ngx.ERR, 'err')
    return nil, err
  end

  ok, err = self:GetImageFromBB(imageID)
  return ok, err
end

return bb
