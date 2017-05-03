

local M = {}

local redis = require 'resty.redis'
local to_json = (require 'lapis.util').to_json
local from_json = (require 'lapis.util').from_json


function M:GetRedisConnection(host)
  local red = redis:new()

  red:set_timeout(1000)
  local ok, err = red:connect(host, 6379)
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
  return self:GetRedisConnection('redis-user')
end

function M:GetUserReadConnection()
  return self:GetRedisConnection('redis-user')
end

function M:GetRedisReadConnection()
  return self:GetRedisConnection('redis-general')
end

function M:GetRedisWriteConnection()
  return self:GetRedisConnection('redis-general')
end

function M:GetCommentWriteConnection()
  return self:GetRedisConnection('redis-comment')
end

function M:GetCommentReadConnection()
  return self:GetRedisConnection('redis-comment')
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
