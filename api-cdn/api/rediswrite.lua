

local write = {}

local to_json = (require 'lapis.util').to_json
local tinsert = table.insert
local SCORE_FACTOR = 43200
local util = require 'util'


function write:ConvertListToTable(list)
  local info = {}
  for i = 1,#list, 2 do
    info[list[i]] = list[i+1]
  end
  return info
end

function write:DeleteResetKey(emailAddr)
  local red = util:GetRedisWriteConnection()

  local ok, err = red:del('emailReset:'..emailAddr)
  if not ok then
    ngx.log(ngx.ERR, 'unable to remove password reset: ',err)
  end

  return ok, err
end

function write:AddPasswordReset(emailAddr, uuid)
  local red = util:GetRedisWriteConnection()
  local PASSWORD_RESET_TIME = 3600

  local ok, err = red:setex('emailReset:'..emailAddr, PASSWORD_RESET_TIME, uuid)
  if not ok then
    ngx.log(ngx.ERR, 'unable to set password reset: ',err)
  end

  return ok, err
end

function write:InvalidateKey(keyType, id)
  local timeInvalidated = ngx.now()
  local red = util:GetRedisWriteConnection()
  local data = to_json({keyType = keyType, id = id})
  local ok, err = red:zadd('invalidationRequests', timeInvalidated, data)
  return ok, err
end

function write:LoadScript(script)
  local red = util:GetRedisWriteConnection()
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
  local red = util:GetRedisWriteConnection()
  local ok, err = red:evalsha(addSHA,0,baseKey,10000,0.01,newElement)
  if not ok then
    ngx.log(ngx.ERR, 'unable to add key: ',err)
  end
  return ok
end


function write:CreateComment(postID,commentID, comment)
  local red = util:GetRedisWriteConnection()
  local ok , err = red:hmset(postID,commentID,comment)
  util:SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to write comment',err)
  end
end

function write:GetComments(postID)
  local red = util:GetRedisWriteConnection()
  local ok, err = red:hgetall(postID)
  if not ok then
    ngx.log(ngx.ERR, 'unable to get comments:',err)
  end
  util:SetKeepalive(red)
  return self:ConvertListToTable(ok)
end


function write:ConvertListToTable(list)
  local info = {}
  for i = 1,#list, 2 do
    info[list[i]] = list[i+1]
  end
  return info
end

function write:FilterBanUser(filterID, banInfo)
  local red = util:GetRedisWriteConnection()
  local ok, err = red:hset('filter:'..filterID, 'bannedUser:'..banInfo.userID, to_json(banInfo))
  if not ok then
    ngx.log(ngx.ERR, 'unable to add banned user: ',err)
    return nil, err
  end
  util:SetKeepalive(red)
  return ok
end

function write:FilterBanDomain(filterID, banInfo)
  local red = util:GetRedisWriteConnection()
  local ok, err = red:hset('filter:'..filterID, 'bannedDomain:'..banInfo.domainName, to_json(banInfo))
  if not ok then
    ngx.log(ngx.ERR, 'unable to add banned domain: ',err)
    return nil, err
  end
  util:SetKeepalive(red)
  return ok
end

function write:UpdatePostField(postID, field, newValue)
  local red = util:GetRedisWriteConnection()
  local ok, err = red:hset('post:'..postID,field,newValue)
  util:SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to update post field: ', err)
  end
  return ok,err
end

function write:FilterUnbanDomain(filterID, domainName)
  local red = util:GetRedisWriteConnection()
  local ok, err = red:hdel('filter:'..filterID, 'bannedDomain:'..domainName)
  if not ok then
    ngx.log(ngx.ERR, 'unable to unban domain: ',err)
  end
  util:SetKeepalive(red)
  return ok, err
end

function write:FilterUnbanUser(filterID, userID)
  local red = util:GetRedisWriteConnection()
  local ok, err = red:hdel('filter:'..filterID, 'bannedUser:'..userID)
  if not ok then
    ngx.log(ngx.ERR, 'unable to unban user: ',err)
  end
  util:SetKeepalive(red)
  return ok, err
