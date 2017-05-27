


local magick = require 'magick'
local redis = require 'redis'

local http = require("socket.http")
local ltn12 = require("ltn12")
local giflib = require("giflib")
local cjson = require('cjson')
local bb = require 'lib.backblaze'
local uuid = require 'lib.uuid'

--[[
local redisURL = 'localhost'
local redisPort = '16379'
local imgHostURl = 'localhost'
local imgHostPort = '81'
--]]
local redisURL, redisPort
if os.getenv('REDIS_GENERAL_WRITE') then
  print( os.getenv('REDIS_GENERAL_WRITE'))
  redisURL, redisPort = os.getenv('REDIS_GENERAL_WRITE'):match('(.+):(%d+)')
else
  redisURL, redisPort = 'redis-general', '6379'
end

local red, err = redis.connect(redisURL, redisPort)
if not red then
  print(err)
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
  if post.bbID then
    return post.bbID
  end
  return post.link
end


function loader:LoadImage(imageLink)
  local res, c = http.request ( imageLink )

	if c ~= 200 then
		--print(' cant laod image: ',imageInfo.link, ' err: ',err)
    print(c)
		return nil, 'cant load image:'
	end
	--print(imageInfo.link, type(res.body), res.body)
	if res:len() > 0 then
		return res
	else
		print ('empty image')
	end

	return nil, 'empty image'
end

function loader:GetImageLinks(res)
  local imageLinks = {}
  --print(res)
	for imgTag in res:gmatch('<img.-src=[\'"](.-)[\'"].->') do
		if imgTag:find('^//') then
			imgTag = 'http:'..imgTag
      print('found: ',imgTag)
		else
      print(imgTag)
    end
		table.insert(imageLinks, {link = imgTag})
	end

  return imageLinks
end

function loader:SendImage(image, imageName)
  local id, err = bb:UploadImage(image, imageName..'.png')
  print(id, err)
  return id, err
end

function loader:AddImgURLToPost(postID, imgURL)
  red:hset('post:'..postID,'imgURL', imgURL)
  return true
end

function loader:ProcessImgur(postURL, postID)
  local handle = io.popen('python pygur.py '..postURL..' '..postID)
  local imgURL = handle:read("*a")
  imgURL = imgURL:gsub('\n','')
  imgURL = imgURL:gsub('\r','')
  imgURL = imgURL:gsub(' ','')
  handle:close()
  print('adding ',imgURL,' to post')
  self:AddImgURLToPost(postID, imgURL)


  local image = magick.load_image('/lua/out/'..postID..'.jpg')
  if not image then
    print('couldnt load image for :',postID)
    return nil, 'unable to load image from file'
  end
  image:coalesce()
  image:set_format('png')
  --finalImage.image:write('/lua/out/p2-'..postID..'.png')
  --finalImage.image = magick.load_image('/lua/out/p2-'..postID..'.png')
  local newID = uuid.generate_random()
  local id, err = self:SendImage(image,newID..'b')
  if not id then
    print('error sending image: ',err)
    return nil, 'couldnt send imgur full image'
  end
  local ok

  image:resize_and_crop(1000,1000)
  ok, err = self:AddImage(postID, 'bigIcon', id)
  if not ok then
    print('error sending image: ',err)
    return ok, err
  end
  image:resize_and_crop(200,200)
  id, err = self:SendImage(image,newID)
  if not id then
    print('error sending image: ',err)
    return nil, 'couldnt send imgur thumb image'
  end

  ok, err = self:AddImage(postID, 'bigIcon', id)
  if not ok then
    print('error sending image: ',err)
    return ok, err
  end
  os.remove('out/'..postID..'.jpg')


  return true

end

function loader:ProcessGfycat(postURL)
  local gfyName = postURL:match('gfycat.com/(%w+)')
  local newURL = 'http://thumbs.gfycat.com/'..gfyName..'-poster.jpg'
  print(newURL)
  local imageBlob, err = self:LoadImage(newURL)
  if not imageBlob then
    return imageBlob, err
  end

  local loadedImage  = assert(magick.load_image_from_blob(imageBlob))

  return {link = newURL, image = loadedImage}

end

function loader:IsImage(headers)
  local contentTypes = {}
  contentTypes['image/gif'] = true
  contentTypes['image/jpeg'] = true
  contentTypes['image/tiff'] = true
  contentTypes['image/png'] = true

  local resContentType = headers['content-type']
  print(resContentType)

  if contentTypes[resContentType] then
    return true
  end

  return false
end

