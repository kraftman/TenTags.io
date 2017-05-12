

local redisRead = (require 'redis.db').redisRead
local cache = require 'api.cache'

local M = {}

function M:GetBacklogStats(jobName, startAt, endAt)
  local ok, err = redisRead:GetBacklogStats(jobName, startAt, endAt)
  if not ok then
    ngx.log(ngx.ERR, 'error getting stat backlog: ', err)
    return nil, 'couldnt get stats'
  end
  return ok
end

function M:GetSiteUniqueStats()
  local ok, err = redisRead:GetSiteUniqueStats('sitestat:device:minutes')

  return ok, err
end

function M:GetSiteStats()
  return redisRead:GetSiteStats()
end

function M:GetNewUsers(userID)
  local user = cache:GetUser(userID)
  if not user.role == 'Admin' then
    return nil, 'no admin'
  end

  return cache:GetNewUsers()
end

return M
