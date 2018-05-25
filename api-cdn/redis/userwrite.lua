local base = require 'redis.base'
local userwrite = setmetatable({}, base)


function userwrite:ConvertListToTable(list)
  local info = {}
  for i = 1,#list, 2 do
    info[list[i]] = list[i+1]
  end
  return info
end

function userwrite:LoadScript(script)
  local red = self:GetUserWriteConnection()
  local ok, err = red:script('load',script)
  if not ok then
    ngx.log(ngx.ERR, 'unable to add script to redis:',err)
    return nil
  else
    ngx.log(ngx.ERR, 'added script to redis: ',ok)
  end

  return ok
end

function userwrite:AddPost(post)
   local red = self:GetUserWriteConnection()
   local ok, err = red:zadd('userPosts:date:'..post.createdBy, post.createdAt, post.id)
   -- post has no score since its per-filter
   return ok, err
 end

-- TODO:remove this
function userwrite:AddNewUser(time, accountID, email)
  local red = self:GetUserWriteConnection()

  local ok, err = red:zadd('newAccounts', time, accountID..':'..email)
  self:SetKeepalive(red)
  return ok, err
end

function userwrite:AddUserTagVotes(userID, postID, tagNames)
  local red = self:GetUserWriteConnection()
  for k,v in pairs(tagNames) do
    tagNames[k] = postID..':'..v
  end


  local ok, err = red:sadd('userTagVotes:'..userID, tagNames)
  self:SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to add user tag vote: ',err)
  end
  return ok
end

function userwrite:AddUserCommentVotes(userID, commentID)
  local red = self:GetUserWriteConnection()

  local ok, err = red:sadd('userCommentVotes:'..userID, commentID)
  self:SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to add user comment vote: ',err)
  end
  return ok
end

function userwrite:DeleteUser(userID, username)
--local account = cache:GetAccount(accountID)
  local red = self:GetUserWriteConnection()
  red:init_pipeline()
  red:hdel('userToID',username:lower())
  red:hset('user:'..userID, 'deleted', '1')
  local ok, err = red:commit_pipeline()
  self:SetKeepalive(red)
  return ok, err
end

function userwrite:AddSavedPost(userID, postID)
  local red = self:GetUserWriteConnection()
  local key = 'userSavedPost:'..userID

  local ok, err = red:sadd(key, postID)

  self:SetKeepalive(red)
  return ok, err

end

function userwrite:RemoveSavedPost(userID, postID)
  local red = self:GetUserWriteConnection()
  local key = 'userSavedPost:'..userID

  local ok, err = red:srem(key, postID)

  self:SetKeepalive(red)
  return ok, err

end


function userwrite:AddUserPostVotes(userID, createdAt, postID, direction)
  -- replace with bloom later
  local red = self:GetUserWriteConnection()
  local ok, err = red:zadd('userPostVotes:date:'..direction..':'..userID, createdAt, postID)
  if not ok then
    self:SetKeepalive(red)
    return ok, err
  end

  ok, err = red:sadd('userPostVotes:'..userID, postID)
  self:SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to add user post vote: ',err)
  end
  return ok

end

function userwrite:AddUserAlert(createdAt,userID, alert)
  local red = self:GetUserWriteConnection()
  local ok, err = red:zadd('UserAlerts:'..userID,createdAt,alert)

  self:SetKeepalive(red)
  return ok, err
end

-- also used to update comments
function userwrite:AddComment(commentInfo)
  local red = self:GetUserWriteConnection()
  local ok, err = red:zadd(
    'userComments:date:'..commentInfo.createdBy,
    commentInfo.createdAt,
    commentInfo.postID..':'..commentInfo.id
  )
  if not ok then
    ngx.log(ngx.ERR, 'unable to add comment:', err)
  end
  for tagName,tag in pairs(commentInfo.tags) do
    ok, err = red:zadd(
      'userComments:score:'..commentInfo.createdBy..':tag:'..tagName,
      tag.score,
      commentInfo.postID..':'..commentInfo.id
    )
  end
  return ok, err
end

