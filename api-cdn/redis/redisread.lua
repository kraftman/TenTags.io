

local tinsert = table.insert
local base = require 'redis.base'
local read = setmetatable({}, base)

read.__index = read

local ConvertListToTable = function(list)
  local info = {}
  for i = 1,#list, 2 do
    info[list[i]] = list[i+1]
  end
  return info
end

function read:GetOldestJob(queueName)

  local realQName = 'queue:'..queueName
  local red = self:GetRedisReadConnection()
  local ok, err = red:zrevrange(realQName, 0, 1)
  self:SetKeepalive(red)

  if (not ok) or ok == ngx.null then
    ngx.log(ngx.ERR, 'error getting job: ',err)
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
    ngx.log(ngx.ERR, 'unable to get q size: ', err);
    return ok, err
  end

  return ok

end

function read:GetView(viewID)
  local red = self:GetRedisReadConnection()
  local ok, err = red:hgetall('view:'..viewID)
  self:SetKeepalive(red)
  if not ok or ok == ngx.null then
    ngx.log(ngx.ERR, 'unable to get view: ', err)
    return nil, err
  end

  ok = ConvertListToTable(ok)
  if ok.filters then
    ok.filters = self:from_json(ok.filters)
  else
    ok.filters = {}
  end
  for i = #ok.filters, 1, -1 do
    print(ok.filters[i])
    if ok.filters[i] == ngx.null then
      table.remove(ok.filters, i)
    end
  end


  return ok
end


function read:GetBacklogStats(jobName,startAt, endAt)
  jobName = 'backlog:'..jobName
  local red = self:GetRedisReadConnection()
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
  local ok, err = red:zrevrange(key,0, 10)
  if not ok then
    ngx.log(ngx.ERR, 'unable to get site stat:', err);
    return ok, err
  end
  local results = {}
  for _, v in pairs(ok) do
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
  return ConvertListToTable(ok)
end


function read:ConvertShortURL(shortURL)
  local red = self:GetRedisReadConnection()
  shortURL = 'su:'..shortURL
  local key, field = self:SplitShortURL(shortURL)
  local ok, err = red:hget(key,field)
  if err then
    ngx.log(ngx.ERR, 'unable to get short url: ',err)
    return ok, err
  end
  if ok == ngx.null then
    return nil
  end

  return ok, err
end

function read:GetInvalidationRequests(startTime, endTime)
  local red = self:GetRedisReadConnection()
  local ok, err = red:zrangebyscore('invalidationRequests', startTime, endTime)
  self:SetKeepalive(red)

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

  red:init_pipeline()

  for _,tag in pairs(tags) do
    red:hgetall('tag:filters:'..tag.name)
  end

  local ok, err = red:commit_pipeline()
  self:SetKeepalive(red)
  return ok, err
end

function read:GetReports(startAt, range)
  startAt = startAt or 0
  range = range or 100

  local red = self:GetRedisReadConnection()
  local ok, err = red:zrange('reports:', startAt, startAt+range)
  self:SetKeepalive(red)
  return ok, err
end

function read:GetRelevantFilters(tags)
  local red = self:GetRedisReadConnection()
  -- for each tag
  -- load all of the filters that care about the tag
  -- if they want the tag , add them to the list
  -- if they dont want the tag, mark them as out of the list
  -- purge marked tags

  local newList = {}

  for _,tag in pairs(tags) do
    local ok, err = red:hgetall('tag:filters:'..tag.name)

    ok = ConvertListToTable(ok)
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
    return true
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
    results[k] = ConvertListToTable(v)
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
  local ok, err = red:zrevrange('UserThreads:'..userID,startAt,startAt+range)
  self:SetKeepalive(red)
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

  thread = ConvertListToTable(thread)
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

  local thread = self:ConvertThreadFromRedis(ok)

  ok, err = red:hgetall('ThreadMessages:'..threadID)
  if not ok then
    ngx.log(ngx.ERR, 'unable to load thread messages: ',err)
    return thread
  end

  thread.messages = ConvertListToTable(ok)
  for k,v in pairs(thread.messages) do
    thread.messages[k] = self:from_json(v)
  end
  --thread.viewers = self:from_json(thread.viewers)

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
    msgs[k] = ConvertListToTable(message)
    local threadID
    for m, n in pairs(msgs[k]) do
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
  local filter = ConvertListToTable(ok)
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

  if not filter.ownerID or filter.ownerID:gsub(' ', '') == '' then
    filter.ownerID = filter.createdBy
  end

  return filter
end

