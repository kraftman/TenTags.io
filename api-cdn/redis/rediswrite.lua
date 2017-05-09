


local tinsert = table.insert
local SCORE_FACTOR = 43200


local base = require 'redis.base'
local write = setmetatable({}, base)


function write:ConvertListToTable(list)
  local info = {}
  for i = 1,#list, 2 do
    info[list[i]] = list[i+1]
  end
  return info
end

function write:AddUniquePostView(postID, userID)
  local red = self:GetRedisWriteConnection()

  local ok, err = red:pfadd('post:uniquview:'..postID, userID)
  self:SetKeepalive(red)
  return ok, err

end

function write:IncrementSiteStat(stat, value)
  local red = self:GetRedisWriteConnection()
  local ok, err = red:hincrby('sitestats', stat, value)
  self:SetKeepalive(red)
  return ok, err
end


function write:LogFilterView(filterID, statTime, userID)

  -- need total views per minute, hour, day, month
  -- and unique pper minute, hour, day, month
  local red = self:GetRedisWriteConnection()

  local times = {}
  times.minutes = '60'
  times.hours = '3600'
  times.days = '86400'
  times.months = '2592000'
  local newTime

  local baseKey = 'filterStats:'..filterID
  local newKey
  red:init_pipeline()
  for k,label in pairs(times) do
    newTime = statTime - (statTime % label)
    newKey = baseKey..':'..k..':'..newTime

    red:zadd(baseKey, newTime, newKey)

    -- store total views per timespan
    red:hincrby(newKey, newTime, 1)
    -- store unique views
    red:pfadd(newKey..':unique', userID)

  end
  local ok, err = red:commit_pipeline()
  self:SetKeepalive(red)

  return ok, err
end

function write:LogUniqueSiteView(baseKey, statTime, userID, value)
  local red = self:GetRedisWriteConnection()
  local times = {}
  times.minutes = '60'
  times.hours = '3600'
  times.days = '86400'
  times.months = '2592000'

  local zkey, statKey, newTime, ok, err
  -- needs wrapping in pipeline
  red:init_pipeline()
  for k,label in pairs(times) do
    zkey = baseKey..':'..k

    newTime = statTime - (statTime % label)
    statKey = baseKey..':'..statTime..':'..value

    -- maintain a list of logs
    red:zadd(zkey, newTime, statKey)

    -- add unique view
    red:pfadd(statKey, userID)

  end
  ok, err = red:commit_pipeline()
  self:SetKeepalive(red)

  return ok, err
end

function write:DeleteResetKey(emailAddr)
  local red = self:GetRedisWriteConnection()

  local ok, err = red:del('emailReset:'..emailAddr)
  self:SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to remove password reset: ',err)
  end

  return ok, err
end

function write:AddPasswordReset(emailAddr, uuid)
  local red = self:GetRedisWriteConnection()
  local PASSWORD_RESET_TIME = 3600

  local ok, err = red:setex('emailReset:'..emailAddr, PASSWORD_RESET_TIME, uuid)
  self:SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to set password reset: ',err)
  end

  return ok, err
end

function write:InvalidateKey(keyType, id)
  local timeInvalidated = ngx.now()
  local red = self:GetRedisWriteConnection()
  local data = self:to_json({keyType = keyType, id = id})
  local ok, err = red:zadd('invalidationRequests', timeInvalidated, data)
  self:SetKeepalive(red)
  return ok, err
end

function write:LoadScript(script)
  local red = self:GetRedisWriteConnection()
  local ok, err = red:script('load',script)
  if not ok then
    ngx.log(ngx.ERR, 'unable to add script to redis:',err)
    return nil
  else
    ngx.log(ngx.ERR, 'added script to redis: ',ok)
  end

  return ok
end

function write:AddKey(addSHA,baseKey,newElement)
  local red = self:GetRedisWriteConnection()
  local ok, err = red:evalsha(addSHA,0,baseKey,10000,0.01,newElement)
  if not ok then
    ngx.log(ngx.ERR, 'unable to add key: ',err)
  end
  return ok, err
end

--[[
function write:CreateComment(postID,commentID, comment)
  local red = self:GetRedisWriteConnection()
  local ok , err = red:hmset(postID,commentID,comment)
  self:SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to write comment',err)
  end
end

function write:GetComments(postID)
  local red = self:GetRedisWriteConnection()
  local ok, err = red:hgetall(postID)
  if not ok then
    ngx.log(ngx.ERR, 'unable to get comments:',err)
  end
  self:SetKeepalive(red)
  return self:ConvertListToTable(ok)
end
--]]


