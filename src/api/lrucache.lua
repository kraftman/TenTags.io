local _M = {}
local lrucache = require "resty.lrucache"

local userFilterIDs = lrucache.new(1000)  -- allow up to 200 items in the cache
if not userFilterIDs then
  ngx.log(ngx.ERR, 'unable to create userFilterIDs  cache: ',err or 'unkown')
end
local tags = lrucache.new(1)
if not tags then
  ngx.log(ngx.ERR, 'unable to create the tags cache: ',err or 'unkown')
end
local filters = lrucache.new(1000)
if not filters then
  ngx.log(ngx.ERR, 'unable to create the filters cache: ',err or 'unkown')
end


function _M:GetUserFilterIDs(username)
  return userFilterIDs:get(username,5)
end

function _M:SetUserFilterIDs(username,filters)
  userFilterIDs:set(username,filters)
end

function _M:SetAllTags(newTags)
  tags:set('all',newTags)
end

function _M:GetAllTags()
  return tags:get('all')
end

function _M:GetFilter(filterName)
  return filters:get(filterName)
end

function _M:SetFilter(filterName,filterInfo)
  return filters:set(filterName,filterInfo,600)
end


return _M
