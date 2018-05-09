
local https = require 'ssl.https'
local redis = require 'redis'
local socket = require 'socket'
local cjson = require('cjson')
local bb = require 'lib.backblaze'

local redisURL, redisPort
if os.getenv('REDIS_GENERAL_WRITE') then
  print( os.getenv('REDIS_GENERAL_WRITE'))
  redisURL, redisPort = os.getenv('REDIS_GENERAL_WRITE'):match('(.+):(%d+)')
else
  redisURL, redisPort = 'redis-general', '6379'
end

local red, rederr = redis.connect(redisURL, redisPort)
if not red then
  print(rederr)
end

local M = {}

function M:AddImgURLToPost(postID, imgURL)
    red:hset('post:'..postID,'imgURL', imgURL)
    return true
end

function M:SendImage(image, imageName)
    local id, err = bb:UploadImage(image, imageName)
    print(id, err)
    return id, err
end

function M:AddImage(postID, key, bbID)
    print('adding to post: post:'..postID, key, bbID )
    print('post:'..postID, key, bbID)
    local _, err = red:hset('post:'..postID, key, bbID)
    if err then
        print('error with hset:', err)
        return nil, err
    end

    local timeInvalidated = socket.gettime()
    print(timeInvalidated)
    local data = cjson.encode({keyType = 'post', id = postID})
    _, err = red:zadd('invalidationRequests', timeInvalidated, data)
    if err then
        print('error with invalidationrequest:', err)
        return nil, err
    end

    return true
  end

function M:LoadImage(imageLink)
    local res, c = https.request ( imageLink )

    if c ~= 200 then
        print(' cant load image: ',imageLink, ' err: ', c)
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


function M:ReadFile(file)
    local f, err = io.open(file, "rb")
    if not f then
      print('couldnt read file: ', file, ' err: ', err)
      return nil, err
    end
    local content = f:read("*a")
    f:close()
    return content
end

function M:WriteFile(path, data)
    local file, err = assert(io.open(path, 'w+'))
    if err then
        return nil, err
    end

    file:write(data)
    file:close()
    return true
end

function M:AddBBIDToImage(imageID, key, bbID)
    local ok, err = red:hset('image:'..imageID, key, bbID)
    if not ok then
        if ok ~= false then
        print('error setting image bb id: ', err)
        return nil, err
        end
    end

    local timeInvalidated = socket.gettime()

    local data = cjson.encode({keyType = 'image', id = imageID})

    ok, err = red:zadd('invalidationRequests', timeInvalidated, data)
    if not ok then
        print('error setting invalidationRequests: ', err)
        return nil, err
    end
    return true
end

return M