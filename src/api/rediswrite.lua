

local write = {}

local redis = require 'resty.redis'
local to_json = (require 'lapis.util').to_json
local tinsert = table.insert
local SCORE_FACTOR = 43200


local function GetRedisConnection()
  local red = redis:new()
  red:set_timeout(1000)
  local ok, err = red:connect("127.0.0.1", 6379)
  if not ok then
      ngx.say("failed to connect: ", err)
      return
  end
  red:select(0)
  return red
end

local function SetKeepalive(red)
  local ok, err = red:set_keepalive(10000, 100)
  if not ok then
      ngx.say("failed to set keepalive: ", err)
      return
  end
end


function write:ConvertListToTable(list)
  local info = {}
  for i = 1,#list, 2 do
    info[list[i]] = list[i+1]
  end
  return info
end

function write:DeleteResetKey(emailAddr)
  local red = GetRedisConnection()

  local ok, err = red:del('emailReset:'..emailAddr)
  if not ok then
    ngx.log(ngx.ERR, 'unable to remove password reset: ',err)
  end

  return ok, err
end

function write:AddPasswordReset(emailAddr, uuid)
  local red = GetRedisConnection()
  local PASSWORD_RESET_TIME = 3600

  local ok, err = red:setex('emailReset:'..emailAddr, PASSWORD_RESET_TIME, uuid)
  if not ok then
    ngx.log(ngx.ERR, 'unable to set password reset: ',err)
  end

  return ok, err
end

function write:LoadScript(script)
  local red = GetRedisConnection()
  local ok, err = red:script('load',script)
  if not ok then
    ngx.log(ngx.ERR, 'unable to add script to redis:',err)
    return nil
  end

  return ok
end

function write:AddKey(addSHA,baseKey,newElement)
  local red = GetRedisConnection()
  local ok, err = red:evalsha(addSHA,0,baseKey,10000,0.01,newElement)
  if not ok then
    ngx.log(ngx.ERR, 'unable to add key: ',err)
  end
  return ok
end


function write:CreateComment(postID,commentID, comment)
  local red = GetRedisConnection()
  local ok , err = red:hmset(postID,commentID,comment)
  SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to write comment',err)
  end
end

function write:GetComments(postID)
  local red = GetRedisConnection()
  local ok, err = red:hgetall(postID)
  if not ok then
    ngx.log(ngx.ERR, 'unable to get comments:',err)
  end
  SetKeepalive(red)
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
  local red = GetRedisConnection()
  local ok, err = red:hset('filter:'..filterID, 'bannedUser:'..banInfo.userID, to_json(banInfo))
  if not ok then
    ngx.log(ngx.ERR, 'unable to add banned user: ',err)
    return nil, err
  end
  SetKeepalive(red)
  return ok
end

function write:FilterBanDomain(filterID, banInfo)
  local red = GetRedisConnection()
  local ok, err = red:hset('filter:'..filterID, 'bannedDomain:'..banInfo.domainName, to_json(banInfo))
  if not ok then
    ngx.log(ngx.ERR, 'unable to add banned domain: ',err)
    return nil, err
  end
  SetKeepalive(red)
  return ok
end

function write:UpdatePostField(postID, field, newValue)
  local red = GetRedisConnection()
  local ok, err = red:hset('post:'..postID,field,newValue)
  SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to update post field: ', err)
  end
  return ok,err
end

function write:FilterUnbanDomain(filterID, domainName)
  local red = GetRedisConnection()
  local ok, err = red:hdel('filter:'..filterID, 'bannedDomain:'..domainName)
  if not ok then
    ngx.log(ngx.ERR, 'unable to unban domain: ',err)
  end
  SetKeepalive(red)
  return ok, err
end

function write:FilterUnbanUser(filterID, userID)
  local red = GetRedisConnection()
  local ok, err = red:hdel('filter:'..filterID, 'bannedUser:'..userID)
  if not ok then
    ngx.log(ngx.ERR, 'unable to unban user: ',err)
  end
  SetKeepalive(red)
  return ok, err
end

