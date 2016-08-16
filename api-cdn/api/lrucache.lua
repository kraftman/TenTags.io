local _M = {}
local lrucache = require "resty.lrucache"

local userFilterIDs = lrucache.new(100)  -- allow up to 200 items in the cache
local postComments = lrucache.new(1000)
if not userFilterIDs then
  ngx.log(ngx.ERR, 'unable to create userFilterIDs  cache')
end
local tags = lrucache.new(1)
if not tags then
  ngx.log(ngx.ERR, 'unable to create the tags cache: ')
end
local filters = lrucache.new(1000)
if not filters then
  ngx.log(ngx.ERR, 'unable to create the filters cache: ')
end


function _M:GetUserFilterIDs(username)
  return userFilterIDs:get(username,5)
end

function _M:SetUserFilterIDs(username,userFilters)
  userFilterIDs:set(username,userFilters)
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

function _M:SetComments(postID,comments)
  ngx.say('adding ',#comments,' comments, key: ', postID)
  postComments:set(postID,comments)
  ngx.say(string.format("</br>Worker %d: GC size: %.3f KB", ngx.var.pid, collectgarbage("count")))
end

function _M:GetComments(key)
  --ngx.say('</br> getting comments for key:',key)

  return postComments:get(key)
end


return _M
