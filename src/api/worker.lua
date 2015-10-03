local worker = {}

local rediswrite = require 'api.rediswrite'
local userWrite = require 'api.userwrite'
local email = require 'lib.testemail'

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

function worker:SendActivationEmail(url,emailAddr)

  local subject = "Email confirmation"
  local body = [[
    Congrats for registering, you are the best!
    Please click this link to confirm your email address
  ]]
  body = body..url
  email:sendMessage(subject,body,emailAddr)

end

function worker:CreateUser(userInfo)
  return userWrite:CreateUser(userInfo)
end

function worker:ActivateAccount(userID)
  return userWrite:ActivateAccount(userID)
end



return worker