end

function write:AddTagIDsToFilter(red, filterID, requiredTagIDs, bannedTagIDs)

    -- add list of required tags
    for _, tagID in pairs(requiredTagIDs) do
      red:sadd('filter:requiredTagIDs:'..filterID,tagID)
      red:hset('tag:filters:'..tagID, filterID, 'required')
    end

    -- add list of banned tags
    for _, tagID in pairs(bannedTagIDs) do
      red:sadd('filter:bannedTagIDs:'..filterID, tagID)
      red:hset('tag:filters:'..tagID, filterID, 'banned')
    end

end

function write:UpdateFilterTags(filter,requiredTagIDs, bannedTagIDs)
  local red = util:GetRedisWriteConnection()

  red:init_pipeline()
    -- remove all existing tags from the filter
    red:del('filter:requiredTagIDs:'..filter.id)
    red:del('filter:bannedTagIDs:'..filter.id)
    -- remove the filter from all tags

    for _,tagID in pairs(filter.requiredTagIDs) do
      if type(tagID) == 'table' then tagID = tagID.id end
      red:hdel('tag:filters:'..tagID, filter.id)
    end
    for _,tagID in pairs(filter.bannedTagIDs) do
      if type(tagID) == 'table' then tagID = tagID.id end
      red:hdel('tag:filters:'..tagID, filter.id)
    end

    -- add the new tags
    self:AddTagIDsToFilter(red, filter.id, requiredTagIDs, bannedTagIDs)
  local res, err = red:commit_pipeline()
  util:SetKeepalive(red)
  if err then
    ngx.log(ngx.ERR, 'unable to update filter tags: ',err)
  end


  return res, err

end

function write:DeletePost(postID)
  local red = util:GetRedisWriteConnection()
  local ok, err = red:hset('post:'..postID, 'deleted', 'true')
  return ok, err
end

function write:DelMod(filterID, modID)
  local red = util:GetRedisWriteConnection()
  local ok, err = red:hdel('filter:'..filterID, 'mod:'..modID)
  util:SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to del mod: ',err)
  end
  return ok, err
end

function write:AddMod(filterID, mod)
  local red = util:GetRedisWriteConnection()
  local ok, err = red:hset('filter:'..filterID, 'mod:'..mod.id, to_json(mod))
  util:SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to add mod: ',err)
  end
  return ok, err
end

function write:UpdateRelatedFilters(filter, relatedFilters)
  local red = util:GetRedisWriteConnection()

  for _,v in pairs(filter.relatedFilterIDs) do
    red:hdel('filter:'..filter.id, 'relatedFilter:'..v)
  end

  for _,v in pairs(relatedFilters) do
    red:hset('filter:'..filter.id,  'relatedFilter:'..v,v)
  end

end

function write:CreateFilter(filter)

  local hashFilter = {}

  for k, v in pairs(filter) do
    if k == 'mods' then
      for _,mod in pairs(v) do
        hashFilter['mod:'..mod.id] = to_json(mod)
      end
    elseif k == 'bannedUsers' then
      for _,banInfo in pairs(v) do
        hashFilter['bannedUser'..banInfo.userID] = to_json(banInfo)
      end
    elseif k == 'bannedDomains' then
      for _,banInfo in pairs(v) do
        hashFilter['bannedDomains:'..banInfo.domainName] = to_json(banInfo)
      end
    elseif type(v) == 'string' then
      hashFilter[k] = v
    end
  end


  -- add id to name conversion table
  local red = util:GetRedisWriteConnection()
  red:init_pipeline()
  red:set('filterid:'..hashFilter.name,hashFilter.id)


  -- add to list ranked by subs
  red:zadd('filtersubs',hashFilter.subs, hashFilter.id)

  -- add to list of filters
  red:zadd('filters',hashFilter.createdAt,hashFilter.id)

  -- add all filter info
  red:hmset('filter:'..hashFilter.id, hashFilter)

  self:AddTagIDsToFilter(red, filter.id, filter.requiredTagIDs, filter.bannedTagIDs)

  local results, err = red:commit_pipeline()
  if err then
    ngx.log(ngx.ERR, 'unable to add filter to redis: ',err)
  end
  return results