function write:AddTagsToFilter(red, filterID, requiredTags, bannedTags)

    -- add list of required tags
    for _, tagID in pairs(requiredTags) do
      red:sadd('filter:requiredtags:'..filterID,tagID)
    end

    -- add list of banned tags
    for _, tagID in pairs(bannedTags) do
      red:sadd('filter:bannedtags:'..filterID, tagID)
    end

    -- add filter to required tag
    for _, tagID in pairs(requiredTags) do
      red:hset('tag:filters:'..tagID, filterID, 'required')
    end
    -- add filter to banned tag
    for _, tagID in pairs(bannedTags) do
      red:hset('tag:filters:'..tagID, filterID, 'banned')
    end
end

function write:UpdateFilterTags(filter, newRequiredTags, newBannedTags)
  local red = GetRedisConnection()

  red:init_pipeline()
    -- remove all existing tags from the filter
    red:del('filter:requiredtags:'..filter.id)
    red:del('filter:bannedtags:'..filter.id)
    -- remove the filter from all tags
    for _,tag in pairs(filter.requiredTags) do
      red:hdel('tag:filters:'..tag.id, filter.id)
    end
    for _,tag in pairs(filter.bannedTags) do
      red:hdel('tag:filters:'..tag.id, filter.id)
    end

    -- add the new tags
    self:AddTagsToFilter(red, filter.id, newRequiredTags, newBannedTags)
  local res, err = red:commit_pipeline()
  SetKeepalive(red)
  if err then
    ngx.log(ngx.ERR, 'unable to update filter tags: ',err)
  end

  return res, err

end

function write:DeletePost(postID)
  local red = GetRedisConnection()
  local ok, err = red:hset('post:'..postID, 'deleted', 'true')
  return ok, err
end

function write:DelMod(filterID, modID)
  local red = GetRedisConnection()
  local ok, err = red:hdel('filter:'..filterID, 'mod:'..modID)
  SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to del mod: ',err)
  end
  return ok, err
end

function write:AddMod(filterID, mod)
  local red = GetRedisConnection()
  local ok, err = red:hset('filter:'..filterID, 'mod:'..mod.id, to_json(mod))
  SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to add mod: ',err)
  end
  return ok, err
end

function write:CreateFilter(filterInfo)
  local tempRequiredTags, tempBannedTags = filterInfo.requiredTags, filterInfo.bannedTags
  local requiredTags = {}
  local bannedTags = {}

  for _,v in pairs( filterInfo.requiredTags) do
    tinsert(requiredTags, v.id)
  end
  for _,v in pairs( filterInfo.bannedTags) do
    tinsert(bannedTags, v.id)
  end

  for _,mod in pairs(filterInfo.mods) do
    filterInfo['mod:'..mod] = to_json(mod)
  end
  filterInfo.mods = nil

  filterInfo.bannedTags = nil
  filterInfo.requiredTags = nil

  if filterInfo.bannedUsers then
    for _, banInfo in pairs(filterInfo.bannedUsers) do
      tinsert(filterInfo, 'bannedUser:'..banInfo.userID,to_json(banInfo))
    end
    filterInfo.bannedUsers = nil
  end

  if filterInfo.bannedDomains then
    for _,banInfo in pairs(filterInfo.bannedDomains) do
      tinsert(filterInfo, 'bannedDomain:'..banInfo.domainName, to_json(banInfo))
    end
    filterInfo.bannedDomains = nil
  end


  -- add id to name conversion table
  local red = GetRedisConnection()
  red:init_pipeline()
  red:set('filterid:'..filterInfo.name,filterInfo.id)


  -- add to list ranked by subs
  red:zadd('filtersubs',filterInfo.subs, filterInfo.id)

  -- add to list of filters
  red:zadd('filters',filterInfo.createdAt,filterInfo.id)

  -- add all filter info
  red:hmset('filter:'..filterInfo.id, filterInfo)

  self:AddTagsToFilter(red, filterInfo.id, requiredTags, bannedTags)
  filterInfo.requiredTags = tempRequiredTags
  filterInfo.bannedTags = tempBannedTags
  local results, err = red:commit_pipeline()
  if err then
    ngx.log(ngx.ERR, 'unable to add filter to redis: ',err)
  end
  return results
