

local cache = {}
local http = require 'http'
local upstream = require "ngx.upstream"
local get_servers = upstream.get_servers
local filterList = ngx.shared.filterlist
local frontpages = ngx.shared.frontpages
local postInfo = ngx.shared.postinfo
local util = require("lapis.util")

local function GetCacheURL()
  local servers = get_servers('cache')

  return servers[1].addr
end

function cache:LoadCachedPosts(posts)
  local result,err
  for postID,v in pairs(posts) do
    result,err = postInfo:get(postID)
    if result then
      posts[postID] = result
      posts[postID].cached = true
    end
  end
end

function cache:GetAllTags()

end

function cache:LoadUncachedPosts(posts)
  local uncached = {}
  local found = false
  for postID, v in pairs(posts) do
    if not v.cached then
      table.insert(uncached,postID)
      found = true
    end
  end
  if not found then
    return
  end

  local httpc = http.new()
  local cacheURL = 'http://'..GetCacheURL()
  local postList = table.concat(uncached,',')
  local res, err = httpc:request_uri(cacheURL..'/posts?posts='..postList)
  if not res or res.status ~= 200 then
    ngx.log(ngx.ERR, 'error requesting upstream: ',err,' status: ',res.status)
    return
  end

  for k,v in pairs(util.from_json(res.body)) do
    if posts[k] then
      posts[k] = v
    end
  end

end

function cache:LoadFrontPage(username,offset)
  offset = offset or 0

  local frontPageList = self:LoadFrontPageList(username)
  local posts = {}
  local max = math.min(#frontPageList,offset)
  local postID
  for i = offset, offset+10 do
    postID = frontPageList[i]
    if postID then
      posts[postID] = {}
    end
  end
  self:LoadCachedPosts(posts)
  self:LoadUncachedPosts(posts)

  return posts

end

function cache:LoadFrontPageList(username)
  local result,err = frontpages:get(username)
  if err then
    ngx.log(ngx.ERR, 'error getting frontpage for user:',username,', err:', err)
    return {}
  end
  if result then
    return util.from_json(result)
  end

  --need to build a frontpage from each filter they have
  local httpc = http.new()
  local cacheURL = GetCacheURL()
  local res, err = httpc:request_uri('http://'..cacheURL..'/frontpage/'..username)
  if not res then
    ngx.log(ngx.ERR, 'error requesting upstream: ',err)
    return {}
  end

  if res.status == 200 then
     frontpages:set(username,res.body,600)
     return util.from_json(res.body)
  elseif res.status == 404 then
    return {}
  else
    ngx.log(ngx.ERR, 'error requesting from upstream: code: ',res.status,' body:',res.body)
  end


end

function cache:LoadFilterList(username)
  local result,err = filterList:get('default')
  if err then
    ngx.log(ngx.ERR, 'unable to get from shdict filterelist: ',err)
    return {}
  end
  if result then
    return util.from_json(result)
  end


  local httpc = http.new()
  local cacheURL = GetCacheURL()
  print('http://'..cacheURL..'/filterlist/'..username)
  local res, err = httpc:request_uri('http://'..cacheURL..'/filterlist/'..username)

  if not res then
    ngx.log(ngx.ERR, 'error requesting upstream: ',err)
    return {}
  end

  if res.status == 200 then
    print(res.body)
     filterList:set(username,res.body,5)
     return util.from_json(res.body)
  elseif res.status == 404 then
    return {}
  else
    ngx.log(ngx.ERR, 'error requesting from upstream: code: ',res.status,' body:',res.body)
  end
end



return cache
