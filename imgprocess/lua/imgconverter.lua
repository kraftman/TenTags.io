


local magick = require 'magick'
local redis = require 'redis'
local socket = require 'socket'

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


local function ReadFile(file)
    local f = io.open(file, "rb")
    local content = f:read("*a")
    f:close()
    return content
end

local function WriteFile(path, data)
  local file, err = assert(io.open(path, 'w+'))
  if err then
    return nil, err
  end

  file:write(data)
  file:close()
  return true
end


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
  local id, err = bb:UploadImage(image, imageName)
  print(id, err)
  return id, err
end

function loader:AddImgURLToPost(postID, imgURL)
  red:hset('post:'..postID,'imgURL', imgURL)
  return true
end

function loader:IsGif(fileName)
  local handle = io.popen('ffprobe '..fileName..' 2>&1')
  local imgURL = handle:read("*a")

  local hours, minutes, seconds = imgURL:match('Duration: (%d%d):(%d%d):(%d%d)%.%d%d')
  local totalTime = seconds + minutes*60 + hours*60*60
  if totalTime > 15 then
    return false
  end
end

function loader:ConvertToMp4(imageID)
  local handle = io.popen('ffmpeg -y -i out/'..imageID..' sample.mp4 2>&1')
  local output = handle:read('*a')
end

function loader:ConvertToGif(imageID)
  local handle = io.popen('ffmpeg -y -i out/'..imageID..' sample.gif 2>&1')
  local output = handle:read('*a')
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
  image:set_format('jpg')
  --finalImage.image:write('/lua/out/p2-'..postID..'.png')
  --finalImage.image = magick.load_image('/lua/out/p2-'..postID..'.png')
  local newID = uuid.generate_random()
  local id, err = self:SendImage(image:get_blob(),newID..'b')
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
  id, err = self:SendImage(image:get_blob(),newID)
  if not id then
    print('error sending image: ',err)
    return nil, 'couldnt send imgur thumb image'
  end

  ok, err = self:AddImage(postID, 'smallIcon', id)
  if not ok then
    print('error sending image: ',err)
    return ok, err
  end
  os.remove('out/'..postID..'.jpg')


  return true

end

function loader:ProcessGfycat(postURL)
  --print(postURL)
  local gfyName = postURL:match('gfycat.com/detail/(%w+)') or postURL:match('gfycat.com/gifs/detail/(%w+)')
  --print(gfyName)
  if not gfyName then
    gfyName = postURL:match('gfycat.com/(%w+)')
  end

  --print(gfyName)
  local newURL = 'http://thumbs.gfycat.com/'..gfyName..'-poster.jpg'
  --print(newURL)

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
    finalImage.image:set_format('jpg')
    finalImage.image:write('/lua/out/p2-'..postID..'.jpg')
    finalImage.image = magick.load_image('/lua/out/p2-'..postID..'.jpgf')

    os.remove(tempGifLoc)
    os.remove('/lua/out/processedgif-'..postID..'.gif')
    os.remove('/lua/out/p2-'..postID..'.jpg')

	end

  return finalImage
end

function loader:AddImage(postID, key, bbID)
  print('adding to post: post:'..postID, key, bbID )
  local ok, err = red:hset('post:'..postID, key, bbID)

  local timeInvalidated = socket.gettime()
  print(timeInvalidated)
  local data = cjson.encode({keyType = 'post', id = postID})
  local ok, err = red:zadd('invalidationRequests', timeInvalidated, data)

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
    --if postURL:find('.gif') or postURL:find('gallery') or postURL:find('.jpg') or postURL:find('.jpeg') or postURL:find('.png') then
      return self:ProcessImgur(postURL, postID)
    --end
    --return nil, 'imgur gallery'
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

  finalImage.image:set_format('jpg')
  local newID = uuid.generate_random()

  local id,err = self:SendImage(finalImage.image:get_blob(), newID..'b')
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


  -- ok, err = self:AddImgURLToPost(postID, finalImage.link)
  -- if not ok then
  --   print('couldnt add to post:', err)
  --   return ok, err
  -- end

  id , err = self:SendImage(finalImage.image:get_blob(), newID)
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

function loader:ProcessPostIcon(post)
  local postURL, err = self:LoadPost(post.id)
  if not postURL then
    return true, err
  end

  local ok, err = self:GetPostIcon(postURL, post.id)
  if not ok then
     return nil, err
  end
  print('got post icon')
  return true
end

function loader:AddBBIDToImage(imageID, key, bbID)
  local ok, err = red:hset('image:'..imageID, key, bbID)
  if not ok then
    print('error setting image bb id: ', err)
  end

  local timeInvalidated = socket.gettime()

  local data = cjson.encode({keyType = 'image', id = imageID})

  ok, err = red:zadd('invalidationRequests', timeInvalidated, data)
  if not ok then
    print('error setting invalidationRequests: ', err)
  end
  return true
end


function loader:GeneratePreview(image, pathIn, pathOut)
  local hours, minutes, seconds = imgURL:match('Duration: (%d%d):(%d%d):(%d%d)%.%d%d')
  local totalTime = seconds + minutes*60 + hours*60*60

  -- calculate what we need
  local segmentCount = 10
  local startTime, command, handle, output
  for i = 1, segmentCount do
    startTime = math.floor((totalTime/segmentCount)*i)
    command = 'ffmpeg -y -ss '..startTime..' -i '..pathIn..' -t 1 -f mpegts '..pathIn..'-out'..i..'.ts'
    print(command)
    handle = io.popen(command)
    output = handle:read('*all')
    print(output)
  end

  local concat = 'concat:'

  for i = 1, segmentCount do
    if i == 1 then
      concat = concat..'output'..i..'.ts'
    else
      concat = concat..'|output'..i..'.ts'
    end
  end

  command = 'ffmpeg -y -i "'..concat..'" -c copy '..pathOut

  handle = io.popen(command)
  output = handle:read('*all')
  io.popen('rm '..pathIn..'-out')

  --TODO check for errors

  return true