function userwrite:CreateAccount(account)

  local red = self:GetUserWriteConnection()

  local hashedAccount = {}
  hashedAccount.sessions = {}
  hashedAccount.users = {}
  for k,v in pairs(account) do
    if k == 'sessions' then
      for _,session in pairs(v) do
        hashedAccount['session:'..session.id] = self:to_json(session)
      end
    elseif k == 'users' then
      for _,userID in pairs(v) do
        hashedAccount['user:'..userID] = userID
      end
    else
      hashedAccount[k] = v
    end
  end

  local ok, err = red:multi()
  if not ok then
    return ok, err
  end
   red:del('account:'..hashedAccount.id)
   red:hmset('account:'..hashedAccount.id,hashedAccount)
   ok, err = red:exec()
  return ok, err

end

function userwrite:AddSeenPosts(userID,seenPosts)
  local red = self:GetUserWriteConnection()

  red:init_pipeline()
    for _,postID in pairs(seenPosts) do
      --red:evalsha(addKeySHA1,0,userID,10000,0.01,postID)
      red['BF.ADD'](red, userID..':seenPosts', postID)
      red:zadd('userSeen:'..userID,ngx.time(),postID)
    end
  local _, err = red:commit_pipeline()
  self:SetKeepalive(red)
  if err then
    ngx.log(ngx.ERR, 'unable to add seen post: ', err)
    return nil
  end
  return true
end

function userwrite:LabelUser(userID, targetUserID, label)
  local red = self:GetUserWriteConnection()

  local ok, err = red:hset('user:'..userID, 'userlabel:'..targetUserID, label)
  if err then
    ngx.log(ngx.ERR, 'unable to set user label')
  end
  return ok, err
end

function userwrite:IncrementUserStat(userID, statName, value)
  local red = self:GetUserWriteConnection()
  local ok, err = red:hincrby('user:'..userID, statName, value)
  self:SetKeepalive(red)
  return ok, err
end


function userwrite:IncrementAccountStat(userID, statName, value)
  local red = self:GetUserWriteConnection()
  local ok, err = red:hincrby('account:'..userID, statName, value)
  self:SetKeepalive(red)
  return ok, err
end

function userwrite:CreateSubUser(user)

  local hashedUser = {}

  -- TODO fix this mess
  for k,v in pairs(user) do
    --print(k)
    if k == 'filters' then
      --do nothing for now, might add the hash later
    elseif k == 'commentSubscriptions' then
      hashedUser['commentSubscriptions:'] = self:to_json(v)
    elseif k == 'commentSubscribers' then
      hashedUser['commentSubscribers:'] = self:to_json(v)
    elseif k == 'postSubscriptions' then
      hashedUser['postSubscriptions:'] = self:to_json(v)
    elseif k == 'postSubscribers' then
      hashedUser['postSubscribers:'] = self:to_json(v)
    elseif k == 'blockedUsers' then
      hashedUser['blockedUsers:'] = self:to_json(v)
    elseif k == 'views' then
      hashedUser['views:'] = self:to_json(v)
    else
      hashedUser[k] = v
    end
  end

  local red = self:GetUserWriteConnection()

  red:multi()
    red:hmset('user:'..hashedUser.id, hashedUser)

    red:hset('userToID',hashedUser.username:lower(),hashedUser.id)
  local results, err = red:exec()
  if not results then
    print('couldnt create user: ', err)
  end
  self:SetKeepalive(red)

  if err then
    ngx.log(ngx.ERR, 'unable to create new user: ',err)
    return nil
  end
  return true

end

function userwrite:UpdateBlockedUsers(user)
  local red = self:GetUserWriteConnection()

  local ok, err = red:hset('user:'..user.id, 'blockedUsers:', self:to_json(user.blockedUsers))
  self:SetKeepalive(red)
  return ok, err

end

function userwrite:UpdateUserField(userID, field, value)
  local red = self:GetUserWriteConnection()

  local ok, err = red:hset('user:'..userID, field, value)
  self:SetKeepalive(red)
  return ok, err
end

function userwrite:ToggleFilterSubscription(userID,filterID,subscribe)

  local red = self:GetUserWriteConnection()
  red:init_pipeline()
  if subscribe then
    red:sadd('userfilters:'..userID, filterID)
  else
    red:srem('userfilters:'..userID, filterID)
  end

  local ok, err = red:commit_pipeline()
  self:SetKeepalive(red)

  return ok, err
end


return userwrite
