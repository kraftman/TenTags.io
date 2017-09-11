


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

function api:GetImageData(userID, imageID, imageSize)
  print('getting image data')
  local ok, err = self:RateLimit('GetImageData:', userID, 10,300)
  if not ok then
    return ok, err
  end

  local image, err = self:GetImage(imageID)
  if not image then
    ngx.log(ngx.ERR, 'couldnt load')
    return nil, 'no image found'
  end

  local bbID = image.rawID
  if imageSize and image[imageSize] then
    print('getting correct size')
    bbID = image[imageSize]
  elseif image.imgID then
    print('falling back to img')
    bbID = image.imgID
  else
    print('using raw')
  end

  local imageData, err = bb:GetImage(bbID)
  if not imageData then
    ngx.log(ngx.ERR, 'error retrieving image from bb: ',err)
    return nil, 'couldnt load image'
  end

  return imageData

end


function api:AddText(userID, imageID, text)

  local ok, err = self:RateLimit('EditImageText:', userID, 40,60)
  if not ok then
    return ok, err
  end

  text = self:SanitiseUserInput(text, 400)

  local image = cache:GetImage(imageID)
  if not image then
    print('couldnt find image: ',imageID)
    return nil, 'image not found'
  end

  if image.createdBy ~= userID then
    local user = cache:GetUser(userID)
    if user.role  ~= 'Admin' then
        return nil, 'need to be adming to do that'
    end
  end

  image.text = text

  ok, err = self.redisWrite:CreateImage(image)

  return ok, err


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
  fileExtension = fileExtension:lower()
  print(fileExtension)
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
  if not ok then
    return ok, err
  end

  return file, err
end

return api
