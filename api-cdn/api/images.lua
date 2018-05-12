
local app_helpers = require("lapis.application")
local cache = require 'api.cache'
local base = require 'api.base'
local bb = require 'lib.backblaze'
local uuid = require 'lib.uuid'

local api = setmetatable({}, base)

local assert_error = app_helpers.assert_error

local allowedExtensions = {
  ['.mp4'] = 'vid',
  ['.mkv'] = 'vid',
  ['.gif'] = 'vid',
  ['.png'] = 'pic',
  ['.jpg'] = 'pic',
  ['.jpeg'] = 'pic'
}

function api:GetImage(imageID)
  if not imageID or imageID:gsub(' ', '') == '' then
    return nil, 'image not found'
  end

  -- all our images are jpeg

  local image = cache:GetImage(imageID)
  if image then
    return image
  end
  return nil, 'image not found'
  --
  -- local imageInfo, err = bb:GetImage(imageID)
  -- if not imageInfo then
  --   print(err)
  --   return nil
  -- end
  -- cache:SetImage(imageID, imageInfo.data)
  -- return imageInfo.data

end

function api:GetPendingTakedowns(userID, limit)
  local user = cache:GetUser(userID)
  if not user or user.role ~= 'Admin' then
    return nil, 'access denied'
  end
  limit = limit or 10
  local ok = assert_error(self.redisRead:GetPendingTakedowns(limit))

  local takedowns = {}
  local request
  for _, v in pairs(ok) do
    request = assert_error(self.redisRead:GetTakedown(v))
    takedowns[#takedowns+1] = request
  end

  return takedowns
end

function api:AcknowledgeTakedown(userID, requestID)
  local user = cache:GetUser(userID)
  if not user or user.role ~= 'Admin' then
    return nil, 'access denied'
  end

  return assert_error(self.redisWrite:AcknowledgeTakedown(requestID))
end

function api:BanImage(userID, requestID)
  local user = cache:GetUser(userID)
  if not user or user.role ~= 'Admin' then
    return nil, 'access denied'
  end

  local request = assert_error(self.redisRead:GetTakedown(requestID))
  local image = assert_error(cache:GetImage(request.imageID))

  image.banned = 1
  return assert_error(self.redisWrite:CreateImage(image))
  --TODO purge cache too
end

function api:SubmitTakedown(userID, imageID, takedownText)

  if not takedownText or takedownText:gsub(' ','') == '' then
    return nil, 'please provide details'
  end
  if #takedownText < 10 then
    return nil, 'please provide more information'
  end

  local request = {
    createdAt = ngx.time(),
    createdBy = userID,
    reason = takedownText,
    id = uuid.generate_random(),
    imageID = imageID
  }

  -- create the takedown
  assert_error(self.redisWrite:IncrementSiteStat('takedownRequests', 1))
  assert_error(self.redisWrite:CreateTakedown(request))

  local image = assert_error(cache:GetImage(imageID))

  -- add the takedown to the image
  image.takedowns[#image.takedowns+1] = request.id
  return assert_error(self.redisWrite:CreateImage(image))
end

function api:GetImageDataByBBID(_, bbID)

  --TODO move this all to cache?
  local imageData = cache:GetImageData(bbID)
  if imageData then
    print('got from cache')
    return imageData
  end

  imageData = assert_error(bb:GetImage(bbID))

  assert_error(cache:SetImageData(bbID, imageData))

  return imageData

end

function api:GetImageData(_, imageID, imageSize)


  local image = self:GetImage(imageID)
  local bbID = image.rawID

  if imageSize and image[imageSize] then
    bbID = image[imageSize]
  elseif image.imgID then
    bbID = image.imgID
  else
    print('using raw')
  end


  --TODO move this all to cache?
  local err
  local imageData = cache:GetImageData(bbID)
  if imageData then
    return imageData
  end

  imageData, err = bb:GetImage(bbID)

  if not imageData then
    ngx.log(ngx.ERR, 'error retrieving image from bb: ',err)
    return nil, 'couldnt load image'
  end

  cache:SetImageData(bbID, imageData)

  return imageData

end


function api:AddText(userID, imageID, text)


  text = self:SanitiseUserInput(text, 400)

  local image = cache:GetImage(imageID)

  if image.createdBy ~= userID then
    local user = cache:GetUser(userID)
    if user.role  ~= 'Admin' then
        return nil, 'need to be adming to do that'
    end
  end

  image.text = text

  return assert_error(self.redisWrite:CreateImage(image))

end

function api:CreateImage(userID, fileData)
  --[[
    upload the image to backblaze
    create the imageinfo in redis
    send back the image id
    could use backblaze id and shorturl or generate id

  ]]



  --check image size

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

  file.type = allowedExtensions[fileExtension]

  file.extension = fileExtension
  local rawID = assert_error(bb:UploadImage(file.id..fileExtension, fileData.content))

  file.rawID = rawID

  self.redisWrite:CreateImage(file)

  self.redisWrite:QueueJob('ConvertImage', file)
  return file

end

function api:ReloadImage(userID, imageID)
  local user = cache:GetUser(userID)
  if not user or user.role ~= 'Admin' then
    return nil, 'no auth'
  end

  local image = cache:GetImage(imageID)

  return assert_error(self.redisWrite:QueueJob('ConvertImage', image))

end

return api
