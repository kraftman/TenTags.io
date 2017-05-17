
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
  print(ok,  tonumber(ok) == 0)
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
  print(to_json(ok))
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

  user.userLabels = {}
  local targetUserID
  for k, v in pairs(user) do
    if k:find('userlabel:') then
      targetUserID = k:match('userlabel:(.+)')
      user.userLabels[targetUserID] = v
      user[k] = nil
    end
  end

  user.fakeNames = user.fakeNames == '1' and true or false
  user.enablePM = user.enablePM == '1' and true or false
  user.hideSeenPosts = user.hideSeenPosts == '1' and true or false
  user.hideVotedPosts = user.hideVotedPosts == '1' and true or false
  user.hideClickedPosts = user.hideClickedPosts == '1' and true or false
  user.showNSFW = user.showNSFW == '1' and true or false
  user.showNSFL = user.showNSFL == '1' and true or false

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

function userread:GetUnseenPosts(baseKey, elements)
  local red = self:GetUserReadConnection()
  local sha1Key = checkKey:GetSHA1()

  red:init_pipeline()

  for _,v in pairs(elements) do
    red:evalsha(sha1Key,0,baseKey,10000,0.01,v)
  end

  local res, err = red:commit_pipeline()
  self:SetKeepalive(red)

  if err then
    ngx.log(ngx.ERR, 'unable to check for elements: ',err)
    return {}
  end

  for k,v in pairs(res) do
    if v == ngx.null then
      res[k] = nil
    end
  end

  return res
end

function userread:GetAllUserSeenPosts(userID,startRange,endRange)

  --ngx.log(ngx.ERR,startRange,' ',endRange,' ',userID)
  startRange = startRange or 0
  endRange = endRange or 1000
  local red = self:GetUserReadConnection()
  local ok, err = red:zrange('userSeen:'..userID, startRange, endRange)
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
