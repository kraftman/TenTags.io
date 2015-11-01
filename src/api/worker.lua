local worker = {}

local rediswrite = require 'api.rediswrite'
local userWrite = require 'api.userwrite'
local email = require 'lib.testemail'
local commentWrite = require 'api.commentwrite'
local cache = require 'api.cache'

function worker:CreateTag(tagInfo)
  rediswrite:CreateTag(tagInfo)
end

function worker:AddUserTagVotes(userID, postID, tagIDs)
  return userWrite:AddUserTagVotes(userID, postID, tagIDs)
end

function worker:AddUserPostVotes(userID, postID)
  return userWrite:AddUserPostVotes(userID, postID)
end

function worker:UpdatePostField(postID, field, newValue)
  return rediswrite:UpdatePostField(postID, field, newValue)
end

function worker:UpdateComment(comment)
  return commentWrite:CreateComment(comment)
end

function worker:CreatePost(postInfo)
  return rediswrite:CreatePost(postInfo)
end

function worker:FilterBanDomain(filterID, banInfo)
  return rediswrite:FilterBanDomain(filterID, banInfo)
end

function worker:FilterUnbanDomain(filterID, domainName)
  return rediswrite:FilterUnbanDomain(filterID, domainName)
end

function worker:FilterUnbanUser(filterID, userID)
  return rediswrite:FilterUnbanUser(filterID, userID)
end

function worker:FilterBanUser(filterID, banInfo)
  return rediswrite:FilterBanUser(filterID, banInfo)
end

function worker:CreateComment(commentInfo)
  userWrite:AddComment(commentInfo)
  return commentWrite:CreateComment(commentInfo)
end

function worker:UpdateUser(user)
  userWrite:CreateSubUser(user)
end

function worker:AddPostsToFilter(filter, posts)
  rediswrite:AddPostsToFilter(filter, posts)
end

function worker:FindPostsForFilter(filterInfo)
  return rediswrite:FindPostsForFilter(filterInfo)
end

function worker:CreateFilter(filterInfo)

  local postIDs = self:FindPostsForFilter(filterInfo)
  local posts = cache:GetPosts(postIDs)
  rediswrite:CreateFilter(filterInfo)
  self:AddPostsToFilter(filterInfo, posts)
  self:SubscribeToFilter(filterInfo.createdBy, filterInfo.id)

end

function worker:SubscribeToFilter(userID,filterID)
  userWrite:SubscribeToFilter(userID, filterID)
end

function worker:UnsubscribeFromFilter(username,filterID)
  rediswrite:UnsubscribeFromFilter(username,filterID)
end

function worker:AddPostToFilters(post, filters)
  rediswrite:AddPostToFilters(post, filters)
end

function worker:RemovePostFromFilters(postID, filterIDs)
  return rediswrite:RemovePostFromFilters(postID, filterIDs)
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

function worker:CreateSubUser(userInfo)
  return userWrite:CreateSubUser(userInfo)
end

function worker:CreateMasterUser(masterInfo)
  return userWrite:CreateMasterUser(masterInfo)
end

function worker:ActivateAccount(userID)
  return userWrite:ActivateAccount(userID)
end

function worker:AddUserAlert(userID, alert)
  return userWrite:AddUserAlert(ngx.time(),userID, alert)
end

function worker:UpdateLastUserAlertCheck(userID)
  return userWrite:UpdateLastUserAlertCheck(userID, ngx.time())
end



return worker
