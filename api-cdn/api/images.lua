


local cache = require 'api.cache'


local base = require 'api.base'
local api = setmetatable({}, base)
local bb = require('lib.backblaze')


local allowedExtensions = {
  ['.gif'] = true,
  ['.png'] = true,
  ['.jpg'] = true,
  ['.jpeg'] = true
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

function api:UploadImage(userID, fileData)
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


  local uuid = require 'lib.uuid'

  local file = {
    createdBy = userID,
    createdAt = ngx.time(),
    views = 0,
    bandwidth = 0,
    id = uuid.generate_random()
  }


  local fileExtension = file.filename:match("^.+(%..+)$")
  if not allowedExtensions[fileExtension] then
    return nil, 'invalid file type'
  end
  local bbID, err = bb:UploadImage(file.id..fileExtension, fileData.content)
  if not bbID then
    ngx.log(ngx.ERR, 'file upload failed: ', err)
    return nil, 'error uploading file'
  end
  file.bbID = bbID

  ok, err = self.redisWrite:CreateImage(file)
  if not ok then
    return ok, err
  end
  ok, err = self.redisWrite:QueueJob('CreateImage', file)

  return ok, err
end

return api
