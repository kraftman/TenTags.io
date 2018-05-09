


local redis = require 'redis'
local socket = require 'socket'

require("ssl")
local cjson = require('cjson')
local bb = require 'lib.backblaze'
local uuid = require 'lib.uuid'

local imgurHandler = require 'handlers.imgur'
local gfycatHandler = require 'handlers.gfycat'
local websiteHandler = require 'handlers.website'
local utils = require 'utils'

local redisURL, redisPort
if os.getenv('REDIS_GENERAL_WRITE') then
  print( os.getenv('REDIS_GENERAL_WRITE'))
  redisURL, redisPort = os.getenv('REDIS_GENERAL_WRITE'):match('(.+):(%d+)')
else
  redisURL, redisPort = 'redis-general', '6379'
end

local red, rederr = redis.connect(redisURL, redisPort)
if not red then
  print(rederr)
end

local loader = {}

function loader:LoadPost(postID)

  local post, err = red:hgetall('post:'..postID)

  if not post or (next(post) == nil) then
    print('error loading post: ',postID,' ', err)
    return nil, err
  end
  if not post.link then
    print('no post link found!')
    return true
  end
  -- if post.bbID then
  --   return post.bbID
  -- end
  return post
end

function loader:GetBBImage(bbID, postID)
  local imageInfo =  bb:GetImage(bbID)
  imageInfo.image =  assert(magick.load_image_from_blob(imageInfo.data))
  return imageInfo
end

function loader:GetPostIcon(postURL, postID)

  local finalImage
  if postURL:find('imgur.com') then
      return imgurHandler:Process(postURL, postID)
  elseif postURL:find('gfycat.com/%w+') then
    finalImage = gfycatHandler:Process(postURL)
  elseif not postURL:find('http') then
    finalImage  = self:GetBBImage(postURL, postID)
  else
    finalImage = websiteHandler:Process(postURL, postID)
  end

	if not finalImage then
		return nil, 'no final image!'
  end

  finalImage.data = finalImage.image
  finalImage.image:set_format('jpg')
  finalImage.image:set_quality(90)

  local newID = uuid.generate_random()

  local id,err = utils:SendImage(finalImage.image:get_blob(), newID..'b')
  if not id then
    print('couldnt send image: ',err)
    return nil, err
  end

  finalImage.image:resize_and_crop(1000,1000)
  local ok, err = self:AddImage(postID, 'bigIcon', id)
  if not ok then
    print('couldnt add bigicon: ', err)
    return ok, err
  end
  finalImage.image:resize_and_crop(100,100)

  id , err = utils:SendImage(finalImage.image:get_blob(), newID)
  if not id then
    print('couldnt send small image:', err)
    return nil, err
  end

  ok, err = utils:AddImage(postID, 'smallIcon', id)
  if not ok then
    print('couldnt add small image to post: ', err)
    return ok, err
  end
  return true
end

function loader:ProcessPostIcon(post)
  local fullPost, err = self:LoadPost(post.id)
  if not fullPost.link then
    return true, err
  end

  local ok, err = self:GetPostIcon(fullPost.link, post.id)
  if not ok then
     return nil, err
  end
  print('got post icon')
  return true
end

function loader:GetUpdates(queueName)
  local ok, err = red:zrevrange(queueName, 0, 10)
  if not ok then
    return ok, err
  end
  for k,v in pairs(ok) do
    red:zrem(queueName,v)
    ok[k], err = cjson.decode(v)
  end

  return ok, err
end


function loader:Requeue(queueName, postInfo)
  -- add retries
  postInfo.retries = postInfo.retries or 0
  postInfo.retries = postInfo.retries + 1
  if postInfo.retries > 3 then
    --give up
    return
  end

  local delay = postInfo.retries * 30

  local ok, err = red:zadd(queueName, delay, cjson.encode(postInfo))
  if not ok then
    print('error requueuing: ',err)
  end
  return ok, err
end

function loader:GetNextJob(queueName, job)
  local updates, ok, err

  updates, err = self:GetUpdates(queueName)
  if not updates then
    print('couldnt load updates: ', err)
    return
  end

  for _,postUpdate in pairs(updates) do

    ok, err = self[job](self,postUpdate)
    local socket = require 'socket'
    if not ok then
      print('couldnt req: ', err)
      self:Requeue(queueName, postUpdate)
    end
 end
end

--=====================================================

while true do
  socket.sleep(5)
  print('checking')

  if not red then
     red, rederr = redis.connect(redisURL, redisPort)
    if not red then
      print(rederr)
    end
  end


  local status, err = pcall(function() loader:GetNextJob('queue:GeneratePostIcon', 'ProcessPostIcon') end)

  if not status then
    print(err)
  end

  status, err = pcall(function() loader:GetNextPost('queue:ConvertImage', 'ConvertImage') end)

  if not status then
    print(err)
  end


end
