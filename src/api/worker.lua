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

function worker:SubscribeToFilter(username,filterID)
  rediswrite:SubscribeToFilter(username, filterID)
end

function worker:UnsubscribeFromFilter(username,filterID)
  rediswrite:UnsubscribeFromFilter(username,filterID)
end

function worker:AddPostToFilters(finalFilters,postInfo)
  rediswrite:AddPostToFilters(finalFilters,postInfo)
end



return worker
