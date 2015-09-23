local cache = {}
local filterList = ngx.shared.filterlist
local filterDict = ngx.shared.filters
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


function cache:AddPost(post)
  result,err = postInfo:set(post.id,to_json(postInfo))
end

function cache:GetAllTags()
  local tags = lru:GetAllTags()
  if tags then
    print(to_json(tags))
    return tags
  end

  local res = redisread:GetAllTags()
  if res then
    lru:SetAllTags(res)
    return res
  else
    ngx.log(ngx.ERR, 'error requesting from api')
    return {}
  end
end


function cache:GetPost(postID)
  local res, err = postInfo:get(postID)
  if err then
    ngx.log(ngx.ERR, 'unable to load post info: ', err)
  end
  if res then
    return from_json(res)
  end

  local result = redisread:GetPost(postID)
  if result and result ~= ngx.null then
    print('found in redis')
    res, err = postInfo:set(postID,to_json(result))
    if err then
      ngx.log(ngx.ERR, 'unable to set postInfo: ',err)
    end
    return result
  else
    print('couldnt find post')
  end

end

function cache:GetFilter(filterName)
  local res = lru:GetFilter(filterName)
  if res then
    return res
  end
  local res, err = filterDict:get(filterName)
  if err then
    ngx.log(ngx.ERR, 'unable to get filter info from shdict: ',err)
  end
  if res then
    local filterInfo = from_json(res)
    lru:SetFilter(filterName,filterInfo)
    return filterInfo
  end

  local result = redisread:GetFilter(filterName)
  if result then
    res, err = filterDict:set(filterName,to_json(result))
    if err then
      ngx.log('unablet to set filterdict: ',err)
    end
    lru:SetFilter(filterName,result)
    return result
  else
    ngx.log(ngx.ERR, 'could not find filter')
  end


end

function cache:GetDefaultFrontPage(offset)
  offset = 0

  local frontPageList = self:LoadFrontPageList('default')

  local posts = {}

  local postID
  for i = 1,5 do

    postID = frontPageList[i]

    if postID then
      posts[postID] = self:GetPost(postID)

    end
  end

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
  local tags = self:GetAllTags()
  for k,v in pairs(tags) do
    if v.name == tagName then
      return v
    end
  end
  return
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