end

function write:CreateFilterPostInfo(red, filter,postInfo)
  --print('updating filter '..filter.title..'with new score: '..filter.score)
  red:sadd('filterposts:'..filter.id, postInfo.id)
  red:zadd('filterposts:date:'..filter.id,postInfo.createdAt,postInfo.id)
  red:zadd('filterposts:score:'..filter.id,filter.score,postInfo.id)
  red:zadd('filterposts:datescore:'..filter.id,postInfo.createdAt + filter.score*SCORE_FACTOR,postInfo.id)
  red:zadd('filterpostsall:datescore',postInfo.createdAt + filter.score*SCORE_FACTOR,filter.id..':'..postInfo.id)
  red:zadd('filterpostsall:date',postInfo.createdAt,filter.id..':'..postInfo.id)
  red:zadd('filterpostsall:score',filter.score,filter.id..':'..postInfo.id)
end

function write:QueueJob(queueName,value)
  local red = GetRedisConnection()
  print(queueName, value)
  local ok, err = red:zadd(queueName,'NX', ngx.time(), value)
  SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to queue job: ',err)
  end
  return ok, err
end

function write:AddPostToFilters(post, filters)
  -- add post to the filters that want it
  -- by post score, and by date
  local red = GetRedisConnection()
    red:init_pipeline()
    for _, filterInfo in pairs(filters) do
      self:CreateFilterPostInfo(red,filterInfo,post)
    end
  local results, err = red:commit_pipeline()

  if err then
    ngx.log(ngx.ERR, 'unable to add posts to filters: ',err)
  end
  return results
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
  local red = GetRedisConnection()
  red:init_pipeline()
    for _,filterID in pairs(filterIDs) do
      self:RemoveFilterPostInfo(red, filterID, postID)
    end
  local results, err = red:commit_pipeline()
  SetKeepalive(red)
  if err then
    ngx.log(ngx.ERR, 'error removing post from filters: ',err)
  end
  return results
end

function write:SetNX(key,value)
  local red = GetRedisConnection()
  local ok, err = red:set(key,value,'NX')
  if err then
    ngx.log(ngx.ERR, 'unable to setNX: ',err)
  end
  return ok, err
end

function write:DeleteJob(queueName, jobKey)
  local red = GetRedisConnection()
  local ok, err = red:zrem(queueName, jobKey)
  SetKeepalive(red)
  return ok, err

end

function write:GetLock(key, expires)
  local red = GetRedisConnection()
  local ok, err = red:set(key, key,'NX', 'EX',expires)
  if err then
    ngx.log(ngx.ERR, 'unable to setex: ',err)
  end
  return ok, err
end

function write:DeleteKey(key)
  local red = GetRedisConnection()

  local ok, err = red:del(key)

  SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'failed to delete keys: ', err)
  end
  return ok, err

end

function write:RemovePostsFromFilter(filterID, postIDs)
  local red = GetRedisConnection()
  red:init_pipeline()
    for _,postID in pairs(postIDs) do
      self:RemoveFilterPostInfo(red, filterID, postID)
    end
  local results, err = red:commit_pipeline()
  SetKeepalive(red)
  if err then
    ngx.log(ngx.ERR, 'error removing post from filters: ',err)
  end
  return results
end

function write:AddPostsToFilter(filterInfo,posts)

  local red = GetRedisConnection()
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
  return results
end

function write:UpdatePostParentID(post)
  local red = GetRedisConnection()
  local ok, err = red:hset('post:'..post.id,'parentID',post.parentID)
  SetKeepalive(red)
  return ok, err
end


