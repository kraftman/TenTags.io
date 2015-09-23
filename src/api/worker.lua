local worker = {}

local rediswrite = require 'api.rediswrite'

function worker:CreateTag(tagInfo)
  rediswrite:CreateTag(tagInfo)
end

function worker:CreatePost(postInfo)
  rediswrite:CreatePost(postInfo)
end

function worker:CreateFilter(filterInfo)
  rediswrite:CreateFilter(filterInfo)
end



return worker
