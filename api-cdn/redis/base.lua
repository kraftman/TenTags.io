

local M = {}

local redis = require 'resty.redis'
local to_json = (require 'lapis.util').to_json
local from_json = (require 'lapis.util').from_json


local function GetConnectionDetails(name)
  local data = os.getenv(name)
  if not data then
    return nil
  end
  local host, port = data:match('(.-):(.+)')
  return host, tonumber(port)
end


local genReadHost, genReadPort = GetConnectionDetails('REDIS_GENERAL_READ')
local genWriteHost, genWritePort = GetConnectionDetails('REDIS_GENERAL_WRITE')
local userReadHost, userReadPort = GetConnectionDetails('REDIS_USER_READ')
local userWriteHost, userWritePort = GetConnectionDetails('REDIS_USER_WRITE')
local commentReadHost, commentReadPort = GetConnectionDetails('REDIS_COMMENT_READ')
local commentWriteHost, commentWritePort = GetConnectionDetails('REDIS_COMMENT_WRITE')


function M:GetRedisConnection(host, port)
  --print('gettings redis connection: ', host)
  --print(debug.traceback())
  --print(ngx.var.uri)
  local red = redis:new()
  port = port or 6379
  red:set_timeout(2000)
  local ok, err = red:connect(host, port)
  if not ok then
    ngx.log(ngx.ERR, "failed to connect: ", err)
    return nil
  end
  return red
end

function M:from_json(data)
  return from_json(data)
end

function M:to_json(data)
  return to_json(data)
end


function M:SplitShortURL(shortURL)
  return shortURL:sub(1,5),shortURL:sub(6,-1)
end


function M:GetUserWriteConnection()
  return self:GetRedisConnection(userWriteHost or 'redis-user', userWritePort)
end

function M:GetUserReadConnection()
  return self:GetRedisConnection(userReadHost  or 'redis-user', userReadPort)
end

function M:GetRedisReadConnection()
  return self:GetRedisConnection(genReadHost  or 'redis-general', genReadPort)
end

function M:GetRedisWriteConnection()
  return self:GetRedisConnection(genWriteHost or 'redis-general', genWritePort)
end

function M:GetCommentWriteConnection()
  return self:GetRedisConnection(commentWriteHost or 'redis-comment' , commentWritePort)
end

function M:GetCommentReadConnection()
  return self:GetRedisConnection(commentReadHost or 'redis-comment', commentReadPort)
end


function M:SetKeepalive(red)
  local ok, err = red:set_keepalive(1000, 1000)
  if not ok then
      ngx.log(ngx.ERR, "failed to set keepalive: ", err)
      return
  end
end


M.__index = M

return M
