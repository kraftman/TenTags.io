

--[[
user settings ands
seen posts
sent messages
recieved messages

]]

local checkKey = require 'redisscripts.checkkey'

local base = require 'redis.base'
local userread = setmetatable({}, base)



function userread:ConvertListToTable(list)
  local info = {}
  for i = 1,#list, 2 do
    info[list[i]] = list[i+1]
  end
  return info
end

function userread:GetNewUsers()
  local red = self:GetUserReadConnection()
  local ok, err = red:zrange('newAccounts', 0, 50,'WITHSCORES')
  self:SetKeepalive(red)
  ok = self:ConvertListToTable(ok)
  return ok, err
end

function userread:GetUserAlerts(userID, startAt, endAt)
  local red = self:GetUserReadConnection()
  local ok, err = red:zrangebyscore('UserAlerts:'..userID,startAt,endAt)
  if not ok then
    ngx.log(ngx.ERR, 'unable to get user alerts: ',err)
  end
  if ok == ngx.null then
    return {}
  else
    return ok
  end
end

function userread:SavedPostExists(userID, postID)
  local red = self:GetUserWriteConnection()
  local key = 'userSavedPost:'..userID

  local ok, err = red:sismember(key, postID)


  self:SetKeepalive(red)
  if not ok then
    return nil, err
  end
  if tonumber(ok) == 0 then
    return false
  end
  return ok, err

end

function userread:GetUserCommentVotes(userID)
  local red = self:GetUserReadConnection()
  local ok, err = red:smembers('userCommentVotes:'..userID)
  self:SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to get user comment votes:',err)
  end
  if ok == ngx.null then
    return {}
  else
    return ok
  end
end

function userread:GetAccount(accountID)
  local red = self:GetUserReadConnection()
  local ok, err = red:hgetall('account:'..accountID)
  if not ok or ok == ngx.null then
    return nil,err
  end
  if not next(ok) then
    return nil
  end

  local account = self:ConvertListToTable(ok)

  account.sessions = {}
  account.users = {}

  account.userCount = 0
  for k,v in pairs(account) do
    if k:find('^user:') then
      table.insert(account.users, v)
      account[k] = nil
      account.userCount = account.userCount +1
    elseif k:find('^session:') then
      local session = self:from_json(v)
      account.sessions[session.id] = session
      account[k] = nil
    end
  end

  account.modCount = tonumber(account.modCount or 0)


  return account

end


function userread:GetUserTagVotes(userID)
  local red = self:GetUserReadConnection()
  local ok, err = red:smembers('userTagVotes:'..userID)
  self:SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to get user tag votes: ',err)
  end
  if not ok or ok == ngx.null then
    return {}
  else
    return ok
  end
end

function userread:GetRecentPostVotes(userID, direction)
  local red = self:GetUserReadConnection()
  local ok, err = red:zrange('userPostVotes:date:'..direction..':'..userID,0, 100)
  self:SetKeepalive(red)

  if not ok then
    return nil, err
  end

  if ok == ngx.null then
    return {}
  else
    return ok
  end
end



function userread:GetUserPostVotes(userID)
  -- replace with bloom later
  local red = self:GetUserReadConnection()
  local ok, err = red:smembers('userPostVotes:'..userID)
  self:SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to get user post votes:',err)
  end
  if ok == ngx.null then
    return {}
  else
    return ok
  end
end

