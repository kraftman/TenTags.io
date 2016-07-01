


local magick = require 'magick'
local redis = require 'redis'
local red = redis.connect('redis-general', 6379)
local http = require("socket.http")
local ltn12 = require("ltn12")


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

	for imgTag in res:gmatch('<img.-src=[\'"](.-)[\'"].->') do
		if imgTag:find('^//') then
			imgTag = 'http:'..imgTag
      print('found: ',imgTag)
		end
		table.insert(imageLinks, {link = imgTag})
	end

  return imageLinks
end

local function SendImage(finalImage, postID)
  local resp = {}
  local body,code,headers,status = http.request{
  url = "http://imghost/upload",
  method = "POST",
  headers = {

    ["Transfer-Encoding"] = 'chunked',
    ['content-disposition'] = 'attachment; filename="'..postID..'.png"'
  },
  source = ltn12.source.string(finalImage.image:get_blob()),
  sink = ltn12.sink.table(resp)
  }
  print(postID)
  print(body,code,status)

  if headers then
      for k,v in pairs(headers) do
       print(k,v)
     end
  end
end

local function GetPostIcon(postURL, postID)
  print(postURL, postID)
  local res, c, h = http.request ( postURL )

  if c ~= 200 then
    print(c, ' ', r)
  end

  local imageLinks = GetImageLinks(res)

  for _, imageInfo in pairs(imageLinks) do
		local imageBlob = LoadImage(imageInfo)
		imageInfo.size = 0
		if imageBlob then
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
		print('trying to coalesce')
		finalImage.image:coalesce()
	else
    finalImage.image:resize_and_crop(100,100)
  	finalImage.image:set_format('png')
  end


  SendImage(finalImage, postID)
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
        print('cant remove from redis! ', err)
      else
        print('removed: '..postID..' from redis after processing')
      end
    else
      -- add back into queue but later
      ok, err = red:zadd(queueName, os.time(), postID)
    end
 end
end




--=====================================================


while true do
  socket.sleep(1)
  GetNextPost()
end
