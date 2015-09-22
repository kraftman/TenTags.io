local _M = {}
local lrucache = require "resty.lrucache"

local userFilters = lrucache.new(1000)  -- allow up to 200 items in the cache
if not userFilters then
    return error("failed to create the cache: " .. (err or "unknown"))
end

function _M:GetUserFilters(username)
  return userFilters:get(username)
end

function _M:SetUserFilters(username,filters)
  userFilters:set(username,filters)
end

function _M:GetDefaultFilters()
  return userFilters:get('default')
end

function _M:SetDefaultFilters(filters)
  userFilters:set('default',filters,60)
end

return _M
