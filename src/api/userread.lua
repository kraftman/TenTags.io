
--[[
user settings ands
seen posts
sent messages
recieved messages

]]

local redis = require "resty.redis"
local checkKey = require 'redisscripts.checkkey'

local userread = {}

local function GetRedisConnection()
  local red = redis:new()
  red:set_timeout(1000)
  local ok, err = red:connect("127.0.0.1", 6379)
  if not ok then
      ngx.say("failed to connect: ", err)
      return
  end
  return red
end

local function SetKeepalive(red)
  local ok, err = red:set_keepalive(10, 10)
  if not ok then
      ngx.say("failed to set keepalive: ", err)
      return
  end
end

function userread:ConvertListToTable(list)
  local info = {}
  for i = 1,#list, 2 do
    info[list[i]] = list[i+1]
  end
  return info
end

function userread:GetUserAlerts(userID, startAt, endAt)
  local red = GetRedisConnection()
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
  local red = GetRedisConnection()
  local ok, err = red:smembers('userCommentVotes:'..userID)
  SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to get user comment votes:',err)
  end
  if ok == ngx.null then
    return {}
  else
    return ok
  end
end

function userread:GetUserTagVotes(userID)
  local red = GetRedisConnection()
  local ok, err = red:smembers('userTagVotes:'..userID)
  SetKeepalive(red)
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
  local red = GetRedisConnection()
  local ok, err = red:smembers('userPostVotes:'..userID)
  SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to get user post votes:',err)
  end
  if ok == ngx.null then
    return {}
  else
    return ok
  end
end

function userread:GetUserInfo(userID)
  local red = GetRedisConnection()
  local ok, err = red:hgetall('user:'..userID)
  SetKeepalive(red)
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
  local red = GetRedisConnection()
  local ok,err = red:hget('userToID',username)
  SetKeepalive(red)
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
  local red = GetRedisConnection()
  local ok, err = red:zrange('userComments:'..userID,0,-1)
  SetKeepalive(red)
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

function userread:GetMasterUserInfo(masterID)

  local red = GetRedisConnection()
  local ok, err = red:hgetall('master:'..masterID)

  if not ok then
    ngx.log(ngx.ERR, 'unable to get user info:',err)
  end
  local master
  if ok == ngx.null then
    return nil
  else
    master = self:ConvertListToTable(ok)
  end

  ok, err = red:smembers('masterusers:'..masterID)
  SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to get master users:',err)
  end
  master.users = ok

  return master
end

function userread:GetMasterUserByEmail(email)
  local red = GetRedisConnection()
  local ok, err = red:hget('useremails',email)
  SetKeepalive(red)

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
  local red = GetRedisConnection()
  red:init_pipeline()
    local sha1Key = checkKey:GetSHA1()

    for _,v in pairs(elements) do
      red:evalsha(sha1Key,0,baseKey,10000,0.01,v)
    end
  local res, err = red:commit_pipeline()
  SetKeepalive(red)

  if err then
    ngx.log(ngx.ERR, 'unable to check for elemets: ',err)
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
  local red = GetRedisConnection()
  local ok, err = red:zrange('userSeen:'..userID, startRange, endRange)
  SetKeepalive(red)

  if not ok then
    ngx.log(ngx.ERR,'unable to get user seen posts:',err)
    return {}
  end
  --ngx.log(ngx.ERR,to_json(ok))
  return ok ~= ngx.null and ok or {}
end

function userread:GetUserFilterIDs(userID)

  local red = GetRedisConnection()

  local ok, err

  ok, err = red:smembers('userfilters:'..userID)

  SetKeepalive(red)
  print(userID, to_json(ok))

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
