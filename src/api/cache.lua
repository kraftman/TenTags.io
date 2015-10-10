local cache = {}
local userFilterIDs = ngx.shared.userFilterIDs
local filterDict = ngx.shared.filters
local frontpages = ngx.shared.frontpages
local userUpdateDict = ngx.shared.userupdates
local userSessionSeenDict = ngx.shared.usersessionseen
local tags = ngx.shared.tags
local postInfo = ngx.shared.postinfo
local to_json = (require 'lapis.util').to_json
local from_json = (require 'lapis.util').from_json
local redisread = require 'api.redisread'
local userRead = require 'api.userread'
local lru = require 'api.lrucache'
local tinsert = table.insert

local FILTER_LIST_CACHE_TIME = 5
local TAG_CACHE_TIME = 5
local FRONTPAGE_CACHE_TIME = 5

function cache:GetMasterUserInfo(masterID)
  return userRead:GetMasterUserInfo(masterID)
end

function cache:GetUserInfo(userID)
  return userRead:GetUserInfo(userID)
end

function cache:GetMasterUserByEmail(email)
  email = email:lower()
  local userID = userRead:GetMasterUserByEmail(email)
  if not userID then
    return
  end

  local userInfo = self:GetMasterUserInfo(userID)
  return userInfo

end


function cache:AddPost(post)
  result,err = postInfo:set(post.id,to_json(postInfo))
end

function cache:GetAllTags()
  local tags = lru:GetAllTags()
  if tags then
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

function cache:GetFilterPosts(filter)

  local filterIDs = redisread:GetFilterPosts(filter)
  local posts = {}
  for k,v in pairs(filterIDs) do
    tinsert(posts, self:GetPost(v))
  end
  return posts

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

function cache:GetIndexedUserFilterIDs(userID)
  local indexed = {}
  for k,v in pairs(self:GetUserFilterIDs(userID)) do
    indexed[v] = true
  end
  return indexed
end

function cache:GetUserSessionSeenPosts(userID)
  local result = userSessionSeenDict:get(userID)
  if not result then
    return {}
  end

  local indexedSeen = {}
  for k,v in pairs(from_json(result)) do
    indexedSeen[v] = true
  end

  return indexedSeen
end

function cache:UpdateUserSessionSeenPosts(userID,indexedSeenPosts)
  local flatSeen = {}
  for k,v in pairs(indexedSeenPosts) do
    tinsert(flatSeen,k)
  end
  local ok,err,forced = userSessionSeenDict:set(userID,to_json(flatSeen))
  if err then
    ngx.log(ngx.ERR, 'unable to write user seen:',err)
  end
  if forced then
    ngx.log(ngx.ERR, 'forced write to user seen posts, increase dict size!')
  end

end

function cache:GetFreshUserPosts(userID) -- needs caching
  -- get a list of all potential posts, add filters later
  local allPostIDs = redisread:GetAllBestPosts(0,100)

  -- get the filters the user wants to see
  local userFilterIDs = self:GetIndexedUserFilterIDs(userID)
  local postID,filterID
  local filteredPosts = {}
  local postFilterIDs = {}

  for k, v in pairs(allPostIDs) do
    filterID,postID = v:match('(%w+):(%w+)')
    tinsert(filteredPosts,postID)
  end


  local unseenPosts = userRead:GetUnseenPosts(userID,filteredPosts)

  -- add these unseenPosts to seen which should also remove duplicates

  return unseenPosts
end

function cache:GetUserFrontPage(userID)
  local sessionSeenPosts = cache:GetUserSessionSeenPosts(userID)
  local freshPosts = cache:GetFreshUserPosts(userID)


  local newPostIDs = {}

  for k,postID in pairs(freshPosts) do
    if not sessionSeenPosts[postID] then
      sessionSeenPosts[postID] = true
      tinsert(newPostIDs,postID)
    end
    -- stop when we have a page worth
    if #newPostIDs > 10 then
      break
    end
  end

  self:UpdateUserSessionSeenPosts(userID,sessionSeenPosts)


  local postsWithInfo = {}

  for k,postID in pairs(newPostIDs) do
    tinsert(postsWithInfo, self:GetPost(postID))
  end

  return postsWithInfo
end


function cache:GetDefaultFrontPage(range,filter)

  -- fresh, load from datescore
  -- new, load from date,
  -- best, load from date then sort by best
  local postIDs = {}
  local filterFunction
  if filter == 'new' then
    filterFunction = 'GetAllNewPosts'
  elseif filter == 'best' then
    filterFunction = 'GetAllBestPosts'
  else
    filterFunction = 'GetAllFreshPosts'
  end

  local filterIDs = self:GetIndexedUserFilterIDs('default')


  local unfilteredOffset = 0
  local unfilteredPosts = {}
  local filteredPosts = {}
  local filterID, postID
  local seenPosts = {}
  local finalPostIDs = {}

  while #filteredPosts < range+10 do
    --load new posts from redis if needed

    unfilteredPosts = redisread[filterFunction](redisread, unfilteredOffset, unfilteredOffset+1000)
    unfilteredOffset = unfilteredOffset + 1000
    if #unfilteredPosts == 0 then
      break
    end

    for k, v in pairs(unfilteredPosts) do

      filterID,postID = v:match('(%w+):(%w+)')

      if filterIDs[filterID] and not seenPosts[postID] then
        seenPosts[postID] = true
        tinsert(finalPostIDs,postID)
      end
    end

  end

  local postsWithInfo = {}
  for i = range,range+10 do
    local postID = finalPostIDs[i]
    if postID then
      tinsert(postsWithInfo, self:GetPost(postID))
    end
  end

  return postsWithInfo
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


function cache:GetUserFilterIDs(userID)
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

  local res = userRead:GetUserFilterIDs(userID)
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
