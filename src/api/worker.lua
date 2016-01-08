local worker = {}

local rediswrite = require 'api.rediswrite'
local userWrite = require 'api.userwrite'
local commentWrite = require 'api.commentwrite'
local cache = require 'api.cache'
local to_json = (require 'lapis.util').to_json

local emailDict = ngx.shared.emailQueue

function worker:CreateTag(tagInfo)
  return rediswrite:CreateTag(tagInfo)
end

function worker:IncrementUserStat(userID, statName, value)
  return userWrite:IncrementUserStat(userID, statName, value)
end

function worker:AddMasterIP(masterID, IP)
  return userWrite:AddMasterIP(masterID, IP)
end

function worker:AddUserTagVotes(userID, postID, tagIDs)
  return userWrite:AddUserTagVotes(userID, postID, tagIDs)
end

function worker:LogChange(key, time, log)
  return rediswrite:LogChange(key, time, log)
end

function worker:LabelUser(userID, targetUserID, label)
  return userWrite:LabelUser(userID, targetUserID, label)
end

function worker:AddUserCommentVotes(userID, commentID)
  return userWrite:AddUserCommentVotes(userID, commentID)
end

function worker:AddMod(filterID, mod)
  return rediswrite:AddMod(filterID, mod)
end

function worker:DelMod(filterID, modID)
  return rediswrite:DelMod(filterID, modID)
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

function worker:UpdatePostTags(post)
  return rediswrite:UpdatePostTags(post)
end

function worker:UpdateFilterDescription(filter)
  return rediswrite:UpdateFilterDescription(filter)
end


function worker:UpdateFilterTitle(filter)
  return rediswrite:UpdateFilterTitle(filter)
end

function worker:QueueJob(jobName, value)
  return rediswrite:QueueJob(jobName, value)
end

function worker:CreatePost(post)

  local ok, err = self:QueueJob('UpdatePostFilters',post.id)
  if not ok then
    return ok, err
  end

  ok, err = self:QueueJob('AddPostShortURL',post.id)
  if not ok then
    return ok, err
  end

  ok, err = rediswrite:CreatePost(post)
  if ok then
    return post
  else
    return ok, err
  end
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


  local ok, err = commentWrite:CreateComment(commentInfo)
  if not ok then
    return ok, err
  end

  ok, err = self:QueueJob('AddCommentShortURL',commentInfo.postID..':'..commentInfo.id)
  if not ok then
    return ok, err
  end

end

function worker:UpdateUser(user)
  userWrite:CreateSubUser(user)
end

function worker:AddPostsToFilter(filter, posts)
  rediswrite:AddPostsToFilter(filter, posts)
end


function worker:UpdateFilterTags(filter, requiredTags, bannedTags)
  return rediswrite:UpdateFilterTags(filter, requiredTags, bannedTags)
end

function worker:RemovePostsFromFilter(filterID, postIDs)
  return rediswrite:RemovePostsFromFilter(filterID, postIDs)
end

function worker:GetUpdatedFilterPosts(filter, newRequiredTags, newBannedTags)

  local newPostsKey = filter.id..':tempPosts'
  local ok, err = rediswrite:CreateTempFilterPosts(newPostsKey, newRequiredTags, newBannedTags)
  if not ok then
    return ok, err
  end

  local oldPostsKey = 'filterposts:'..filter.id
  local oldPostIDs = rediswrite:GetSetDiff(oldPostsKey, newPostsKey)
  --print('old posts:'..to_json(oldPostIDs))
  local newPostIDs = rediswrite:GetSetDiff(newPostsKey, oldPostsKey)
  --print('new posts:'..to_json(newPostIDs))

  local newPosts = cache:GetPosts(newPostIDs)
  rediswrite:DeleteKey(newPostsKey)
  return newPosts, oldPostIDs

end

function worker:UpdatePostParentID(post)
  return rediswrite:UpdatePostParentID(post)
end


function worker:FindPostsForFilter(filter)
  -- has to use write as it uses sinterstore
  return rediswrite:FindPostsForFilter(filter.id, filter.requiredTags, filter.bannedTags)
end

function worker:CreateFilter(filterInfo)

  --local postIDs = self:FindPostsForFilter(filterInfo)
  --local posts = cache:GetPosts(postIDs)
  rediswrite:CreateFilter(filterInfo)
  -- we need to get scores per post :(

  --self:AddPostsToFilter(filterInfo, posts)
  self:SubscribeToFilter(filterInfo.createdBy, filterInfo.id)

end

function worker:SubscribeToFilter(userID,filterID)
  userWrite:SubscribeToFilter(userID, filterID)
end

function worker:UnsubscribeFromFilter(username,filterID)
  rediswrite:UnsubscribeFromFilter(username,filterID)
end

function worker:AddPostToFilters(post, filters)
  return rediswrite:AddPostToFilters(post, filters)
end


function worker:CreateThread(thread)
  return rediswrite:CreateThread(thread)
end


function worker:CreateMessage(message)

  return rediswrite:CreateMessage(message)
end

function worker:SendActivationEmail(url,emailAddr)

  local email = {}
  email.body = [[
    Congrats for registering, you are the best!
    Please click this link to confirm your email address
  ]]
  email.body = email.body..url
  email.subject = 'Email confirmation'

  local ok, err, forced = emailDict:set(emailAddr, to_json(email))
  if (not ok) and err then
    ngx.log(ngx.ERR, 'unable to set emaildict: ', err)
    return nil, 'unable to send email'
  end
  if forced then
    ngx.log(ngx.ERR, 'WARNING! forced email dict! needs to be bigger!')
  end

  return true
end

function worker:ResetMasterPassword(masterID, passwordHash)
  return userWrite:ResetMasterPassword(masterID, passwordHash)
end

function worker:DeletePost(postID)
  return rediswrite:DeletePost(postID)
end

function worker:SendPasswordReset(url, emailAddr, uuid)

  local ok, err = rediswrite:AddPasswordReset(emailAddr, uuid)
  if not ok then
    return ok, err
  end

  local email = {}
  email.body = [[
    To reset your password, please click this link:
  ]]
  email.body = email.body.. url..uuid

  ok, err, forced = emailDict:set(emailAddr, to_json(email))
  if (not ok) and err then
    ngx.log(ngx.ERR, 'unable to set emaildict: ', err)
    return nil, 'unable to send email'
  end
  if forced then
    ngx.log(ngx.ERR, 'WARNING! forced email dict! needs to be bigger!')
  end

  return true
end

function worker:DeleteResetKey(emailAddr)
  return rediswrite:DeleteResetKey(emailAddr)
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