end



function loader:ConvertAndUpload(image, pathIn, pathOut, width, height, tag)
  local command = 'ffmpeg -y -i '..pathIn..[[ -filter_complex "scale=iw*min(1\,min(]]
                        ..height..[[/iw\,]]..width..[[/ih)):-1" ]]..pathOut..' 2>&1'
  local handle = io.popen(command)
  local output = handle:read('*a')
  --TODO check output


  local fileData, err = ReadFile(pathOut)
  if not fileData then
    return ok, err
  end

  local ok, err = self:SendImage(fileData, image.id..'-'..tag)
  print(tag, ' - ', ok)
  if not ok then
    return ok, err
  end

  return self:AddBBIDToImage(image.id, tag, ok)

end

function loader:GetFirstFrame(image, pathIn)
  --https://stackoverflow.com/questions/4425413/how-to-extract-the-1st-frame-and-restore-as-an-image-with-ffmpeg
  local ok, err, fileData
  local pathOut = pathIn..'-icon.jpg'
  local command = 'ffmpeg -i '..pathIn..' -vf '..[["select=eq(n\,0)"]]..' -vf scale=100:-2 -q:v 3 '..pathOut..' 2>&1'
  local handle = io.popen(command)
  local output = handle:read('*a')
  print(output)
  --TODO check output

  fileData, err = ReadFile(pathOut)
  if not fileData then
    return fileData, err
  end

  ok, err = self:SendImage(fileData, image.id..'-'..'icon')
  if not ok then
    return ok, err
  end

  return self:AddBBIDToImage(image.id, 'iconID', ok)


end

function loader:ConvertRawVideo(image)

  -- download the raw file
  local file, err = bb:GetImage(image.rawID)
  if not file then
    return file, err
  end
  print('got raw')

  --write locally
  local ok, err = WriteFile('out/'..image.id, file.data)
  if not ok then
    return ok, err
  end

  print('wrote locally')

  local pathIn = 'out/'..image.id
  local pathOut = 'out/'..image.id..'-processed.mp4'

  -- convert to mp4 and upload
  local ok, err = self:ConvertAndUpload(image, pathIn, pathOut, 1920, 1080, 'videoID')
  if not ok then
    return ok, err
  end
  print('converted to mp4')


  -- create preview and upload
  pathOut = 'out/'..image.id..'-preview.mp4'
  if self:IsGif(pathIn) then
    ok, err = self:GeneratePreview(pathIn, pathOut)
  else
    ok, err = self:ConvertAndUpload(image, pathIn, pathOut, 854, 480, 'previewID')
    if not ok then
      return ok, err
    end
  end
  print('converted to preview')

  -- by now we have either a condensed 10 sec preview or just a shrunk 15 sec vid
  -- convert to gif as fallback

  -- use the output from above
  pathIn = pathOut
  pathOut = 'out/'..image.id..'-processed.gif'
  ok, err = self:ConvertAndUpload(image, pathIn, pathOut, 854, 480, 'gifID')
  if not ok then
    return ok, err
  end
  print('converted to gif')
  -- use the preview for image as its already smaller
  ok, err = self:GetFirstFrame(image, pathIn)
  if not ok then
    return ok, err
  end
  print('converted icon')

  --TODO cleanup local files
  --TODO remove raw from image/backblaze.


  return true
end


function loader:ConvertStaticImage(image)

    local imageData =  bb:GetImage(image.rawID)
    image.data =  assert(magick.load_image_from_blob(imageData.data))

    -- optimise
    image.data:set_format('jpg')
    image.data:set_quality(90)
    local bbID, err = self:SendImage(image.data:get_blob(), image.id)

    if bbID then
      print('sent to bb, adding to image')
      self:AddBBIDToImage(image.id, 'imgID', bbID)
    else
      print(err)
    end

    -- add this as imgID

    -- shrink
    image.data:resize_and_crop(1000,1000)

    bbID, err = self:SendImage(image.data:get_blob(), image.id)
    if bbID then
      print('sent to bb, adding to image big')
      self:AddBBIDToImage(image.id, 'bigID', bbID)
    else
      print(err)
    end

    image.data:resize_and_crop(100,100)

    bbID, err = self:SendImage(image.data:get_blob(), image.id)
    if bbID then
      print('sent to bb, adding to image icon')
      self:AddBBIDToImage(image.id, 'iconID', bbID)
    else
      print(err)
    end

    return true
end

function loader:ConvertImage(image)


  if image.type == 'vid' then
    local ok, err = self:ConvertRawVideo(image)
    if not ok then
      print('failed to process:', err)
    end
    return ok, err
  else
    local ok, err = self:ConvertStaticImage(image)
    return ok, err
  end

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

function loader:GetNextPost(queueName, job)
  local updates, ok, err

  updates, err = self:GetUpdates(queueName)
  if not updates then
    print('couldnt load updates: ', err)
    return
  end

  for _,postUpdate in pairs(updates) do

    ok, err = self[job](self,postUpdate)
    if not ok then
      print('couldnt req: ', err)
      self:Requeue(queueName, postUpdate)
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


  local status, err = pcall(function() loader:GetNextPost('queue:GeneratePostIcon', 'ProcessPostIcon') end)

  if not status then
    print(err)
  end

  local status, err = pcall(function() loader:GetNextPost('queue:ConvertImage', 'ConvertImage') end)

  if not status then
    print(err)
  end


end