function loader:NormalPage(postURL, postID)

    local res, c, h = http.request ( postURL )
    print(postURL)
    if not res then
      print(res, err)
      return res, err

    end
    if c ~= 200 then
      print(c, ' ', res)
    end

    local imageLinks
    if postURL:find('.gif') or postURL:find('.jpg') or postURL:find('.jpeg') or postURL:find('.png') then
      imageLinks = {{link = postURL}}
    elseif self:IsImage(h) then
      print('its an content-type image')
      imageLinks = {{link = postURL}}
    else
      imageLinks = self:GetImageLinks(res)
    end

    for _, imageInfo in pairs(imageLinks) do
  		local imageBlob = self:LoadImage(imageInfo.link)
  		imageInfo.size = 0
  		if imageBlob then
          imageInfo.blob = imageBlob
  			local image = assert(magick.load_image_from_blob(imageBlob))

  			if image then
  				imageInfo.image = image
  				local w,h = image:get_width(), image:get_height()
  				imageInfo.size = w*h
  			end
  		end
  	end

  	table.sort(imageLinks, function(a,b) return a.size > b.size end)

  	local finalImage

  	for _,v in ipairs(imageLinks) do
  		if v.image then
  			finalImage = v
  			break
  		end
  	end


	if finalImage.link:find('.gif') then
    local tempGifLoc = '/lua/out/tempgif-'..postID..'.gif'
    --finalImage.image:write(tempGifLoc)
    local file = io.open(tempGifLoc, 'w+')
    file:write(finalImage.blob)
    file:close()
    print('wrote gif')

    local gif = assert(giflib.load_gif(tempGifLoc))
    print('loaded gif')
    gif:write_first_frame('/lua/out/processedgif-'..postID..'.gif')
    print('load first frame')
    gif:close()
    finalImage.image = magick.load_image('/lua/out/processedgif-'..postID..'.gif')
    finalImage.image:coalesce()
    finalImage.image:set_format('png')
    finalImage.image:write('/lua/out/p2-'..postID..'.png')
    finalImage.image = magick.load_image('/lua/out/p2-'..postID..'.png')

    os.remove(tempGifLoc)
    os.remove('/lua/out/processedgif-'..postID..'.gif')
    os.remove('/lua/out/p2-'..postID..'.png')

	end

  return finalImage
end

function loader:AddImage(postID, key, bbID)
  local ok, err = red:hset('post:'..postID, key, bbID)
  return true
end

function loader:GetBBImage(bbID, postID)
  local imageInfo =  bb:GetImage(bbID)
  imageInfo.image =  assert(magick.load_image_from_blob(imageInfo.data))
  return imageInfo
end

function loader:GetPostIcon(postURL, postID)

  local finalImage
  if postURL:find('imgur.com') then
    if postURL:find('.gif') or postURL:find('gallery') or postURL:find('.jpg') or postURL:find('.jpeg') or postURL:find('.png') then
      return self:ProcessImgur(postURL, postID)
    end
    return nil, 'imgur gallery'
  elseif postURL:find('gfycat.com/%w+') then
    finalImage = self:ProcessGfycat(postURL)
  elseif not postURL:find('http') then
    finalImage  = self:GetBBImage(postURL, postID)
  else
    finalImage = self:NormalPage(postURL, postID)
  end

	if not finalImage then
		return nil, 'no final image!'
	end

  finalImage.image:set_format('png')
  local newID = uuid.generate_random()

  local id,err = self:SendImage(finalImage.image, newID..'b')
  if not id then
    print('couldnt send image: ',err)
    return nil, err
  end

  image:resize_and_crop(1000,1000)
  local ok, err = self:AddImage(postID, 'bigIcon', id)
  if not ok then
    print('couldnt add bigicon: ', err)
    return ok, err
  end
  finalImage.image:resize_and_crop(100,100)


  -- ok, err = self:AddImgURLToPost(postID, finalImage.link)
  -- if not ok then
  --   print('couldnt add to post:', err)
  --   return ok, err
  -- end

  id , err = self:SendImage(finalImage.image, newID)
  if not id then
    print('couldnt send small image:', err)
    return nil, err
  end

  ok, err = self:AddImage(postID, 'smallIcon', id)
  if not ok then
    print('couldnt add small image to post: ', err)
    return ok, err
  end
  return true
end

function loader:ProcessPostIcon(postID)
  local postURL, err = self:LoadPost(postID)
  if not postURL then
    return true, err
  end

  local ok, err = self:GetPostIcon(postURL, postID)
  if not ok then
     return nil, err
  end
  print('got post icon')
  return true
end

function loader:GetUpdates()
  local ok, err = red:zrevrange(self.queueName, 0, 10)
  if not ok then
    return ok, err
  end
  for k,v in pairs(ok) do
    red:zrem(self.queueName,v)
    ok[k] = cjson.decode(v)
  end

  return ok, err
end


function loader:Requeue(postInfo)
  -- add retries
  postInfo.retries = postInfo.retries or 0
  postInfo.retries = postInfo.retries + 1
  if postInfo.retries > 3 then
    --give up
    return
  end

  local delay = postInfo.retries * 30

  local ok, err = red:zadd(self.queueName, delay, cjson.encode(postInfo))
  if not ok then
    print('error requueuing: ',err)
  end
  return ok, err
end

function loader:GetNextPost()
  local updates, ok, err
  --print('checking icons ', redisURL, redisPort)
  updates, err = self:GetUpdates()
  if not updates then
    print('couldnt load updates: ', err)
    return
  end

  for _,postUpdate in pairs(updates) do

    ok, err = self:ProcessPostIcon(postUpdate.id)
    if not ok then
      print('couldnt req: ', err)
      self:Requeue(postUpdate)
    end
 end
end




--=====================================================


loader.queueName = 'queue:GeneratePostIcon'

while true do
  socket.sleep(1)

  if not red then
     red, err = redis.connect(redisURL, redisPort)
    if not red then
      print(err)
    end
  end


  local status, err = pcall(function() loader:GetNextPost() end)

  if not status then
    print(err)
  end


end