function userread:GetUser(userID)

  local red = self:GetUserReadConnection()
  local ok, err = red:hgetall('user:'..userID)
  self:SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR,'unable to get user: ',err)
  end

  if not ok or ok == ngx.null then

    return nil
  end

  local user = self:ConvertListToTable(ok)
  if not user.username then
    return nil
  end

  user.userLabels = {}
  local targetUserID
  for k, v in pairs(user) do
    if k:find('userlabel:') then
      targetUserID = k:match('userlabel:(.+)')
      user.userLabels[targetUserID] = v
      user[k] = nil
    elseif k:find('commentSubscriptions:') then
      user.commentSubscriptions = self:from_json(v) or {}
      user[k] = nil
    elseif k:find('commentSubscribers:') then
      user.commentSubscribers = self:from_json(v) or {}
      user[k] = nil
    elseif k:find('postSubscriptions:') then
      user.postSubscriptions = self:from_json(v) or {}
      user[k] = nil
    elseif k:find('postSubscribers:') then
      user.postSubscribers = self:from_json(v) or {}
      user[k] = nil
    elseif k:find('views:') then
      user.views = self:from_json(v) or {}
      user[k] = nil
    elseif k:find('blockedUsers:') then

      user.blockedUsers = self:from_json(v) or {}
      user[k] = nil
    end
  end

  if user.commentSubscribers == ngx.null or not user.commentSubscribers then
    user.commentSubscribers = {}
  end
  if user.blockedUsers == ngx.null or not user.blockedUsers then
    user.blockedUsers = {}
  end
  if user.commentSubscriptions == ngx.null or not user.commentSubscriptions then
    user.commentSubscriptions = {}
  end
  if user.postSubscribers == ngx.null or not user.postSubscribers then
    user.postSubscribers = {}
  end
  if user.postSubscriptions == ngx.null or not user.postSubscriptions then
    user.postSubscriptions = {}
  end

  user.fakeNames = user.fakeNames == '1' and true or false
  user.enablePM = user.enablePM == '1' and true or false
  user.hideSeenPosts = user.hideSeenPosts == '1' and true or false
  user.hideUnsubbedComments = user.hideUnsubbedComments == '1' and true or false
  user.hideVotedPosts = user.hideVotedPosts == '1' and true or false
  user.hideClickedPosts = user.hideClickedPosts == '1' and true or false
  user.showNSFL = user.showNSFL == '1' and true or false
  user.nsfwLevel = user.nsfwLevel and tonumber(user.nsfwLevel) or 0
  user.viewCount = user.viewCount or 1
  user.views = user.views or {}

  if user.deleted then
    return nil
  end

  return user

end


function userread:GetUserID(username)
  username = username:lower()
  local red = self:GetUserReadConnection()
  local ok,err = red:hget('userToID',username)
  self:SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to get userID from username:',err)
    return nil
  end

  if ok == ngx.null then
    return nil
  else
    return ok
  end
end


function userread:GetUserComments(userID, sortBy,startAt, range)
  local red = self:GetUserReadConnection()
  local ok, err = red:zrange('userComments:'..sortBy..':'..userID, startAt, startAt+range)
  self:SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to get user comments, ',err)
    return {}
  end
  if ok == ngx.null then
    return nil
  else
    return ok
  end
end

function userread:GetUserPosts(userID,startAt, range)
  local red = self:GetUserReadConnection()
  local ok, err = red:zrange('userPosts:date:'..userID, startAt, startAt+range)
  self:SetKeepalive(red)

  if ok == ngx.null then
    return nil
  else
    return ok
  end
end

function userread:GetUnseenParentIDs(baseKey, elements)
  local red = self:GetUserReadConnection()
  local sha1Key = checkKey:GetSHA1()

  red:init_pipeline()
    for _,v in pairs(elements) do
      red:evalsha(sha1Key,0,baseKey,10000,0.01,v.parentID)
    end
  local res, err = red:commit_pipeline()

  self:SetKeepalive(red)

  if err then
    ngx.log(ngx.ERR, 'unable to check for elements: ',err)
    return {}
  end

  local indexed = {}
  for k,v in pairs(res) do
    if v == ngx.null then
      res[k] = nil
    else
      indexed[v] = true
    end
  end

  return indexed
end

function userread:GetAllUserSeenPosts(userID,startAt,range)

  --ngx.log(ngx.ERR,startRange,' ',endRange,' ',userID)

  local red = self:GetUserReadConnection()
  local ok, err = red:zrange('userSeen:'..userID, startAt, startAt+range)
  self:SetKeepalive(red)

  if not ok then
    ngx.log(ngx.ERR,'unable to get user seen posts:',err)
    return {}
  end
  --ngx.log(ngx.ERR,self:to_json(ok))
  return ok ~= ngx.null and ok or {}
end

function userread:GetUserFilterIDs(userID)

  local red = self:GetUserReadConnection()

  local ok, err

  ok, err = red:smembers('userfilters:'..userID)

  self:SetKeepalive(red)
  --print(userID, self:to_json(ok))

  if not ok then
    ngx.log(ngx.ERR, 'error getting filter list for user "',userID,'", error:',err)
    return {}
  end

  if ok == ngx.null then
    return {}
  else
    return ok
  end

end


return userread
