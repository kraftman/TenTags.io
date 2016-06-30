


--zrange queue:GeneratePostIcon 0 -1
local magick = require 'magick'

local redis = require 'redis'
local red = redis.connect('redis-general', 6379)

local io = require("io")
local http = require("socket.http")
local ltn12 = require("ltn12")

local function ConvertListToTable(list)
  local info = {}
  for i = 1,#list, 2 do
    info[list[i]] = list[i+1]
  end
  return info
end

local function LoadPost(postID)
  print(postID)
  local post, err = red:hgetall('post:'..postID)

  print(post.link)
  return post.link



end


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

	--newPost.icon = finalImage.image:get_blob()
	finalImage.image:write('/lua/'..postID..'.png')
	print('icon added, written to: ',postID..'.png')

end


local function GetNextPost()
  local ok, err = red:zrevrange('queue:GeneratePostIcon', 0, 1)
  local postURL = LoadPost(ok[1])
  if (not ok) then
    -- update it in the queue so we try it later
    -- dont want to spam the site repeatedly if it fail
  end

  local icon = GetPostIcon(postURL, ok[1])




end




--=====================================================



GetNextPost()
