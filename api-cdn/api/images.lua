


local cache = require 'api.cache'


local base = require 'api.base'
local api = setmetatable({}, base)
local bb = require('lib.backblaze')


local allowedExtensions = {
  ['.mp4'] = 'vid',
  ['.gif'] = 'vid',
  ['.png'] = 'pic',
  ['.jpg'] = 'pic',
  ['.jpeg'] = 'pic'
}

function api:GetImage(imageID)


  -- all our images are jpeg

  local image = cache:GetImage(imageID)
  if image then
    return image
  end

  local imageInfo, err = bb:GetImage(imageID)
  if not imageInfo then
    print(err)
    return nil
  end
  cache:SetImage(imageID, imageInfo.data)
  return imageInfo.data

end

function api:CreateImage(userID, fileData)
  --[[
    upload the image to backblaze
    create the imageinfo in redis
    send back the image id
    could use backblaze id and shorturl or generate id

  ]]

  local ok, err = self:RateLimit('UploadImage:', userID, 40,120)
	if not ok then
		return ok, err
	end

  --check image size


  local uuid = require 'lib.uuid'

  local file = {
    createdBy = userID,
    createdAt = ngx.time(),
    views = 0,
    bandwidth = 0,
    id = uuid.generate_random()
  }


  local fileExtension = fileData.filename:match("^.+(%..+)$")
  if not allowedExtensions[fileExtension] then
    return nil, 'invalid file type'
  end

  file.extension = fileExtension
  local rawID, err = bb:UploadImage(file.id..fileExtension, fileData.content)
  if not rawID then
    ngx.log(ngx.ERR, 'file upload failed: ', err)
    return nil, 'error uploading file'
  end
  file.rawID = rawID

  ok, err = self.redisWrite:CreateImage(file)
  if not ok then
    return ok, err
  end
  ok, err = self.redisWrite:QueueJob('ConvertImage', file)

  return ok, err
end

return api
