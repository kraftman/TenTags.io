
local magick = require 'magick'
local uuid = require 'lib.uuid'
local utils = require 'utils'

local M = {}


function M:Process(postURL, postID)
    local handle = io.popen('python pygur.py '..postURL..' '..postID)
    local imgURL = handle:read("*a")
    imgURL = imgURL:gsub('\n','')
    imgURL = imgURL:gsub('\r','')
    imgURL = imgURL:gsub(' ','')
    handle:close()
    print('adding ',imgURL,' to post')
    utils:AddImgURLToPost(postID, imgURL)

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
    local id, err = utils:SendImage(image:get_blob(),newID..'b')
    if not id then
      print('error sending image: ',err)
      return nil, 'couldnt send imgur full image'
    end
    local ok

    image:resize_and_crop(1000,1000)
    ok, err = utils:AddImage(postID, 'bigIcon', id)
    if not ok then
      print('error sending image: ',err)
      return ok, err
    end
    image:resize_and_crop(200,200)
    id, err = utils:SendImage(image:get_blob(),newID)
    if not id then
      print('error sending image: ',err)
      return nil, 'couldnt send imgur thumb image'
    end

    ok, err = utils:AddImage(postID, 'smallIcon', id)
    if not ok then
      print('error sending image: ',err)
      return ok, err
    end
    os.remove('out/'..postID..'.jpg')

    return true

  end

return M