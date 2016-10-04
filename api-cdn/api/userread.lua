
--[[
user settings ands
seen posts
sent messages
recieved messages

]]

local redis = require "resty.redis"
local checkKey = require 'redisscripts.checkkey'
local userread = {}
local util = require 'util'
local from_json = (require 'lapis.util').from_json
local to_json = (require 'lapis.util').to_json



function userread:ConvertListToTable(list)
  local info = {}
  for i = 1,#list, 2 do
    info[list[i]] = list[i+1]
  end
  return info
end

function userread:GetUserAlerts(userID, startAt, endAt)
  local red = util:GetUserReadConnection()
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

function userread:GetUserCommentVotes(userID)
  local red = util:GetUserReadConnection()
  local ok, err = red:smembers('userCommentVotes:'..userID)
  util:SetKeepalive(red)
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
  local red = util:GetUserReadConnection()
  local ok, err = red:hgetall('account:'..accountID)
  if not ok or ok == ngx.null then
    return nil
  end

  local account = self:ConvertListToTable(ok)

  account.sessions = {}
  account.users = {}

  for k,v in pairs(account) do
    if k:find('^user:') then
      table.insert(account.users, v)
      account[k] = nil
    elseif k:find('^session:') then
      local session = from_json(v)
      account.sessions[session.id] = session
      account[k] = nil
    end
  end
  
  account.modCount = tonumber(account.modCount or 0)


  return account

end


function userread:GetUserTagVotes(userID)
  local red = util:GetUserReadConnection()
  local ok, err = red:smembers('userTagVotes:'..userID)
  util:SetKeepalive(red)
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
  local red = util:GetUserReadConnection()
  local ok, err = red:smembers('userPostVotes:'..userID)
  util:SetKeepalive(red)
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
  local red = util:GetUserReadConnection()
  local ok, err = red:hgetall('user:'..userID)
  util:SetKeepalive(red)
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

  return user

end


function userread:GetUserID(username)
  username = username:lower()
  local red = util:GetUserReadConnection()
  local ok,err = red:hget('userToID',username)
  util:SetKeepalive(red)
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


function userread:GetUserComments(userID)
  local red = util:GetUserReadConnection()
  local ok, err = red:zrange('userComments:'..userID,0,-1)
  util:SetKeepalive(red)
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

function userread:GetMasterUserByEmail(email)
  local red = util:GetUserReadConnection()
  local ok, err = red:hget('useremails',email)
  util:SetKeepalive(red)

  if not ok then
    ngx.log(ngx.ERR, 'unable to get user info:',err)
  end

  if ok == ngx.null then
    return
  else
    return ok
  end
end

function userread:GetUnseenPosts(baseKey, elements)
  local red = util:GetUserReadConnection()
  local sha1Key = checkKey:GetSHA1()

  red:init_pipeline()

  for _,v in pairs(elements) do
    red:evalsha(sha1Key,0,baseKey,10000,0.01,v)
  end

  local res, err = red:commit_pipeline()
  util:SetKeepalive(red)

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
  local red = util:GetUserReadConnection()
  local ok, err = red:zrange('userSeen:'..userID, startRange, endRange)
  util:SetKeepalive(red)

  if not ok then
    ngx.log(ngx.ERR,'unable to get user seen posts:',err)
    return {}
  end
  --ngx.log(ngx.ERR,to_json(ok))
  return ok ~= ngx.null and ok or {}
end

function userread:GetUserFilterIDs(userID)

  local red = util:GetUserReadConnection()

  local ok, err

  ok, err = red:smembers('userfilters:'..userID)

  util:SetKeepalive(red)
  --print(userID, to_json(ok))

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
