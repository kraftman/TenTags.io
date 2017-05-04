

local tinsert = table.insert
local base = require 'redis.base'
local read = setmetatable({}, base)





function read:ConvertListToTable(list)
  local info = {}
  for i = 1,#list, 2 do
    info[list[i]] = list[i+1]
  end
  return info
end

function read:GetUnseenElements(checkSHA,baseKey, elements)
  local red = self:GetRedisReadConnection()
  red:init_pipeline()
  ngx.log(ngx.ERR,'checking for sha: ',checkSHA)
  for _,v in pairs(elements) do
    red:evalsha(checkSHA,0,baseKey,10000,0.01,v)
  end
  local res, err = red:commit_pipeline()
  self:SetKeepalive(red)
  if err then
    ngx.log(ngx.ERR, 'unable to check for elemets: ',err)
    return {}
  end
  return res

end

--[[function read:CheckKey(checkSHA,addSHA)
  local keys = {'testr','rsitenrsi','rsiteunrsit'}
  local red = self:GetRedisReadConnection()

  local ok, err = red:evalsha(addSHA,0,'basekey',10000,0.01,'testr')
  if not ok then
    ngx.log(ngx.ERR, 'unable to add key: ',err)
  end

  red:init_pipeline()
    for k,v in pairs(keys) do
      red:evalsha(checkSHA,0,'basekey',10000,0.01,v)
    end
  local res, err = red:commit_pipeline()
  self:SetKeepalive(red)
  for k,v in pairs(res) do
    ngx.log(ngx.ERR,'k:',k,' v: ',v)
  end


end
--]]

function read:GetOldestJob(queueName)
  local realQName = 'queue:'..queueName
  --print('getting job: ',realQName)
  local red = self:GetRedisReadConnection()
  local ok, err = red:zrevrange(realQName, 0, 1)
  self:SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'error getting job: ',err)
  end
  if (not ok) or ok == ngx.null then
    return nil
  else
    return ok[1]
  end
end

function read:GetQueueSize(jobName)
  jobName = 'queue:'..jobName
  local red = self:GetRedisReadConnection()
  local ok, err = red:zcard(jobName)
  self:SetKeepalive(red)
  if not ok then
    return ok, err
  end

  return ok

end


function read:GetBacklogStats(jobName,startAt, endAt)
  jobName = 'backlog:'..jobName
  local red = self:GetRedisReadConnection()
  print('zrangebyscore ',jobName, ' ', startAt, ' ', endAt)
  local ok, err = red:zrangebyscore(jobName, startAt, endAt)

  self:SetKeepalive(red)
  return ok, err
end


function read:GetOldestJobs(jobName, size)
  jobName = 'queue:'..jobName

  local red = self:GetRedisReadConnection()

  local ok, err = red:zrange(jobName, 0, size)
  self:SetKeepalive(red)

  if (not ok) or ok == ngx.null then
    return nil, err
  else
    return ok, err
  end
end

function read:GetSiteUniqueStats(key)
  local red = self:GetRedisReadConnection()
  --print('gettin stats for: ', key)
  local ok, err = red:zrange(key,0, 100)
  --print(to_json(ok))
  local results = {}
  for k, v in pairs(ok) do
    --print('getting stat for : ',v)
    results[v] = red:pfcount(v)
  end
  return results
end

function read:GetSiteStats()
  local red = self:GetRedisReadConnection()
  local ok, err = red:hgetall('sitestats')
  self:SetKeepalive(red)
  if not ok then
    return ok, err
  end
  return self:ConvertListToTable(ok)
end


function read:ConvertShortURL(shortURL)
  local red = self:GetRedisReadConnection()
  shortURL = 'su:'..shortURL
  local key, field = self:SplitShortURL(shortURL)
  local ok, err = red:hget(key,field)
  if err then
    ngx.log(ngx.ERR, 'unable to get short url: ',err)
  end
  if ok == ngx.null then
    return nil
  end

  return ok, err
end

function read:GetInvalidationRequests(startTime, endTime)
  local red = self:GetRedisReadConnection()
  local ok, err = red:zrangebyscore('invalidationRequests', startTime, endTime)
  red:close()
  if ok == ngx.null then
    return nil
  end
  if err then
    ngx.log(ngx.ERR, 'unable to get invalidation requests: ',err)
  end
  return ok,err