end

function write:CreateFilterPostInfo(red, filter,postInfo)
  --print('updating filter '..filter.title..'with new score: '..filter.score)
  print(filter.id, postInfo.id)
  red:sadd('filterposts:'..filter.id, postInfo.id)
  red:zadd('filterposts:date:'..filter.id,postInfo.createdAt,postInfo.id)
  red:zadd('filterposts:score:'..filter.id,filter.score,postInfo.id)
  red:zadd('filterposts:datescore:'..filter.id,postInfo.createdAt + filter.score*SCORE_FACTOR,postInfo.id)
  red:zadd('filterpostsall:datescore',postInfo.createdAt + filter.score*SCORE_FACTOR,filter.id..':'..postInfo.id)
  red:zadd('filterpostsall:date',postInfo.createdAt,filter.id..':'..postInfo.id)
  red:zadd('filterpostsall:score',filter.score,filter.id..':'..postInfo.id)
end

function write:RemoveInvalidations(cutOff)
  local red = util:GetRedisWriteConnection()
  local ok, err = red:zremrangebyscore('invalidationRequests', 0, cutOff)
  return ok, err
end

function write:QueueJob(queueName,value)
  local realQName = 'queue:'..queueName
  local red = util:GetRedisWriteConnection()
  --print(realQName, value)
  local ok, err = red:zadd(realQName,'NX', ngx.time(), value)
  util:SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to queue job: ',err)
  end
  return ok, err
end

function write:AddPostToFilters(post, filters)
  -- add post to the filters that want it
  -- by post score, and by date
  local red = util:GetRedisWriteConnection()
    red:init_pipeline()
    for _, filterInfo in pairs(filters) do
        print(to_json(filterInfo))
        print(to_json(post))
      self:CreateFilterPostInfo(red,filterInfo,post)
    end
  local results, err = red:commit_pipeline()

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
  local red = util:GetRedisWriteConnection()
  red:init_pipeline()
    for _,filterID in pairs(filterIDs) do
      self:RemoveFilterPostInfo(red, filterID, postID)
    end
  local results, err = red:commit_pipeline()
  util:SetKeepalive(red)
  if err then
    ngx.log(ngx.ERR, 'error removing post from filters: ',err)
  end
  return results
end

function write:SetNX(key,value)
  local red = util:GetRedisWriteConnection()
  local ok, err = red:set(key,value,'NX')
  if err then
    ngx.log(ngx.ERR, 'unable to setNX: ',err)
  end
  return ok, err
end

function write:DeleteJob(queueName, jobKey)
  local realQName = 'queue:'..queueName
  local red = util:GetRedisWriteConnection()
  local ok, err = red:zrem(realQName, jobKey)
  util:SetKeepalive(red)
  return ok, err

end

function write:GetLock(key, expires)
  local red = util:GetRedisWriteConnection()
  local ok, err = red:set(key, key,'NX', 'EX',expires)
  if err then
    ngx.log(ngx.ERR, 'unable to setex: ',err)
  end
  return ok, err
end

function write:DeleteKey(key)
  local red = util:GetRedisWriteConnection()

  local ok, err = red:del(key)

  util:SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'failed to delete keys: ', err)
  end
  return ok, err

end

function write:LogChange()
  return true
end

function write:RemovePostsFromFilter(filterID, postIDs)
  local red = util:GetRedisWriteConnection()
  red:init_pipeline()
    for _,postID in pairs(postIDs) do
      self:RemoveFilterPostInfo(red, filterID, postID)
    end
  local results, err = red:commit_pipeline()
  util:SetKeepalive(red)
  if err then
    ngx.log(ngx.ERR, 'error removing post from filters: ',err)
  end
  return results
end

