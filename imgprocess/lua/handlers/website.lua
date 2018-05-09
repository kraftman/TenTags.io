local M = {}

local utils = require 'utils'
local magick = require 'magick'
local giflib = require("giflib")
local https = require 'ssl.https'

local function ConvertGif(finalImage, postID)
    if not finalImage.link:find('.gif') then
        return
    end

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

local function GetLargestImage(imageLinks)

    for _, imageInfo in pairs(imageLinks) do
        print('loading blob for: ', imageInfo.link)
      local imageBlob = utils:LoadImage(imageInfo.link)
      imageInfo.size = 0
      if imageBlob then
          imageInfo.blob = imageBlob
        local image = magick.load_image_from_blob(imageBlob)

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
    return finalImage
end

function M:GetImageLinks(res)
    local imageLinks = {}
    --print(res)
      for imgTag in res:gmatch('<img.-src=[\'"](.-)[\'"].->') do
        if imgTag:find('^//') then
            imgTag = 'https:'..imgTag
            print('found: ',imgTag)
        else
            print(imgTag)
        end
        table.insert(imageLinks, {link = imgTag})
      end

    return imageLinks
  end


function M:IsImage(headers)
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

function M:Process(postURL, postID)

    local res, c, header = https.request ( postURL )

    if not res then
      return res, c
    end
    if c ~= 200 then
      print(c, ' ', res)
    end

    local imageLinks
    if postURL:find('.gif') or postURL:find('.jpg') or postURL:find('.jpeg') or postURL:find('.png') then
      imageLinks = {{link = postURL}}
    elseif self:IsImage(header) then
      print('its an content-type image')
      imageLinks = {{link = postURL}}
    else
      imageLinks = self:GetImageLinks(res)
    end

    local finalImage = GetLargestImage(imageLinks)

    ConvertGif(finalImage, postID)

  return finalImage
end

return M