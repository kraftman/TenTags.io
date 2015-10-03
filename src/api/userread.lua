
local redis = require "resty.redis"
local tinsert = table.insert

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
  local ok, err = red:set_keepalive(10000, 100)
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

function userread:GetUserInfo(userID)
  local red = GetRedisConnection()
  local ok, err = red:hgetall('user:'..userID)
  SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to get user info:',err)
  end

  if ok == ngx.null then
    return {}
  else
    return self:ConvertListToTable(ok)
  end
end

function userread:GetUserByEmail(email)
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

function userread:GetUserFilterIDs(userID)

  local red = GetRedisConnection()

  local ok, err

  ok, err = red:smembers('userfilters:'..userID)

  SetKeepalive(red)

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
