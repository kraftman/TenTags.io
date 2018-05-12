local M = {}

local utils = require 'utils'
local https = require 'ssl.https'
local magick = require 'magick'

function M:Process(postURL)

    -- cant use just the url because sometimes the urls are lowercase
    -- and gifycats cdn is case sensitive

    local res, c, _ = https.request ( postURL )

    if not res then
      print(res, err)
      return res, c
    end
    if c ~= 200 then
      print('error loading gfycat: ', c)
    end
    --print(res)
    local gfyName = res:match('https://thumbs%.gfycat%.com/(%w-)%-mobile%.jpg')

    print('gfyname:', gfyName)
    -- local gfyName = postURL:match('gfycat.com/detail/(%w+)') or postURL:match('gfycat.com/gifs/detail/(%w+)')
    --
    -- if not gfyName then
    --   gfyName = postURL:match('gfycat.com/(%w+)')
    -- end

    local newURL = 'http://thumbs.gfycat.com/'..gfyName..'-poster.jpg'

    print('icon URL:', newURL)
    local imageBlob, err = utils:LoadImage(newURL)
    if not imageBlob then
      print('couldnt get image from gyf: ', err)
      return imageBlob, err
    end
  
    local loadedImage  = assert(magick.load_image_from_blob(imageBlob))
  
    return {link = newURL, image = loadedImage}
  
  end


return M