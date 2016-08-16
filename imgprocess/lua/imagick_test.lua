--package.path = package.path .. ';/usr/local/openresty/luajit/lib/lua/5.1/?.so'

--[[
download the page
check for the largest image
convert and save as icon
if image, use imagemagick, if gif use giflib
]]

local http = require('socket.http')
local sites = {'https://i.imgur.com/M3Anp1K.gif','http://i.imgur.com/4DDzfxar.jpg','https://j.gifs.com/Kr9OkM.gif'}

local magick = require "magick"

--[[
	for k,v in pairs(sites) do
	local b, c, h = http.request(v)
	if c ~= 200 then
		break
	end


	local img = magick.open_blob(b)
	local imgName = v:match('(%w+)%.%w+$')
	img:write('out/'..imgName..'.jpg')

end
]]


local img = assert(magick.load_image("out/test-frame-1.gif"))
--img:smart_resize("100x100^")
img:set_format('png')
img:resize_and_crop(100,100)
img:write("out/out.png")