function write:ConvertListToTable(list)
  local info = {}
  for i = 1,#list, 2 do
    info[list[i]] = list[i+1]
  end
  return info
end

function write:FilterBanUser(filterID, banInfo)
  local red = self:GetRedisWriteConnection()
  local ok, err = red:hset('filter:'..filterID, 'bannedUser:'..banInfo.userID, self:to_json(banInfo))
  self:SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to add banned user: ',err)
    return nil, err
  end
  return ok
end

function write:FilterBanDomain(filterID, banInfo)
  local red = self:GetRedisWriteConnection()
  local ok, err = red:hset('filter:'..filterID, 'bannedDomain:'..banInfo.domainName, self:to_json(banInfo))
  self:SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to add banned domain: ',err)
    return nil, err
  end
  return ok
end

function write:UpdatePostField(postID, field, newValue)
  local red = self:GetRedisWriteConnection()
  local ok, err = red:hset('post:'..postID,field,newValue)
  self:SetKeepalive(red)

  return ok,err
end

function write:IncrementPostStat(postID, field, value)
  local red = self:GetRedisWriteConnection()
  local ok, err = red:hincrby('post:'..postID, field, value)
  self:SetKeepalive(red)
  return ok, err
end

function write:FilterUnbanDomain(filterID, domainName)
  local red = self:GetRedisWriteConnection()
  local ok, err = red:hdel('filter:'..filterID, 'bannedDomain:'..domainName)
  self:SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to unban domain: ',err)
  end
  return ok, err
end

function write:FilterUnbanUser(filterID, userID)
  local red = self:GetRedisWriteConnection()
  local ok, err = red:hdel('filter:'..filterID, 'bannedUser:'..userID)
  self:SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to unban user: ',err)
  end
  return ok, err
end

function write:AddtagNamesToFilter(red, filterID, requiredTagNames, bannedTagNames)

    -- add list of required tags
    for _, tagName in pairs(requiredTagNames) do
      red:sadd('filter:requiredTagNames:'..filterID,tagName)
      red:hset('tag:filters:'..tagName, filterID, 'required')
    end

    -- add list of banned tags
    for _, tagName in pairs(bannedTagNames) do
      red:sadd('filter:bannedTagNames:'..filterID, tagName)
      red:hset('tag:filters:'..tagName, filterID, 'banned')
    end

end

function write:UpdateFilterTags(filter,requiredTagNames, bannedTagNames)
  local red = self:GetRedisWriteConnection()

  red:init_pipeline()
    -- remove all existing tags from the filter
    red:del('filter:requiredTagNames:'..filter.id)
    red:del('filter:bannedTagNames:'..filter.id)
    -- remove the filter from all tags

    for _,tagName in pairs(filter.requiredTagNames) do
      if type(tagName) == 'table' then tagName = tagName.name end
      red:hdel('tag:filters:'..tagName, filter.id)
    end
    for _,tagName in pairs(filter.bannedTagNames) do
      if type(tagName) == 'table' then tagName = tagName.name end
      red:hdel('tag:filters:'..tagName, filter.id)
    end

    -- add the new tags
    self:AddtagNamesToFilter(red, filter.id, requiredTagNames, bannedTagNames)
  local res, err = red:commit_pipeline()
  self:SetKeepalive(red)
  if err then
    ngx.log(ngx.ERR, 'unable to update filter tags: ',err)
  end


  return res, err

end

function write:DeletePost(postID)
  local red = self:GetRedisWriteConnection()
  local ok, err = red:hset('post:'..postID, 'deleted', 'true')
  self:SetKeepalive(red)
  return ok, err
end

function write:DelMod(filterID, modID)
  local red = self:GetRedisWriteConnection()
  local ok, err = red:hdel('filter:'..filterID, 'mod:'..modID)
  self:SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to del mod: ',err)
  end
  return ok, err
end

function write:AddMod(filterID, mod)
  local red = self:GetRedisWriteConnection()
  local ok, err = red:hset('filter:'..filterID, 'mod:'..mod.id, self:to_json(mod))
  self:SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to add mod: ',err)
  end
  return ok, err
end

function write:UpdateRelatedFilters(filter, relatedFilters)
  local red = self:GetRedisWriteConnection()
  red:init_pipeline()
  for _,v in pairs(filter.relatedFilterIDs) do
    red:hdel('filter:'..filter.id, 'relatedFilter:'..v)
  end

  for _,v in pairs(relatedFilters) do
    red:hset('filter:'..filter.id,  'relatedFilter:'..v,v)
  end
  local ok,err = red:commit_pipeline()

  self:SetKeepalive(red)
  return ok,err