end

function read:GetFilterIDsByTags(tags)
  local red = self:GetRedisReadConnection()
  -- for each tag
  -- load all of the filters that care about the tag
  -- if they want the tag , add them to the list
  -- if they dont want the tag, mark them as out of the list
  -- purge marked tags

  local newList = {}

  for _,tag in pairs(tags) do
    local ok, err = red:hgetall('tag:filters:'..tag.name)

    ok = self:ConvertListToTable(ok)
    if not ok then
      return ok, err
    end

    for filterID,filterType in pairs(ok) do
      if filterType == 'required' then
        if not newList[filterID] then
          newList[filterID] = filterID
        end
      elseif filterType == 'banned' then
        -- we need to be confident so we dont accidentally hide the post
        -- see issue gh-30
        print(tag.up)
        if tonumber(tag.up) > 20 then
          newList[filterID] = 'banned'
        end
      end
    end

    for k,v in pairs(newList) do
      if v == 'banned' then
        newList[k] = nil
      end
    end

  end


  self:SetKeepalive(red)
  return newList
end

function read:VerifyReset(emailAddr, resetKey)
  local red = self:GetRedisReadConnection()

  local ok, err = red:get('emailReset:'..emailAddr)
  self:SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to get email reset: ',err)
  end

  if ok == resetKey then
    print('key is valid')
    return true
  end

end

function read:GetTag(tagName)
  local red = self:GetRedisReadConnection()
  local ok, err = red:hgetall('tag:'..tagName)
  self:SetKeepalive(red)
  if ok then
    return self:ConvertListToTable(ok)
  else
    return nil, err
  end
end

