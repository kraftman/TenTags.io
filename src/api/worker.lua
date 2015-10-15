local worker = {}

local rediswrite = require 'api.rediswrite'
local userWrite = require 'api.userwrite'
local email = require 'lib.testemail'
local commentWrite = require 'api.commentwrite'

function worker:CreateTag(tagInfo)
  rediswrite:CreateTag(tagInfo)
end

function worker:CreatePost(postInfo)
  rediswrite:CreatePost(postInfo)
end

function worker:CreateComment(commentInfo)
  userWrite:AddComment(commentInfo)
  return commentWrite:CreateComment(commentInfo)
end

function worker:CreateFilter(filterInfo)
  rediswrite:CreateFilter(filterInfo)
end

function worker:SubscribeToFilter(userID,filterID)
  userWrite:SubscribeToFilter(userID, filterID)
end

function worker:UnsubscribeFromFilter(username,filterID)
  rediswrite:UnsubscribeFromFilter(username,filterID)
end

function worker:AddPostToFilters(finalFilters,postInfo)
  rediswrite:AddPostToFilters(finalFilters,postInfo)
end

function worker:FlushAllPosts()
  return rediswrite:FlushAllPosts()
end

function worker:CreateThread(thread)
  return rediswrite:CreateThread(thread)
end


function worker:CreateMessage(message)

  return rediswrite:CreateMessage(message)
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

function worker:CreateMasterUser(masterInfo)
  return userWrite:CreateMasterUser(masterInfo)
end

function worker:ActivateAccount(userID)
  return userWrite:ActivateAccount(userID)
end



return worker