function write:AddPostsToFilter(filterInfo,posts)

  local red = util:GetRedisWriteConnection()
    red:init_pipeline()
    for _, postInfo in pairs(posts) do
      if postInfo.score then
        filterInfo.score = postInfo.score
      end
      self:CreateFilterPostInfo(red,filterInfo,postInfo)
    end
  local results, err = red:commit_pipeline()

  if err then
    ngx.log(ngx.ERR, 'unable to add posts to filters: ',err)
  end
  --print('pipeline: ',err, err)
  return results
end

function write:UpdatePostParentID(post)
  local red = util:GetRedisWriteConnection()
  local ok, err = red:hset('post:'..post.id,'parentID',post.parentID)
  util:SetKeepalive(red)
  return ok, err
end


function write:CreateTempFilterPosts(tempKey, requiredTagIDs, bannedTagIDs)
  -- hacky duplicate of FindPostsForFilter, my bannedTagIDs
  -- TODO: merge back together later

  --[[
    so we get list of every post that matches all the tags we want
    then we remove every post that has a tag we dont want,
    then store this list temporarily

  ]]

  local red = util:GetRedisWriteConnection()
  local labelledRequiredTagIDs = {}
  local labelledBannedTagIDs = {}

  for _,tagID in pairs(requiredTagIDs) do
    if type(tagID) == 'table'then
      tagID = tagID.id
    end
    tinsert(labelledRequiredTagIDs,'tagPosts:'..tagID)
  end

  for _,tagID in pairs(bannedTagIDs) do
    if type(tagID) == 'table'then
      tagID = tagID.id
    end
    tinsert(labelledBannedTagIDs,'tagPosts:'..tagID)
  end

  local tempRequiredPostsKey = tempKey..':required'
  --print(tempRequiredPostsKey)

  local ok, err = red:sinterstore(tempRequiredPostsKey, unpack(labelledRequiredTagIDs))
  if not ok then
    ngx.log(ngx.ERR, 'unable to sinterstore tags: ',err)
    red:del(tempRequiredPostsKey)
    util:SetKeepalive(red)
    return nil, err
  end
  ok, err = red:sdiffstore(tempKey, tempRequiredPostsKey, unpack(labelledBannedTagIDs))
  if not ok then
    ngx.log(ngx.ERR, 'unable to diff tags: ',err)
    util:SetKeepalive(red)
    return nil, err
  end

  ok, err = red:del(tempRequiredPostsKey)
  if not ok then
    ngx.log(ngx.ERR, 'unable to del temp posts set "',tempRequiredPostsKey,'": ',err)
  end
  util:SetKeepalive(red)
  return ok

end

function write:GetSetDiff(key1, key2)
  local red = util:GetRedisWriteConnection()
  local res, err = red:sdiff(key1, key2)
  util:SetKeepalive(red)
  if not res then
    ngx.log(ngx.ERR, 'unable to get set diff: ',err)
    return {}
  end
  return res
end


function write:FindPostsForFilter(filterID, requiredTagIDs, bannedTagIDs)
  -- in the future it may be too big to load in one go, and
  -- we may want to store the diff and iterate through it in chunks
  local red = util:GetRedisWriteConnection()
  local matchingPostIDs
  local labelledRequiredTagIDs = {}
  local labelledBannedTagIDs = {}
  for _,v in pairs(requiredTagIDs) do
    tinsert(labelledRequiredTagIDs,'tagPosts:'..v.id)
  end
  for _,v in pairs(bannedTagIDs) do
    tinsert(bannedTagIDs,'tagPosts:'..v.id)
  end

  local tempKey = filterID..':tempPosts'

  local ok, err = red:sinterstore(tempKey, unpack(labelledRequiredTagIDs))
  if not ok then
    ngx.log(ngx.ERR, 'unable to sinterstore tags: ',err)
    red:del(tempKey)
    util:SetKeepalive(red)
    return nil
  end
  matchingPostIDs, err = red:sdiff(tempKey, unpack(labelledBannedTagIDs))
  if not matchingPostIDs then
    ngx.log(ngx.ERR, 'unable to diff tags: ',err)
    util:SetKeepalive(red)
    return nil
  end

  ok, err = red:del(tempKey)
  if not ok then
    ngx.log(ngx.ERR, 'unable to del temp posts set "',tempKey,'": ',err)
  end
  util:SetKeepalive(red)

  if matchingPostIDs == ngx.null then
    return {}
  else
    return matchingPostIDs
  end