end

function write:CreateFilter(filter)

  local hashFilter = {}

  for k, v in pairs(filter) do
    if k == 'mods' then
      for _,mod in pairs(v) do
        hashFilter['mod:'..mod.id] = self:to_json(mod)
      end
    elseif k == 'bannedUsers' then
      for _,banInfo in pairs(v) do
        hashFilter['bannedUser'..banInfo.userID] = self:to_json(banInfo)
      end
    elseif k == 'bannedDomains' then
      for _,banInfo in pairs(v) do
        hashFilter['bannedDomains:'..banInfo.domainName] = self:to_json(banInfo)
      end
    elseif type(v) == 'string' then
      hashFilter[k] = v
    end
  end


  -- add id to name conversion table
  local red = self:GetRedisWriteConnection()
  red:init_pipeline()
    red:set('filterid:'..hashFilter.name,hashFilter.id)


    -- add to list ranked by subs
    red:zadd('filtersubs',hashFilter.subs, hashFilter.id)

    -- add to list of filters
    red:zadd('filters',hashFilter.createdAt,hashFilter.id)
    red:sadd('filterNames',hashFilter.name)

    -- add all filter info
    red:hmset('filter:'..hashFilter.id, hashFilter)

    self:AddtagNamesToFilter(red, filter.id, filter.requiredTagNames, filter.bannedTagNames)

  local results, err = red:commit_pipeline()
  if err then
    ngx.log(ngx.ERR, 'unable to add filter to redis: ',err)
  end
  self:SetKeepalive(red)
  return results
end

function write:CreateFilterPostInfo(red, filter,postInfo)
  --print('updating filter '..filter.title..'with new score: '..filter.score)
  --print(filter.id, postInfo.id)
  red:sadd('filterposts:'..filter.id, postInfo.id)
  red:zadd('filterposts:date:'..filter.id,postInfo.createdAt,postInfo.id)
  red:zadd('filterposts:score:'..filter.id,filter.score,postInfo.id)
  red:zadd('filterposts:datescore:'..filter.id,postInfo.createdAt + filter.score*SCORE_FACTOR,postInfo.id)
  red:zadd('filterpostsall:datescore',postInfo.createdAt + filter.score*SCORE_FACTOR,filter.id..':'..postInfo.id)
  red:zadd('filterpostsall:date',postInfo.createdAt,filter.id..':'..postInfo.id)
  red:zadd('filterpostsall:score',filter.score,filter.id..':'..postInfo.id)
end

function write:IncrementFilterSubs(filterID, value)
  local red = self:GetRedisWriteConnection()
  local ok, err = red:hincrby('filter:'..filterID, 'subs', value)
  if not ok then
    self:SetKeepalive(red)
    print('error updating subcount ', err)
    return ok, err
  end
  print('adding ',ok,' to filtersubs')
  ok,err = red:zadd('filtersubs',ok, filterID)
  self:SetKeepalive(red)
  if not ok then
    print('moop : ',err)
  end
  return ok,err
end

function write:RemoveInvalidations(cutOff)
  local red = self:GetRedisWriteConnection()
  local ok, err = red:zremrangebyscore('invalidationRequests', 0, cutOff)
  self:SetKeepalive(red)
  return ok, err
end


function write:QueueJob(jobName, jobData)
  jobName = 'queue:'..jobName
  local red = self:GetRedisWriteConnection()
  jobData = self:to_json(jobData)
  -- this will remove duplicates by default since its not using NX
  local ok, err = red:zadd(jobName, ngx.time(), jobData)

  self:SetKeepalive(red)

  return ok, err
end

function write:RemoveJob(jobName, jobData)
jobName = 'queue:'..jobName
  local red = self:GetRedisWriteConnection()
  local ok, err = red:zrem(jobName, jobData)
  self:SetKeepalive(red)
  return ok, err
end

function write:AddPostToFilters(post, filters)
  -- add post to the filters that want it
  -- by post score, and by date
  local red = self:GetRedisWriteConnection()
    red:init_pipeline()
    for _, filterInfo in pairs(filters) do
        --print(self:to_json(filterInfo))
        --print(self:to_json(post))
      self:CreateFilterPostInfo(red,filterInfo,post)
    end
  local results, err = red:commit_pipeline()
  self:SetKeepalive(red)

  if err then
    ngx.log(ngx.ERR, 'unable to add posts to filters: ',err)
  end

  if not results and not err then
    return true
  else
    return results, err
  end

