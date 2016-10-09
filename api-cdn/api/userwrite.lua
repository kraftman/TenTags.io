
local userwrite = {}

local redis = require 'resty.redis'
local to_json = (require 'lapis.util').to_json
local addKey = require 'redisscripts.addkey'
local util = require 'util'

function userwrite:ConvertListToTable(list)
  local info = {}
  for i = 1,#list, 2 do
    info[list[i]] = list[i+1]
  end
  return info
end

function userwrite:LoadScript(script)
  local red = util:GetUserWriteConnection()
  local ok, err = red:script('load',script)
  if not ok then
    ngx.log(ngx.ERR, 'unable to add script to redis:',err)
    return nil
  else
    ngx.log(ngx.ERR, 'added script to redis: ',ok)
  end

  return ok
end

function userwrite:AddUserTagVotes(userID, postID, tagIDs)
  local red = util:GetUserWriteConnection()
  for k,v in pairs(tagIDs) do
    tagIDs[k] = postID..':'..v
  end

  local ok, err = red:sadd('userTagVotes:'..userID, tagIDs)
  util:SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to add user tag vote: ',err)
  end
  return ok
end

function userwrite:AddUserCommentVotes(userID, commentID)
  local red = util:GetUserWriteConnection()

  local ok, err = red:sadd('userCommentVotes:'..userID, commentID)
  util:SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to add user comment vote: ',err)
  end
  return ok
end


function userwrite:AddUserPostVotes(userID, postID)
  local red = util:GetUserWriteConnection()

  local ok, err = red:sadd('userPostVotes:'..userID, postID)
  util:SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to add user post vote: ',err)
  end
  return ok

end

function userwrite:AddUserAlert(createdAt,userID, alert)
  local red = util:GetUserWriteConnection()
  print('adding user alert for ',userID,to_json(alert))
  local ok, err = red:zadd('UserAlerts:'..userID,createdAt,alert)
  if not ok then
    ngx.log(ngx.ERR, 'unable to create alert: ',err)
  end
  util:SetKeepalive(red)
  return ok
end

function userwrite:UpdateLastUserAlertCheck(userID, checkedAt)
  local red = util:GetUserWriteConnection()
  local ok, err = red:hmset('user:'..userID,'alertCheck',checkedAt)
  util:SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to set user alert check:',err)
  end
  return ok
end

function userwrite:AddComment(commentInfo)
  local red = util:GetUserWriteConnection()
  local ok, err = red:zadd('userComments:'..commentInfo.createdBy, commentInfo.createdAt, commentInfo.postID..':'..commentInfo.id)
  if not ok then
    ngx.log(ngx.ERR, 'unable to add comment: ', err)
  end
end

function userwrite:CreateAccount(account)

  local red = util:GetUserWriteConnection()

  local hashedAccount = {}
  hashedAccount.sessions = {}
  hashedAccount.users = {}
  for k,v in pairs(account) do
    if k == 'sessions' then
      for _,session in pairs(v) do
        hashedAccount['session:'..session.id] = to_json(session)
      end
    elseif k == 'users' then
      for _,userID in pairs(v) do
        hashedAccount['user:'..userID] = userID
      end
    else
      hashedAccount[k] = v
    end
  end


  local ok, err = red:del('account:'..hashedAccount.id)
   ok, err = red:hmset('account:'..hashedAccount.id,hashedAccount)

  return ok, err

end

function userwrite:AddSeenPosts(userID,seenPosts)
  local red = util:GetUserWriteConnection()
  local addKeySHA1 = addKey:GetSHA1()

  red:init_pipeline()
    for k,postID in pairs(seenPosts) do
      red:evalsha(addKeySHA1,0,userID,10000,0.01,postID)
      red:zadd('userSeen:'..userID,ngx.time(),postID)
    end
  local res,err = red:commit_pipeline()
  util:SetKeepalive(red)
  if err then
    ngx.log(ngx.ERR, 'unable to add seen post: ',err)
    return nil
  end
  return true
end

function userwrite:LabelUser(userID, targetUserID, label)
  local red = util:GetUserWriteConnection()

  local ok, err = red:hset('user:'..userID, 'userlabel:'..targetUserID, label)
  if err then
    ngx.log(ngx.ERR, 'unable to set user label')
  end
  return ok, err
end

function userwrite:IncrementUserStat(userID, statName, value)
  local red = util:GetUserWriteConnection()
  local ok, err = red:hincrby('user:'..userID, statName, value)
  util:SetKeepalive(red)
  return ok, err
end

function userwrite:CreateSubUser(user)

  local hashedUser = {}
  hashedUser.filters = {}

  for k,v in pairs(user) do
    if k == 'filters' then
      --do nothing for now, might add the hash later
    else
      hashedUser[k] = v
    end
  end

  local red = util:GetUserWriteConnection()

  red:init_pipeline()
    red:hmset('user:'..hashedUser.id, hashedUser)
    for _,filterID in pairs(user.filters) do
      red:sadd('userfilters:'..hashedUser.id,filterID)
    end
    red:hset('userToID',hashedUser.username:lower(),hashedUser.id)
  local results, err = red:commit_pipeline()
  util:SetKeepalive(red)

  if err then
    ngx.log(ngx.ERR, 'unable to create new user: ',err)
    return nil
  end
  return true

end

function userwrite:SubscribeToFilter(userID,filterID)
  userID = userID or 'default'
  local red = util:GetUserWriteConnection()
  --print('adding filter ',filterID, ' to ',userID)
  local ok, err = red:sadd('userfilters:'..userID, filterID)

  if not ok then
    util:SetKeepalive(red)
    ngx.log(ngx.ERR, 'unable to add filter to list: ',err)
    return
  end


  util:SetKeepalive(red)
  return ok, err

end

function userwrite:UnsubscribeFromFilter(userID, filterID)
  local red = util:GetUserWriteConnection()
  local ok, err = red:srem('userfilters:'..userID,filterID)
  if not ok then
    util:SetKeepalive(red)
    ngx.log(ngx.ERR, 'unable to remove filter from users list:',err)
    return
  end

  util:SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to incr subs: ',err)
  end

end

return userwrite
