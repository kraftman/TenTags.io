local cache = {}
local userFilterIDs = ngx.shared.userFilterIDs
local filterDict = ngx.shared.filters
local frontpages = ngx.shared.frontpages
local tags = ngx.shared.tags
local postInfo = ngx.shared.postinfo
local to_json = (require 'lapis.util').to_json
local from_json = (require 'lapis.util').from_json
local redisread = require 'api.redisread'
local lru = require 'api.lrucache'
local tinsert = table.insert

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
  --[[
  local res, err = postInfo:get(postID)
  if err then
    ngx.log(ngx.ERR, 'unable to load post info: ', err)
  end
  if res then
    return from_json(res)
  end
  --]]

  local result = redisread:GetPost(postID)

  return result or {}
  --[[
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
  --]]

end



function cache:GetFilterID(filterName)
  --cache later
  return redisread:GetFilterID(filterName)
end

function cache:GetFilterByName(filterName)
  local filterID = self:GetFilterID(filterName)
  return self:GetFilterByID(filterID) or {}
end

function cache:GetFilterByID(filterID)
  --[[
  local res = lru:GetFilter(filterID)
  if res then
    return res
  end
  local res, err = filterDict:get(filterID)
  if err then
    ngx.log(ngx.ERR, 'unable to get filter info from shdict: ',err)
  end
  if res then
    local filterInfo = from_json(res)
    lru:SetFilter(filterID,filterInfo)
    return filterInfo
  end
  ]]

  local result = redisread:GetFilter(filterID)
  return result or {}
  --[[
  if result then
    res, err = filterDict:set(filterID,to_json(result))
    if err then
      ngx.log('unablet to set filterdict: ',err)
    end
    lru:SetFilter(filterID,result)
    return result
  else
    ngx.log(ngx.ERR, 'could not find filter')
  end
  ]]

end

function cache:GetFilterIDsByTags(tags)

  -- return all filters that are interested in these tags
  return redisread:GetFilterIDsByTags(tags)

end



function cache:GetFilterInfo(filterIDs)
  local filterInfo = {}
  for k,v in pairs(filterIDs) do
    filterInfo[k] = self:GetFilterByID(v)
  end
  return filterInfo
end

function cache:GetFiltersBySubs(startAt,endAt)

  local filterIDs = redisread:GetFiltersBySubs(startAt, endAt)
  if not filterIDs then
    return {}
  end
  return self:GetFilterInfo(filterIDs)
end

function cache:GetDefaultFrontPage(offset)
  offset = offset or 0

  local frontPageList = self:LoadFrontPageList('default')
  print(#frontPageList)

  local posts = {}

  local postID
  for i = offset+1,offset+10 do
    print(i)
    postID = frontPageList[i]

    if postID then
      posts[postID] = self:GetPost(postID)
    end
  end

  return posts

end

function cache:LoadFrontPageList(username)


  --[[
  local result,err = frontpages:get(username)
  if err then
    ngx.log(ngx.ERR, 'error getting frontpage for user:',username,', err:', err)
    return {}
  end
  if result then
    return from_json(result)
  end
  ]]

  local res = redisread:LoadFrontPageList(username)
  --print(to_json(res))

  --later on we need to add filters to post where there are multiple
  local posts = {}
  for filterID,filterPosts in pairs(res) do
    for _,postID in pairs(filterPosts) do
      tinsert(posts,postID)
    end
  end
  --print(to_json(posts))
  return posts
  --[[
  if res then
    frontpages:set(username,to_json(res),FRONTPAGE_CACHE_TIME)
    return res
  else
    ngx.log(ngx.ERR, 'error requesting from upstream: code: ',res.status,' body:',res.body)
  end
  --]]
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


function cache:GetUserFilterIDs(username)
  username = username or 'default'
  --[[

  local filters = lru:GetUserFilterIDs(username)
  if filters then
    return filters
  end

  local result,err = userFilterIDs:get(username)
  if err then
    ngx.log(ngx.ERR, 'unable to get from shdict filterlist: ',err)
    return {}
  end

  if result then
    result = from_json(result)
    lru:SetUserFilterIDs(username,result)
    return result
  end
  ]]

  local res = redisread:GetUserFilterIDs(username)
  return res or {}
  --[[
  if res then
    lru:SetUserFilterIDs(username,result)
    userFilterIDs:set('default',to_json(res),FILTER_LIST_CACHE_TIME)
    return res
  else
    return {}
  end
  --]]
end


return cache