end

function write:RemoveFilterPostInfo(red, filterID,postID)
  red:srem('filterposts:'..filterID, postID)
  red:zrem('filterposts:date:'..filterID, postID)
  red:zrem('filterposts:score:'..filterID, postID)
  red:zrem('filterposts:datescore:'..filterID, postID)
  red:zrem('filterpostsall:datescore', filterID..':'..postID)
  red:zrem('filterpostsall:date', filterID..':'..postID)
  red:zrem('filterpostsall:score', filterID..':'..postID)
end

function write:RemovePostFromFilters(postID, filterIDs)
  local red = self:GetRedisWriteConnection()
  red:init_pipeline()
    for _,filterID in pairs(filterIDs) do
      self:RemoveFilterPostInfo(red, filterID, postID)
    end
  local results, err = red:commit_pipeline()
  self:SetKeepalive(red)
  if err then
    ngx.log(ngx.ERR, 'error removing post from filters: ',err)
  end
  return results
end

function write:SetNX(key,value)
  local red = self:GetRedisWriteConnection()
  local ok, err = red:set(key,value,'NX')
  self:SetKeepalive(red)
  if err then
    ngx.log(ngx.ERR, 'unable to setNX: ',err)
  end
  return ok, err
end


function write:SetShortURL(shortURL, id)
  local shortURL = 'su:'..shortURL
  local key, field = self:SplitShortURL(shortURL)
  local red = self:GetRedisWriteConnection()
  local ok, err = red:hset(key, field, id)
  self:SetKeepalive(red)
  return ok, err
end

function write:DeleteJob(queueName, jobKey)
  local realQName = 'queue:'..queueName
  local red = self:GetRedisWriteConnection()
  local ok, err = red:zrem(realQName, jobKey)
  self:SetKeepalive(red)
  return ok, err

end

function write:GetLock(key, expires)
  local red = self:GetRedisWriteConnection()
  local ok, err = red:set(key, key,'NX', 'EX',expires)
  self:SetKeepalive(red)
  if err then
    ngx.log(ngx.ERR, 'unable to setex: ',err)
  end
  return ok, err
end

function write:RemLock(key)
  local red = self:GetRedisWriteConnection()
  local ok, err = red:del(key)
  self:SetKeepalive(red)
  return ok, err
end

function write:DeleteKey(key)
  local red = self:GetRedisWriteConnection()

  local ok, err = red:del(key)

  self:SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'failed to delete keys: ', err)
  end
  return ok, err

end

function write:LogChange()
  return true
end

function write:RemovePostsFromFilter(filterID, postIDs)
  local red = self:GetRedisWriteConnection()
  red:init_pipeline()
    for _,postID in pairs(postIDs) do
      self:RemoveFilterPostInfo(red, filterID, postID)
    end
  local results, err = red:commit_pipeline()
  self:SetKeepalive(red)
  if err then
    ngx.log(ngx.ERR, 'error removing post from filters: ',err)
  end
  return results
end

function write:AddPostsToFilter(filterInfo,posts)

  local red = self:GetRedisWriteConnection()
    red:init_pipeline()
    for _, postInfo in pairs(posts) do
      if postInfo.score then
        filterInfo.score = postInfo.score
      end
      self:CreateFilterPostInfo(red,filterInfo,postInfo)
    end
  local results, err = red:commit_pipeline()
  self:SetKeepalive(red)

  if err then
    ngx.log(ngx.ERR, 'unable to add posts to filters: ',err)
  end
  --print('pipeline: ',err, err)
  return results
end

function write:UpdatePostParentID(post)
  local red = self:GetRedisWriteConnection()
  local ok, err = red:hset('post:'..post.id,'parentID',post.parentID)
  self:SetKeepalive(red)
  return ok, err
end


