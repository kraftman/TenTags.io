
local util = {}

util.locks = ngx.shared.locks
local redis = require 'resty.redis'

local REDIS_SERVER = 'redis-master'
--REDIS_SERVER = '192.168.1.30'

local sentinels = {
  { host = "master-sentinel", port = "26379" },
  { host = "api-sentinel", port = "26379" },
}

function util:GetLock(key, lockTime)
  local success, err = self.locks:add(key, true, lockTime)
  if not success then
    if err ~= 'exists' then
      ngx.log(ngx.ERR, 'failed to add lock key: ',err)
    end
    return nil
  end
  return true
end

function util:GetRedisConnection(host)
  local red = redis:new()

  red:set_timeout(1000)
  local ok, err = red:connect(host, 6379)
  if not ok then
    ngx.log(ngx.ERR, "failed to connect: ", err)
    return nil
  end
  return red
end


function util:GetUserWriteConnection()
  return self:GetRedisConnection('redis-user')
end

function util:GetUserReadConnection()
  return self:GetRedisConnection('redis-user')
end

function util:GetRedisReadConnection()
  return self:GetRedisConnection('redis-general')
end

function util:GetRedisWriteConnection()
  return self:GetRedisConnection('redis-general')
end

function util:GetCommentWriteConnection()
  return self:GetRedisConnection('redis-comment')
end

function util:GetCommentReadConnection()
  return self:GetRedisConnection('redis-comment')
end



--[[
function util:GetRedisConnectionFromSentinel(masterName, role)
  local redis_connector = require "resty.redis.connector"
  local rc = redis_connector.new()

  local redis, err = rc:connect{ url = "sentinel://"..masterName..":"..role, sentinels = sentinels }


  if not redis then
    ngx.log(ngx.ERR, 'error getting connection from master:', masterName, ', role: ',role, ', error: ', err)
    return nil
  else
    return redis
  end
end

function util:GetUserWriteConnection()
  return self:GetRedisConnectionFromSentinel('master-user', 'm')
end

function util:GetUserReadConnection()
  return self:GetRedisConnectionFromSentinel('master-user', 's')
end

function util:GetRedisReadConnection()
  return self:GetRedisConnectionFromSentinel('master-general', 's')
end

function util:GetRedisWriteConnection()
  return self:GetRedisConnectionFromSentinel('master-user', 'm')
end

function util:GetCommentWriteConnection()
  return self:GetRedisConnectionFromSentinel('master-user', 'm')
end

function util:GetCommentReadConnection()
  return self:GetRedisConnectionFromSentinel('master-user', 's')
end
--]]

function util:SetKeepalive(red)
  local ok, err = red:set_keepalive(10000, 200)
  if not ok then
      ngx.log(ngx.ERR, "failed to set keepalive: ", err)
      return
  end
end

return util