end





function write:CreateTag(tagInfo)
  local red = util:GetRedisWriteConnection()
  local ok, err = red:hgetall('tag:'..tagInfo.name)

  if not ok then
    ngx.log(ngx.ERR, 'unable to get tag: ',err)
  end
  print('got tag: ', to_json(ok))

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

  util:SetKeepalive(red)
  return true
end

function write:UpdatePostTags(post)
  local red = util:GetRedisWriteConnection()
  red:init_pipeline()
  for _,tag in pairs(post.tags) do
    red:sadd('post:tagIDs:'..post.id, tag.id)
    red:hmset('posttags:'..post.id..':'..tag.id,tag)
  end
  local res, err = red:commit_pipeline()
  util:SetKeepalive(red)

  if err then
    ngx.log(ngx.ERR, 'unable to update post tags: ',err)
  end
  return res
end

function write:UpdateFilterDescription(filter)
  local red = util:GetRedisWriteConnection()
  print('filter:'..filter.id)
  local ok, err = red:hset('filter:'..filter.id, 'description', filter.description)
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
  local red = util:GetRedisWriteConnection()

  local ok, err = red:hset('filter:'..filter.id, 'title', filter.title)
  if err then
    ngx.log(ngx.ERR, 'unable to update description: ', err)
  end
  if ok == ngx.null then
    return nil
  else
    return ok
  end
end

function write:CreatePost(postInfo)
  local red = util:GetRedisWriteConnection()
  local tags = postInfo.tags
  postInfo.tags = nil

  for _,viewerID in pairs(postInfo.viewers) do
    postInfo['viewer:'..viewerID] = 'true'
  end
  postInfo.viewers = nil

  for _,filterID in pairs(postInfo.filters) do
    postInfo['filter:'..filterID] = 'true'
  end
  postInfo.filters = nil

  red:init_pipeline()

    red:del('post:'..postInfo.id)

    -- collect tag ids and add taginfo to hash
    for _,tag in pairs(tags) do
      red:sadd('tagPosts:'..tag.id, postInfo.id)
      red:sadd('post:tagIDs:'..postInfo.id,tag.id)
      red:hmset('posttags:'..postInfo.id..':'..tag.id,tag)
    end

    -- add to /f/all

    red:zadd('allposts:date',postInfo.createdAt,postInfo.id)

    -- add post inf
  red:hmset('post:'..postInfo.id,postInfo)
  local results,err = red:commit_pipeline()
  if err then
    ngx.log(ngx.ERR, 'unable to create post:',err)
  end

  util:SetKeepalive(red)
  return results, err
end


function write:CreateThread(thread)
  local red = util:GetRedisWriteConnection()
  local viewers = thread.viewers
  thread.viewers = nil

  -- there wont be many viewers ever so lets not waste a set
  for _,userID in pairs(viewers) do
    ngx.log(ngx.ERR, 'adding user: ',userID)
    thread['viewer:'..userID] = 1
  end

  red:init_pipeline()
    red:hmset('Thread:'..thread.id,thread)
    for _,userID in pairs(viewers) do
      red:zadd('UserThreads:'..userID,thread.lastUpdated,thread.id)
    end
  local res, err = red:commit_pipeline()
  if err then
    ngx.log('unable to write thread:',err)
  end
  return res
end

function write:CreateMessage(msg)
  -- also need to update theead last userUpdate
  local red = util:GetRedisWriteConnection()
  red:init_pipeline()

    red:hset('ThreadMessages:'..msg.threadID,msg.id,to_json(msg))
    red:hset('Thread:'..msg.threadID,'lastUpdated',msg.createdAt)

  local res, err = red:commit_pipeline()
  if err then
    ngx.log(ngx.ERR, 'unable to create message: ',err)
  end
  return res
end


return write