function write:CreateTempFilterPosts(tempKey, requiredTagNames, bannedTagNames)
  -- hacky duplicate of FindPostsForFilter, my bannedTagNames
  -- TODO: merge back together later

  --[[
    so we get list of every post that matches all the tags we want
    then we remove every post that has a tag we dont want,
    then store this list temporarily

  ]]

  local red = self:GetRedisWriteConnection()
  local labelledrequiredTagNames = {}
  local labelledbannedTagNames = {}
  print(self:to_json(requiredTagNames))
  for _,tagName in pairs(requiredTagNames) do
    if type(tagName) == 'table'then
      tagName = tagName.name
    end
    tinsert(labelledrequiredTagNames,'tagPosts:'..tagName)
  end

  for _,tagName in pairs(bannedTagNames) do
    if type(tagName) == 'table'then
      tagName = tagName.name
    end
    tinsert(labelledbannedTagNames,'tagPosts:'..tagName)
  end

  local tempRequiredPostsKey = tempKey..':required'
  --print(tempRequiredPostsKey)
  print(self:to_json(tempRequiredPostsKey))
  print(self:to_json(labelledrequiredTagNames))
  local ok, err = red:sinterstore(tempRequiredPostsKey, unpack(labelledrequiredTagNames))
  if not ok then
    ngx.log(ngx.ERR, 'unable to sinterstore tags: ',err)
    red:del(tempRequiredPostsKey)
    self:SetKeepalive(red)
    return nil, err
  end
  ok, err = red:sdiffstore(tempKey, tempRequiredPostsKey, unpack(labelledbannedTagNames))
  if not ok then
    ngx.log(ngx.ERR, 'unable to diff tags: ',err)
    self:SetKeepalive(red)
    return nil, err
  end

  ok, err = red:del(tempRequiredPostsKey)
  if not ok then
    ngx.log(ngx.ERR, 'unable to del temp posts set "',tempRequiredPostsKey,'": ',err)
  end
  self:SetKeepalive(red)
  return ok

end


function write:GetSetDiff(key1, key2)
  local red = self:GetRedisWriteConnection()
  local res, err = red:sdiff(key1, key2)
  self:SetKeepalive(red)
  if not res then
    ngx.log(ngx.ERR, 'unable to get set diff: ',err)
    return {}
  end
  return res
end


function write:FindPostsForFilter(filterID, requiredTagNames, bannedTagNames)
  -- in the future it may be too big to load in one go, and
  -- we may want to store the diff and iterate through it in chunks

  --for each tag, get the list of posts
  -- sinter all the posts that hared the required tags
  -- remove any posts that are under our banned tags
  local red = self:GetRedisWriteConnection()
  local matchingPostIDs
  local labelledrequiredTagNames = {}
  local labelledbannedTagNames = {}
  for _,v in pairs(requiredTagNames) do
    tinsert(labelledrequiredTagNames,'tagPosts:'..v.name)
  end
  for _,v in pairs(bannedTagNames) do
    tinsert(bannedTagNames,'tagPosts:'..v.name)
  end

  local tempKey = filterID..':tempPosts'

  local ok, err = red:sinterstore(tempKey, unpack(labelledrequiredTagNames))
  if not ok then
    ngx.log(ngx.ERR, 'unable to sinterstore tags: ',err)
    red:del(tempKey)
    self:SetKeepalive(red)
    return nil
  end
  matchingPostIDs, err = red:sdiff(tempKey, unpack(labelledbannedTagNames))
  if not matchingPostIDs then
    ngx.log(ngx.ERR, 'unable to diff tags: ',err)
    self:SetKeepalive(red)
    return nil
  end

  ok, err = red:del(tempKey)
  if not ok then
    ngx.log(ngx.ERR, 'unable to del temp posts set "',tempKey,'": ',err)
  end
  self:SetKeepalive(red)

  if matchingPostIDs == ngx.null then
    return {}
  else
    return matchingPostIDs
  end

end





function write:CreateTag(tagInfo)
  local red = self:GetRedisWriteConnection()
  local ok, err = red:hgetall('tag:'..tagInfo.name)

  if not ok then
    ngx.log(ngx.ERR, 'unable to get tag: ',err)
  end

  if ok ~= ngx.null and next(ok) then
    return self:ConvertListToTable(ok)
  end

  ok, err = red:hmset('tag:'..tagInfo.name,tagInfo)
  if not ok then
    ngx.log(ngx.ERR, 'unable to add tag: ',err)
  end

  ok, err = red:sadd('tags',tagInfo.name)
  if not ok then
    ngx.log(ngx.ERR, 'unable to add tag: ',err)
  end

  self:SetKeepalive(red)
  return true
end

function write:UpdatePostTags(post)
  local red = self:GetRedisWriteConnection()
  red:init_pipeline()
  for _,tag in pairs(post.tags) do
    red:sadd('post:tagNames:'..post.id, tag.name)
    red:hmset('posttags:'..post.id..':'..tag.name,tag)
  end
  local res, err = red:commit_pipeline()
  self:SetKeepalive(red)

  if err then
    ngx.log(ngx.ERR, 'unable to update post tags: ',err)
  end
  return res
