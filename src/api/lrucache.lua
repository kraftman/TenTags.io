local _M = {}
local lrucache = require "resty.lrucache"

local userFilters = lrucache.new(1000)  -- allow up to 200 items in the cache
local tags = lrucache.new(1)
local filters = lrucache.new(100)
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

function _M:SetAllTags(newTags)
  tags:set('all',newTags)
end

function _M:GetAllTags()
  return tags:get('all')
end

function _M:GetFilter(filterName)
  return tags:get(filterName)
end

function _M:SetFilter(filterName,filterInfo)
  return tags:set(filterName,filterInfo,600)
end

return _M
