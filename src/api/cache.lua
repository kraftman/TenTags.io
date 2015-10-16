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
local commentRead = require 'api.commentread'
local lru = require 'api.lrucache'
local tinsert = table.insert


function cache:GetMasterUserInfo(masterID)
  return userRead:GetMasterUserInfo(masterID)
end


function cache:GetThread(threadID)
  return redisread:GetThreadInfo(threadID)
end

function cache:GetThreads(userID)
  local threadIDs = redisread:GetUserThreads(userID)
  local threads = redisread:GetThreadInfos(threadIDs)

  return threads
end

function cache:GetUserInfo(userID)
  return userRead:GetUserInfo(userID)
end


function cache:GetUserAlerts(userID)
  local user = self:GetUserInfo(userID)
  if not user.alertCheck then
    user.alertCheck = 0
  end
  local alerts = userRead:GetUserAlerts(userID,user.alertCheck, ngx.time())
  --ngx.log(ngx.ERR, to_json(alerts))
  return alerts
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

function cache:GetUserID(username)
  return userRead:GetUserID(username)
end

function cache:GetComment(commentID)
  return commentRead:GetComment(commentID)
end

function cache:GetUserComments(userID)
  local postIDcommentIDs = userRead:GetUserComments(userID)
  if not postIDcommentIDs then
    return {}
  end
  local commentInfo = commentRead:GetUserComments(postIDcommentIDs)
  for k,v in pairs(commentInfo) do
    commentInfo[k] = from_json(v)
  end
  return commentInfo
end

function cache:AddChildren(parentID,flat)
  local t = {}
  for k,v in pairs(flat[parentID]) do
    t[v.id] = self:AddChildren(v.id,flat)
  end

  return t
end

function cache:GetUsername(userID)
  local user = self:GetUserInfo(userID)
  if user then
    return user.username
  end
end

function cache:GetPostComments(postID)
  local flatComments = commentRead:GetPostComments(postID)

  local flat = {}
  flat[postID] = {}
  local indexedComments = {}

  for k,v in pairs(flatComments) do
    ngx.log(ngx.ERR, k,' userID: ',to_json(v))
    flatComments[k] = from_json(v)
    flatComments[k].username = self:GetUsername(flatComments[k].createdBy)
    ngx.log(ngx.ERR,flatComments[k].username)
  end

  for k,comment in pairs(flatComments) do
    if not flat[comment.parentID] then
      flat[comment.parentID] = {}
    end
    if not flat[comment.id] then
      flat[comment.id] = {}
    end
    tinsert(flat[comment.parentID],comment)
    indexedComments[comment.id] = comment
  end

  for k,v in pairs(flat) do
    table.sort(v,function(a,b)
      if a.up+a.down == b.up+b.down then
        return a.createdAt > b.createdAt
      end
      return (a.up+a.down > b.up+b.down)
    end)
  end

  local tree = self:AddChildren(postID,flat)
  print(to_json(tree))
  return tree,indexedComments
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

  ok, err = userUpdateDict:set(userID,1)

end

function cache:GetFreshUserPosts(userID,filter) -- needs caching
  -- the results of this need to be cached for a shorter duration than the
  -- frequency that session seen posts are flushed to user seen
  -- so that we can ignore session seen posts here

  local startRange,endRange = 0,1000
  local freshPosts,filteredPosts = {},{}
  local postID,filterID
  local userFilterIDs = self:GetIndexedUserFilterIDs(userID)

  local filterFunction
  if filter == 'new' then
    filterFunction = 'GetAllNewPosts'
  elseif filter == 'best' then
    filterFunction = 'GetAllBestPosts'
  elseif filter == 'seen' then
    filterFunction = 'GetAllUserSeenPosts'
  else
    filterFunction = 'GetAllFreshPosts'
  end
  --ngx.log(ngx.ERR,'filter:',filter,filterFunction)

  while #freshPosts < 100 do

    local allPostIDs
    if filter == 'seen' then
      allPostIDs = userRead[filterFunction](userRead,userID,startRange,endRange)
      ngx.log(ngx.ERR,'posts:',#allPostIDs)
    else
      allPostIDs = redisread[filterFunction](redisread,startRange,endRange)
    end
    -- if weve hit the end then return regardless
    if #allPostIDs == 0 then
      break
    end


    startRange = startRange+1000
    endRange = endRange+1000
    filteredPosts = {}

    if filter == 'seen' then
      for k,v in pairs(allPostIDs) do
        tinsert(freshPosts,v)
      end
    else

      for k, v in pairs(allPostIDs) do
        filterID,postID = v:match('(%w+):(%w+)')
        if userFilterIDs[filterID] then
          tinsert(filteredPosts,postID)
        end
      end

      -- check the user hasnt seen the posts
      local newUnseen
      if userID == 'default' then
        newUnseen = filteredPosts
      else
        newUnseen = userRead:GetUnseenPosts(userID,filteredPosts)
      end

      for k,v in pairs(newUnseen) do
        tinsert(freshPosts,v)
      end

    end
  end

  return freshPosts
end

function cache:GetUserFrontPage(userID,filter,range)
  range = range or 0

  --also need to check the posts nodeID

  local sessionSeenPosts = cache:GetUserSessionSeenPosts(userID)

  -- this will be cached for say 5 minutes
  local freshPosts = cache:GetFreshUserPosts(userID,filter)
  --ngx.log(ngx.ERR, 'freshposts: ',#freshPosts)

  local newPostIDs = {}

  if filter ~= 'seen' and userID ~= 'default' then
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
  else
    for i = range, range+10 do
      if freshPosts[i] then
        tinsert(newPostIDs,freshPosts[i])
      end
    end
  end



  local postsWithInfo = {}

  for k,postID in pairs(newPostIDs) do
    tinsert(postsWithInfo, self:GetPost(postID))
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