function write:CreateTempFilterPosts(tempKey, requiredTagIDs, bannedTagIDs)
  -- hacky duplicate of FindPostsForFilter, my bannedTagIDs
  -- TODO: merge back together later

  local red = GetRedisConnection()
  local requiredTags = {}
  local bannedTags = {}

  for _,tag in pairs(requiredTagIDs) do
    tinsert(requiredTags,'tagPosts:'..tag.id)
  end

  for _,tag in pairs(bannedTagIDs) do
    tinsert(bannedTags,'tagPosts:'..tag.id)
  end

  local tempRequiredPostsKey = tempKey..':required'
  print(tempRequiredPostsKey)

  local ok, err = red:sinterstore(tempRequiredPostsKey, unpack(requiredTags))
  if not ok then
    ngx.log(ngx.ERR, 'unable to sinterstore tags: ',err)
    red:del(tempRequiredPostsKey)
    SetKeepalive(red)
    return nil
  end
  ok, err = red:sdiffstore(tempKey, tempRequiredPostsKey, unpack(bannedTags))
  if not ok then
    ngx.log(ngx.ERR, 'unable to diff tags: ',err)
    SetKeepalive(red)
    return nil
  end

  ok, err = red:del(tempRequiredPostsKey)
  if not ok then
    ngx.log(ngx.ERR, 'unable to del temp posts set "',tempRequiredPostsKey,'": ',err)
  end
  SetKeepalive(red)
  return ok

end

function write:GetSetDiff(key1, key2)
  local red = GetRedisConnection()
  local res, err = red:sdiff(key1, key2)
  SetKeepalive(red)
  if not res then
    ngx.log(ngx.ERR, 'unable to get set diff: ',err)
    return {}
  end
  return res
end


function write:FindPostsForFilter(filterID, requiredTagIDs, bannedTagIDs)
  -- in the future it may be too big to load in one go, and
  -- we may want to store the diff and iterate through it in chunks
  local red = GetRedisConnection()
  local matchingPostIDs
  local requiredTags = {}
  local bannedTags = {}
  for _,v in pairs(requiredTagIDs) do
    tinsert(requiredTags,'tagPosts:'..v.id)
  end
  for _,v in pairs(bannedTagIDs) do
    tinsert(bannedTags,'tagPosts:'..v.id)
  end

  local tempKey = filterID..':tempPosts'

  local ok, err = red:sinterstore(tempKey, unpack(requiredTags))
  if not ok then
    ngx.log(ngx.ERR, 'unable to sinterstore tags: ',err)
    red:del(tempKey)
    SetKeepalive(red)
    return nil
  end
  matchingPostIDs, err = red:sdiff(tempKey, unpack(bannedTags))
  if not matchingPostIDs then
    ngx.log(ngx.ERR, 'unable to diff tags: ',err)
    SetKeepalive(red)
    return nil
  end

  ok, err = red:del(tempKey)
  if not ok then
    ngx.log(ngx.ERR, 'unable to del temp posts set "',tempKey,'": ',err)
  end
  SetKeepalive(red)

  if matchingPostIDs == ngx.null then
    return {}
  else
    return matchingPostIDs
  end

end





function write:CreateTag(tagInfo)
  local red = GetRedisConnection()
  local ok, err = red:hmset('tag:'..tagInfo.name,tagInfo)
  if not ok then
    ngx.log(ngx.ERR, 'unable to add tag: ',err)
  end

  ok, err = red:sadd('tags',tagInfo.name)
  if not ok then
    ngx.log(ngx.ERR, 'unable to add tag: ',err)
  end

  SetKeepalive(red)

end

function write:UpdatePostTags(post)
  local red = GetRedisConnection()
  red:init_pipeline()
  for _,tag in pairs(post.tags) do
    red:sadd('post:tagIDs:'..post.id, tag.id)
    red:hmset('posttags:'..post.id..':'..tag.id,tag)
  end
  local res, err = red:commit_pipeline()
  SetKeepalive(red)
  print('update: ',err)
  if err then
    ngx.log(ngx.ERR, 'unable to update post tags: ',err)
  end
  return res
end

function write:UpdateFilterDescription(filter)
  local red = GetRedisConnection()
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
  local red = GetRedisConnection()

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
  local red = GetRedisConnection()
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

    -- add post info
    red:hmset('post:'..postInfo.id,postInfo)

  local results,err = red:commit_pipeline()
  if err then
    ngx.log(ngx.ERR, 'unable to create post:',err)
  end

  SetKeepalive(red)
  return results, err
end


function write:CreateThread(thread)
  local red = GetRedisConnection()
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
  local red = GetRedisConnection()
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