end

function write:UpdateFilterDescription(filter)
  local red = self:GetRedisWriteConnection()
  print('filter:'..filter.id)
  local ok, err = red:hset('filter:'..filter.id, 'description', filter.description)
  self:SetKeepalive(red)
  if err then
    ngx.log(ngx.ERR, 'unable to update description: ', err)
  end
  if ok == ngx.null then
    return nil
  else
    return ok
  end
end

function write:UpdateFilterTitle(filter)
  local red = self:GetRedisWriteConnection()

  local ok, err = red:hset('filter:'..filter.id, 'title', filter.title)
  self:SetKeepalive(red)
  if err then
    ngx.log(ngx.ERR, 'unable to update description: ', err)
  end
  if ok == ngx.null then
    return nil
  else
    return ok
  end
end


function write:LogBacklogStats(jobName, time, value, duration)
  jobName = 'backlog:'..jobName

  local red = self:GetRedisReadConnection()
  local ok, err = red:zrangebyscore(jobName, time, time)
  if not ok then
    self:SetKeepalive(red)
    return nil, err
  end
  if (ok ~= ngx.null) and (next(ok) ~= nil) then
    self:SetKeepalive(red)
    return true,' already exists'
  end

  ok, err = red:zadd(jobName, time, value)
  if not ok then
    self:SetKeepalive(red)
    return ok, err
  end
  ok, err = red:zremrangebyrank(jobName, 0, -20000)
  return ok, err

end

function write:CreatePost(post)

  local hashedPost = {}
  hashedPost.viewers = {}
  hashedPost.filters = {}

  for k,v in pairs(post) do
    if k == 'viewers' then
      for _,viewerID in pairs(v) do
        hashedPost['viewer:'..viewerID] = 'true'
      end
    elseif k == 'filters' then
      for _,filterID in pairs(v) do
        hashedPost['filter:'..filterID] = 'true'
      end
    elseif k == 'tags' then
      --leave tags seperate for now as we do more with them

    elseif k == 'edits' then
      for time,edit in pairs(v) do
        hashedPost['edit:'..time] = self:to_json(edit)
      end
    else
      hashedPost[k] = v
    end
   end

  local red = self:GetRedisWriteConnection()

  red:init_pipeline()

    red:del('post:'..hashedPost.id)

    -- collect tag ids and add taginfo to hash
    for _,tag in pairs(post.tags) do
      red:sadd('tagPosts:'..tag.name, hashedPost.id)
      red:sadd('post:tagNames:'..hashedPost.id,tag.name)
      red:hmset('posttags:'..hashedPost.id..':'..tag.name,tag)
    end

    -- add to /f/all

    red:zadd('allposts:date',hashedPost.createdAt,hashedPost.id)

    -- add post inf
    red:hmset('post:'..hashedPost.id,hashedPost)
  local results,err = red:commit_pipeline()
  if err then
    self:SetKeepalive(red)
    ngx.log(ngx.ERR, 'unable to create post:',err)
  end

  self:SetKeepalive(red)
  return results, err
end


function write:CreateThread(thread)

  local hashedThread = {}
  hashedThread.viewers = {}
  for k,v in pairs(thread) do
    if k == 'viewers' then
      for _,userID in pairs(v) do
        hashedThread['viewer:'..userID] = 1
      end
    else
      hashedThread[k] = v
    end
  end

  local red = self:GetRedisWriteConnection()

  red:init_pipeline()
    red:hmset('Thread:'..hashedThread.id,hashedThread)
    for _,userID in pairs(thread.viewers) do
      red:zadd('UserThreads:'..userID,thread.lastUpdated,thread.id)
    end
  local res, err = red:commit_pipeline()
  self:SetKeepalive(red)
  if err then
    ngx.log('unable to write thread:',err)
  end
  return res
end

function write:CreateMessage(msg)
  -- also need to update theead last userUpdate
  local red = self:GetRedisWriteConnection()
  red:init_pipeline()

    red:hset('ThreadMessages:'..msg.threadID,msg.id,self:to_json(msg))
    red:hset('Thread:'..msg.threadID,'lastUpdated',msg.createdAt)

  local res, err = red:commit_pipeline()
  self:SetKeepalive(red)
  if err then
    ngx.log(ngx.ERR, 'unable to create message: ',err)
  end
  return res
end


return write
