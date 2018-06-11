
local app_helpers = require("lapis.application")
local assert_error = app_helpers.assert_error


local redisRead = (require 'redis.redisread')
local cache = require 'api.cache'

local M = {}

function M:GetBacklogStats(jobName, startAt, endAt)
  return assert_error(redisRead:GetBacklogStats(jobName, startAt, endAt))
end

function M:GetSiteUniqueStats()
  return redisRead:GetSiteUniqueStats('sitestat:device:minutes')
end

function M:GetSiteStats()
  return redisRead:GetSiteStats()
end

function M:GetNewUsers(userID)
  local user = assert_error(cache:GetUser(userID))
  if not user.role == 'Admin' then
    return nil, 'no admin'
  end

  return assert_error(cache:GetNewUsers())
end

function M:GetReports(userID)
  local user = assert_error(cache:GetUser(userID))
  if not user.role == 'Admin' then
    return nil, 'no admin'
  end

  return assert_error(cache:GetReports())
end

return M