function read:GetAllTags()
  local red = self:GetRedisReadConnection()
  local ok, results, err
  ok, err = red:smembers('tags')
  if not ok then
    ngx.log(ngx.ERR, 'unable to load tags:',err)
    return {}
  end

  red:init_pipeline()
  for _,v in pairs(ok) do
    red:hgetall('tag:'..v)
  end
   results, err = red:commit_pipeline(#ok)

  for k,v in pairs(results) do
    results[k] = self:ConvertListToTable(v)
  end

  if err then
    ngx.log(ngx.ERR, 'error reading tags from reds: ',err)
  end
  self:SetKeepalive(red)
  return results
end

function read:GetFiltersBySubs(startAt,endAt)
  local red = self:GetRedisReadConnection()
  local ok, err = red:zrange('filtersubs',startAt,endAt)
  self:SetKeepalive(red)

  if not ok then
    ngx.log(ngx.ERR, 'unable to get filters: ',err)
    return
  end

  if ok == ngx.null then
    return
  else
    return ok
  end
end

function read:GetUserThreads(userID, startAt, range)
  local red = self:GetRedisReadConnection()
  local ok, err = red:zrange('UserThreads:'..userID,startAt,startAt+range)
  self:SetKeepalive(red)
  print(startAt, range, #ok)
  if not ok then
    ngx.log(ngx.ERR, 'unable to get user threads: ',err)
    return {}
  end
  if ok == ngx.null then
    return {}
  else
    return ok
  end
end

function read:ConvertThreadFromRedis(thread)

  thread  = self:ConvertListToTable(thread)
  local viewers = {}


  for k,_ in pairs(thread) do
    if k:find('viewer') then
      local viewerID = k:match('viewer:(%w+)')
      if viewerID then
        thread[k] = nil
        tinsert(viewers,viewerID)
      end
    end
  end

  thread.viewers = viewers

  return thread
end

function read:GetThreadInfo(threadID)
  local red = self:GetRedisReadConnection()

  local ok, err = red:hgetall('Thread:'..threadID)
  if not ok then
    ngx.log(ngx.ERR, 'unable to get thread info:',err)
    return {}
  end

  local thread = read:ConvertThreadFromRedis(ok)

  ok,err = red:hgetall('ThreadMessages:'..threadID)
  if not ok then
    ngx.log(ngx.ERR, 'unable to load thread messages: ',err)
    return thread
  end

  thread.messages = self:ConvertListToTable(ok)
  for k,v in pairs(thread.messages) do
    thread.messages[k] = self:from_json(v)
  end

  return thread
end

function read:GetThreadInfos(threadIDs)
  local red = self:GetRedisReadConnection()
  red:init_pipeline()
    for _,threadID in pairs(threadIDs) do
      red:hgetall('Thread:'..threadID)
    end
  local res, err = red:commit_pipeline()
  if err then
    ngx.log(ngx.ERR, 'unable to load thread: ',err)
    return {}
  end
  for k,v in pairs(res) do
    res[k] = self:ConvertThreadFromRedis(v)
  end


  red:init_pipeline()
    for _,thread in pairs(res) do
      red:hgetall('ThreadMessages:'..thread.id)
    end
  local msgs
  msgs, err = red:commit_pipeline()
  if err then
    ngx.log(ngx.ERR, 'unable to get thread messages: ',err)
    return {}
  end

  --convert from json
  for k,message in pairs(msgs) do
    msgs[k] = self:ConvertListToTable(message)
    local threadID
    for m,n in pairs(msgs[k]) do

      msgs[k][m] = self:from_json(n)
      if not threadID then
      threadID = msgs[k][m].threadID
      end
    end
    for _,thread in pairs(res) do
      if thread.id == threadID then
        thread.messages = msgs[k]
      end
    end

  end


  return res
end

function read:GetFilterID(filterName)
  local red = self:GetRedisReadConnection()
  local ok, err = red:get('filterid:'..filterName)
  if not ok then
    ngx.log(ngx.ERR, 'unable to get filter id from name: ',err)
  end
  self:SetKeepalive(red)
  if ok == ngx.null then
    return nil
  else
    return ok
  end
end



function read:GetFilter(filterID)
  --print(self:to_json(filterID))
  local red = self:GetRedisReadConnection()
  local ok, err = red:hgetall('filter:'..filterID)
  if not ok then
    ngx.log(ngx.ERR, 'unable to load filter info: ',err)
  end
  if ok == ngx.null then
    return nil
  end
  local filter = self:ConvertListToTable(ok)
  --error()

  filter.bannedUsers = {}
  filter.bannedDomains = {}
  filter.mods = {}
  filter.relatedFilterIDs = {}
  local banInfo
  for k, v in pairs(filter) do
    if type(k) == 'string' then
      if k:find('^bannedUser:') then
        banInfo = self:from_json(v)
        filter.bannedUsers[banInfo.userID] = banInfo
        filter[k] = nil
      elseif k:find('^bannedDomain:') then
        tinsert(filter.bannedDomains, self:from_json(v))
        banInfo = self:from_json(v)
        filter.bannedDomains[banInfo.domainName] = banInfo
        filter[k] = nil
      elseif k:find('mod:') then
        tinsert(filter.mods, self:from_json(v))
        filter[k] = nil
      elseif k:find('^relatedFilter:') then
        tinsert(filter.relatedFilterIDs, v)
        filter[k] = nil
      end
    end
  end

  ok, err = red:smembers('filter:bannedTagNames:'..filterID)
  if not ok then
    ngx.log(ngx.ERR, 'unable to load banned tags: ',err)
  end
  if ok == ngx.null then
    filter.bannedTagNames = {}
  else
    filter.bannedTagNames = ok
  end

  ok, err = red:smembers('filter:requiredTagNames:'..filterID)
  if not ok then
    ngx.log(ngx.ERR, 'unable to load required tags: ',err)
  end
  if ok == ngx.null then
    filter.requiredTagNames = {}
  else
    filter.requiredTagNames = ok
  end
  return filter


end

function read:SearchFilters(searchString)
  searchString = '*'..searchString..'*'
  local red = self:GetRedisReadConnection()
  print(searchString)
  local ok,err = red:sscan('filterNames', 0, 'match', searchString)
  print(self:to_json(ok))
  if ok then
    return ok[2]
  end
  return ok,err
end

function read:GetPost(postID)
  local red = self:GetRedisReadConnection()
  local ok, err = red:hgetall('post:'..postID)
  if not ok then
    ngx.log(ngx.ERR, 'unable to get post:',err)
  end

  if ok == ngx.null then
    return nil
  end

  local post = self:ConvertListToTable(ok)
  post.viewers = {}
  post.filters = {}
  post.edits = {}

  for k,v in pairs(post) do
    if k:find('^viewer:') then
      local viewerID = k:match('^viewer:(%w+)')
      tinsert(post.viewers, viewerID)
      post[k] = nil
    elseif k:find('^filter:') then
      local filterID = k:match('^filter:(%w+)')
      tinsert(post.filters, filterID)
      post[k] = nil
    elseif k:find('^specialTag:') then
      post[k] = v == 'true' and true or nil

    elseif k:find('^edit:') then
      post.edits[k] = self:from_json(v)
      post[k] = nil
    end
  end

  local postTags
  postTags, err = red:smembers('post:tagNames:'..postID)
  if not postTags then
    ngx.log(ngx.ERR, 'unable to get post tags:',err)
  end
  if postTags == ngx.null then
    postTags = {}
  end

  post.tags = {}

  for _, tagName in pairs(postTags) do
    ok, err = red:hgetall('posttags:'..postID..':'..tagName)
    if not ok then
      ngx.log(ngx.ERR, 'unable to load posttags:',err)
    end

    if ok ~= ngx.null then
      local tag = self:ConvertListToTable(ok)
      if tag and tag.score then
        tag.score = tonumber(tag.score)
      end
      tinsert(post.tags,tag)
    end
  end

  self:SetKeepalive(red)

  --[[
  ok,err = red:smembers('postfilters:'..postID)
  if not ok then
    ngx.log(ngx.ERR, 'could not load filters: ',err)
  end
  --ngx.log(ngx.ERR, self:to_json(ok))
  post.filters = ok
  --]]

  return post
end

function read:GetFilterPosts(filter, sortBy)
  local key = 'filterposts:score:'
  if sortBy == 'fresh' then
    key = 'filterposts:datescore:'
  elseif sortBy == 'new' then
    key = 'filterposts:date:'
  elseif sortBy == 'best' then
    key = 'filterposts:score:'
  end
  local red = self:GetRedisReadConnection()
  local ok, err = red:zrevrange(key..filter.id,0,50)
  if not ok then
    ngx.log(ngx.ERR, 'unable to get filter posts ',err)
  end
  ok = ok ~= ngx.null and ok or {}
  self:SetKeepalive(red)
  return ok
end


function read:GetAllNewPosts(rangeStart,rangeEnd)
  local red = self:GetRedisReadConnection()
  local ok, err = red:zrevrange('filterpostsall:date',rangeStart,rangeEnd)
  self:SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to get new posts: ',err)
  end

  return ok ~= ngx.null and ok or {}
end

function read:GetAllFreshPosts(rangeStart,rangeEnd)
  local red = self:GetRedisReadConnection()
  local ok, err = red:zrevrange('filterpostsall:datescore',rangeStart,rangeEnd)
  self:SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to get fresh posts: ',err)
  end

  return ok ~= ngx.null and ok or {}
end

function read:SearchTags(searchString)
  local red = self:GetRedisReadConnection()
  searchString = searchString..'*'
  local ok, err = red:sscan('tags', 0, 'match', searchString)
  self:SetKeepalive(red)
  if ok then
    return ok[2]
  else
    return ok, err
  end
end

function read:GetAllBestPosts(rangeStart,rangeEnd)
  local red = self:GetRedisReadConnection()
  local ok, err = red:zrevrange('filterpostsall:score',rangeStart,rangeEnd)
  self:SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to get best posts: ',err)
  end

  return ok ~= ngx.null and ok or {}
end


function read:BatchLoadPosts(posts)
  local red = self:GetRedisReadConnection()
  red:init_pipeline()
  for _,postID in pairs(posts) do
      red:hgetall('post:'..postID)
  end
  local results, err = red:commit_pipeline()
  if not results then
    ngx.log(ngx.ERR, 'unable batch get post info:', err)
  end
  local processedResults = {}

  for _,v in pairs(results) do
    tinsert(processedResults,self:ConvertListToTable(v))
  end

  return results
end

function read:GetTag(tagName)
  local red = self:GetRedisReadConnection()
  local ok, err = red:hgetall('tag:'..tagName)
  self:SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to load tag:',err)
    return
  end
  local tagInfo = self:ConvertListToTable(ok)
  if tagInfo.name then
    return tagInfo
  else
    return nil
  end

  return tagInfo
end

function read:GetTagPosts(tagName)
  local red = self:GetRedisReadConnection()
  local ok, err = red:smembers('tagPosts:'..tagName)
  self:SetKeepalive(red)
  if not ok then
    return nil, err
  end

  return ok
end






return read