function read:SearchFilters(searchString)
  searchString = '*'..searchString..'*'
  local red = self:GetRedisReadConnection()
  local ok,err = red:sscan('filterNames', 0, 'match', searchString)
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

  if ok == ngx.null or not next(ok) then
    return nil
  end

  local post = ConvertListToTable(ok)
  post.viewers = {}
  post.filters = {}
  post.edits = {}
  post.reports = {}

  for k,v in pairs(post) do
    if k:find('^viewer:') then
      local viewerID = k:match('^viewer:(%w+)')
      tinsert(post.viewers, viewerID)
      post[k] = nil
    elseif k:find('^filter:') then
      local filterID = k:match('^filter:(%w+)')
      tinsert(post.filters, filterID)
      post[k] = nil

    elseif k:find('^reports:') then
      local reporterID = k:match('^reports:(%w+)')
      post.reports[reporterID] = v

      post[k] = nil
    elseif k:find('^nsfl:') then
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
      local tag = ConvertListToTable(ok)
      if tag and tag.score then
        tag.score = tonumber(tag.score)
      end
      tinsert(post.tags,tag)
    end
  end

  self:SetKeepalive(red)

  post.images = self:from_json(post.images or '[]')

  --[[
  ok,err = red:smembers('postfilters:'..postID)
  if not ok then
    ngx.log(ngx.ERR, 'could not load filters: ',err)
  end
  --ngx.log(ngx.ERR, self:to_json(ok))
  post.filters = ok
  --]]
  post.nsfwLevel = post.nsfwLevel and tonumber(post.nsfwLevel)
  if not post.id then
    return nil
  end

  return post
end

function read:GetFilterPosts(filter, sortBy,startAt, range)
  local key = 'filterposts:score:'
  if sortBy == 'fresh' then
    key = 'filterposts:datescore:'
  elseif sortBy == 'new' then
    key = 'filterposts:date:'
  elseif sortBy == 'best' then
    key = 'filterposts:score:'
  end

  local red = self:GetRedisReadConnection()

  local ok, err = red:zrevrange(key..filter.id, startAt, startAt+range)
  if not ok then
    ngx.log(ngx.ERR, 'unable to get filter posts ',err)
  end
  ok = ok ~= ngx.null and ok or {}
  self:SetKeepalive(red)
  return ok
end

function read:GetImage(imageID)
  local red = self:GetRedisReadConnection()
  local ok, err = red:hgetall('image:'..imageID)
  ok = ConvertListToTable(ok)
  self:SetKeepalive(red)
  ok.takedowns = self:from_json(ok.takedowns or '[]')

  if ok == ngx.null then
    return nil
  end

  return ok, err
end

function read:GetPendingTakedowns(limit)
  local red = self:GetRedisReadConnection()
  local ok, err = red:zrevrange('pendingTakedowns', 0, limit)
  self:SetKeepalive(red)
  return ok, err
end

function read:GetTakedown(requestID)
  local red = self:GetRedisReadConnection()
  local ok, err = red:hgetall('takedown:'..requestID)
  self:SetKeepalive(red)
  if not ok or ok == ngx.null then
    return nil, 'not found'
  end
  ok = ConvertListToTable(ok)
  return ok, err
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

function read:GetFrontPage(userID, sortBy, userFilterIDs, startAt, range)
  local red = self:GetRedisReadConnection()
  local destionationKey = 'frontPage:'..userID..':'..sortBy

  local ok, err = red:zrevrange(destionationKey, startAt, startAt+range)
  if not ok then
    return nil, err
  end

  if ok == ngx.null or #ok < range then
    local timeUnits = {'day','week', 'month'}
    for _,timeUnit in ipairs(timeUnits) do
      -- go bigger until we get enough
      ok, err = self:GenerateUserFrontPage(userID, userFilterIDs, timeUnit, sortBy)
      if not ok then
        self:SetKeepalive(red)
        return ok, err
      end

      ok, err = red:zrevrange(destionationKey, startAt, startAt+range)
      if not ok then
        self:SetKeepalive(red)
        return ok, err
      end

      if #ok >= range then
        self:SetKeepalive(red)
        return ok
      end
    end
  end

  -- we have as many as we can get, send them back
  self:SetKeepalive(red)
  return ok, err
end

function read:GenerateUserFrontPage(userID, userFilterIDs, range, sortBy)
  --we're going to write to the slave to save the master overhead
  range = range or 'day'
  local red = self:GetRedisReadConnection()

  local destinationKey = 'frontPage:'..userID..':'..sortBy

  local sortToKey = {
    fresh = 'filterposts:datescore:',
    new = 'filterposts:date:',
    best = 'filterposts:score:'
  }
  local keyedFilterIDs = {}

  for _,filterID in pairs(userFilterIDs) do
    table.insert(keyedFilterIDs, sortToKey[sortBy]..range..':'..filterID)
  end
  if #keyedFilterIDs == 0 then
    return {}
  end

  table.insert(keyedFilterIDs, 'AGGREGATE')
  table.insert(keyedFilterIDs, 'MAX')
  local ok, err = red:zunionstore(destinationKey,#keyedFilterIDs-2,unpack(keyedFilterIDs))
  if not ok then
    return nil, err
  end
  ok, err = red:expire(destinationKey, 300)

  return ok, err

end

function read:GetParentIDs(postIDs)
  local red = self:GetRedisReadConnection()
  red:init_pipeline()
  for _,postID in pairs(postIDs) do
    red:hget('post:'..postID,'parentID')
  end
  local ok, err = red:commit_pipeline()
  if not ok then
    return nil, 'couldnt commit pipeline:', err
  end
  self:SetKeepalive(red)
  local postParents = {}
  for i = 1, #postIDs do
    tinsert(postParents, {postID = postIDs[i], parentID = ok[i]})
  end
  return postParents

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
    tinsert(processedResults, ConvertListToTable(v))
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
  local tagInfo = ConvertListToTable(ok)
  if tagInfo.name then
    return tagInfo
  else
    return nil
  end

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
