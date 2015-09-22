local cache = {}
local filterList = ngx.shared.filterlist
local frontpages = ngx.shared.frontpages
local tags = ngx.shared.tags
local postInfo = ngx.shared.postinfo
local to_json = (require 'lapis.util').to_json
local from_json = (require 'lapis.util').from_json
local redisread = require 'api.redisread'
local lru = require 'api.lrucache'

local FILTER_LIST_CACHE_TIME = 5
local TAG_CACHE_TIME = 5
local FRONTPAGE_CACHE_TIME = 5


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
  local result,err = tags:get('all')
  if err then
    ngx.log(ngx.ERR, 'unable to load all tags: ',err)
  end

  if result then
    return from_json(result)
  end

  local res = ngx.location.capture('/cache/tags')
  if res.status == 200 then
    result,err = tags:set('all',res.body,60)
    if err then
      ngx.log(ngx.ERR, 'unable to set tags ',err)
    end
    return from_json(res.body)
  else
    ngx.log(ngx.ERR, 'error requesting from api, status:',status,' message: ',res.body)
    return {}
  end

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

  local postList = table.concat(uncached,',')
  local res = ngx.location.capture('/cache/posts?posts='..postList)
  if not res or res.status ~= 200 then
    ngx.log(ngx.ERR, 'error requesting upstream: ',err,' status: ',res.status)
    return
  end

  for k,v in pairs(from_json(res.body)) do
    if posts[k] then
      posts[k] = v
    end
  end

end

function cache:GetDefaultFrontPage(offset)
  offset = offset or 0

  local frontPageList = self:LoadFrontPageList('default')
  local posts = {}

  local postID
  for i = 1+offset,10+offset do
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
    return from_json(result)
  end

  local res = redisread:LoadFrontPageList(username)

  if res then
    frontpages:set(username,to_json(res),FRONTPAGE_CACHE_TIME)
    return res
  else
    ngx.log(ngx.ERR, 'error requesting from upstream: code: ',res.status,' body:',res.body)
  end


end

function cache:GetTag(tagName)
  local result,err = tags:get(tagName)
  if err then
    ngx.log(ngx.ERR, 'unable to load from tags: ',err)
    return
  end
  if result then
    return from_json(result)
  end

  local res= ngx.location.capture('/cache/tag/'..tagName)
  if res.status == 200 then
    local tagInfo = from_json(res.body)
    if tagInfo.name then
      tags:set(tagInfo.name,res.body,TAG_CACHE_TIME)
      return tagInfo
    end
  else
    ngx.log(ngx.ERR, 'unable to get tag: code ',res.status,' body: ',res.body)
  end

end


function cache:GetDefaultFilters()
  local filters = lru:GetDefaultFilters()
  if filters then
    return filters
  end

  local result,err = filterList:get('default')
  if err then
    ngx.log(ngx.ERR, 'unable to get from shdict filterelist: ',err)
    return {}
  end
  if result then
    result = from_json(result)
    lru:SetDefaultFilters(result)
    return result
  end

  local res = redisread:GetUserFilters('default')
  if res then
    lru:SetDefaultFilters(result)
    filterList:set('default',to_json(res),FILTER_LIST_CACHE_TIME)
    return res
  else
    return {}
  end
end


return cache
