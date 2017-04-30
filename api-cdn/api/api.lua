--[[
  access control
  rate limitting
  business logic
]]

local cache = require 'api.cache'
local api = {}
local uuid = require 'lib.uuid'
local worker = require 'api.worker'
local util = require 'util'
local tinsert = table.insert
local trim = (require 'lapis.util').trim
local scrypt = require 'lib.scrypt'
local salt = 'poopants'
--local to_json = (require 'lapis.util').to_json
--local magick = require 'magick'
local http = require 'lib.http'
--arbitrary, needs adressing later
local TAG_START_DOWNVOTES = 0
local TAG_START_UPVOTES = 1
local COMMENT_LENGTH_LIMIT = 2000
local UNLIMITED_VOTING = os.getenv('UNLIMITED_VOTING')
--local permission = require 'userpermission'

local MAX_ALLOWED_TAG_COUNT = 20
local MAX_MOD_COUNT = 7

local USER_ROLES = {ADMIN = 1, USER = 2}




function api:GetDefaultFrontPage(range,filter)
  range = range or 0
  filter = filter or 'fresh'
  return cache:GetDefaultFrontPage(range,filter)
end

















--[[
function api:LoadImage(httpc, imageInfo)
	local res, err = httpc:request_uri(imageInfo.link)
	if err then
		--print(' cant laod image: ',imageInfo.link, ' err: ',err)
		return nil
	end
	--print(imageInfo.link, type(res.body), res.body)
	if res.body:len() > 0 then
		return res.body

	else
		print('empty body for '..imageInfo.link)
	end
	return nil
end
]]

-- is this used anymore?

-- function api:GetIcon(newPost)
-- 	--see if we can get the webpage
-- 	--scan the webpage for image links
-- 	--get the size of each link
-- 	--create an icon from the largest image
-- 	local httpc = http.new()
-- 	local res, err = httpc:request_uri(newPost.link)
-- 	if not res then
-- 		print('failed: ', err)
-- 		return
-- 	end
--
-- 	--print(res.body)
-- 	local imageLinks = {}
-- 	for imgTag in res.body:gmatch('<img.-src=[\'"](.-)[\'"].->') do
-- 		if imgTag:find('^//') then
-- 			imgTag = 'http:'..imgTag
-- 		end
-- 		tinsert(imageLinks, {link = imgTag})
-- 	end
--
-- 	for _, imageInfo in pairs(imageLinks) do
-- 		local imageBlob = self:LoadImage(httpc, imageInfo)
-- 		imageInfo.size = 0
-- 		if imageBlob then
-- 			local image = assert(magick.load_image_from_blob(imageBlob))
--
-- 			--local icon = assert(magick.thumb(imageBlob, '100x100'))
--
-- 			if image then
-- 				imageInfo.image = image
-- 				local w,h = image:get_width(), image:get_height()
-- 				imageInfo.size = w*h
-- 			end
-- 		end
-- 	end
--
-- 	table.sort(imageLinks, function(a,b) return a.size > b.size end)
--
-- 	local finalImage
-- 	for _,v in pairs(imageLinks) do
-- 		if v.image then
-- 			finalImage = v
-- 			break
-- 		end
-- 	end
--
-- 	if not finalImage then
-- 		return nil
-- 	end
--
-- 	finalImage.image:resize_and_crop(100,100)
-- 	finalImage.image:set_format('png')
-- 	if finalImage.link:find('.gif') then
-- 		print('trying to coalesce')
-- 		finalImage.image:coalesce()
-- 	end
-- 	--newPost.icon = finalImage:get_blob()
-- 	newPost.icon = finalImage.image:get_blob()
-- 	finalImage.image:write('static/icons/'..newPost.id..'.png')
-- 	print('icon added, written to: ',newPost.id..'.png')
--
-- end
--






return api
