


local magick = require 'magick'
local redis = require 'redis'

local http = require("socket.http")
local ltn12 = require("ltn12")
local giflib = require("giflib")

--[[
local redisURL = 'localhost'
local redisPort = '16379'
local imgHostURl = 'localhost'
local imgHostPort = '81'
--]]

local redisURL = 'redis-general'
local redisPort = '6379'
local imgHostURl = 'imghost'
local imgHostPort = '80'

local red = redis.connect(redisURL, redisPort)


local function LoadPost(postID)
  local post, err = red:hgetall('post:'..postID)
  if not post then
    return post, err
  end
  return post.link
end

local ok, err

local function LoadImage(imageInfo)
  local res, c, h = http.request ( imageInfo.link )

	if c ~= 200 then
		--print(' cant laod image: ',imageInfo.link, ' err: ',err)
		return nil
	end
	--print(imageInfo.link, type(res.body), res.body)
	if res:len() > 0 then
		return res
	else
		print ('empty image')
	end

	return nil
end

local function GetImageLinks(res)
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

local function SendImage(image, postID)
  local resp = {}
  local body,code,headers,status = http.request{
  url = "http://"..imgHostURl..':'..imgHostPort.."/upload",
  method = "POST",
  headers = {

    ["Transfer-Encoding"] = 'chunked',
    ['content-disposition'] = 'attachment; filename="'..postID..'.png"'
  },
  source = ltn12.source.string(image:get_blob()),
  sink = ltn12.sink.table(resp)
  }
  print(postID)
  print(body,code,status)

  if headers then
      for k,v in pairs(headers) do
       print(k,v)
     end
  end
  return true
end

local function ProcessImgur(postURL, postID)
  local ok, err = os.execute('python pygur.py '..postURL..' '..postID)
  if ok ~= 0 then
    return nil, err
  end

  local image = magick.load_image('/lua/out/'..postID..'.jpg')
  image:coalesce()
  image:set_format('png')
  --finalImage.image:write('/lua/out/p2-'..postID..'.png')
  --finalImage.image = magick.load_image('/lua/out/p2-'..postID..'.png')

  image:resize_and_crop(100,100)
  ok, err = SendImage(image,postID)
  if ok then
    os.remove('out/'..postID..'.jpg')
  end

  return ok, err

end

local function GetPostIcon(postURL, postID)
  print(postURL, postID)

  if postURL:find('imgur.com') then
    return ProcessImgur(postURL, postID)
  end

  local res, c, h = http.request ( postURL )

  if c ~= 200 then
    print(c, ' ', r)
  end


  local imageLinks = {}
  if postURL:find('.gif') or postURL:find('.jpg') or postURL:find('.jpeg') or postURL:find('.png  ') then
    imageLinks = {{link = postURL}}
  else
    imageLinks = GetImageLinks(res)
  end

  for _, imageInfo in pairs(imageLinks) do
		local imageBlob = LoadImage(imageInfo)
		imageInfo.size = 0
		if imageBlob then
        imageInfo.blob = imageBlob
			local image = assert(magick.load_image_from_blob(imageBlob))

			if image then
				imageInfo.image = image
				local w, h = image:get_width(), image:get_height()
				imageInfo.size = w*h
			end
		end
	end

	table.sort(imageLinks, function(a,b) return a.size > b.size end)

	local finalImage

	for _,v in pairs(imageLinks) do
		if v.image then
			finalImage = v
			break
		end
	end

	if not finalImage then
		return nil
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

    finalImage.image:resize_and_crop(100,100)
    os.remove(tempGifLoc)
    os.remove('/lua/out/processedgif-'..postID..'.gif')
    os.remove('/lua/out/p2-'..postID..'.png')

	end

    finalImage.image:resize_and_crop(100,100)
  	finalImage.image:set_format('png')

  SendImage(finalImage.image, postID)
  return true

end

local function ProcessPostIcon(postID)
  local postURL, err = LoadPost(postID)
  if not postURL then
    return nil, err
  end

   ok, err = GetPostIcon(postURL, postID)
  if not ok then
     return nil, ok
  end
  return true
end


local function GetNextPost()
  local queueName = 'queue:GeneratePostIcon'
  ok, err = red:zrevrange(queueName, 0, 10)
  if not ok then
    print('couldnt get next posts: ', err)
    return
  end

  for _,postID in pairs(ok) do
    ok, err = ProcessPostIcon(postID)
    if ok then
      --remove from queue
      ok, err = red:zrem(queueName, postID)
      if not ok then
      --  print('cant remove from redis! ', err)
      else
        print('removed: '..postID..' from redis after processing')
      end
    else
      -- add back into queue but later
      print('couldnt process, requeueing')
      ok, err = red:zadd(queueName, os.time(), postID)
    end
 end
end




--=====================================================


while true do
  socket.sleep(1)
  GetNextPost()
end
