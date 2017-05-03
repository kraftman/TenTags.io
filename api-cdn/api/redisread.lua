

local redis = require "resty.redis"
local tinsert = table.insert
local from_json = (require 'lapis.util').from_json
local to_json = (require 'lapis.util').to_json
local util = require 'util'

local read = {}





function read:ConvertListToTable(list)
  local info = {}
  for i = 1,#list, 2 do
    info[list[i]] = list[i+1]
  end
  return info
end

function read:GetUnseenElements(checkSHA,baseKey, elements)
  local red = util:GetRedisReadConnection()
  red:init_pipeline()
  ngx.log(ngx.ERR,'checking for sha: ',checkSHA)
  for _,v in pairs(elements) do
    red:evalsha(checkSHA,0,baseKey,10000,0.01,v)
  end
  local res, err = red:commit_pipeline()
  if err then
    ngx.log(ngx.ERR, 'unable to check for elemets: ',err)
    return {}
  end
  return res

end

--[[function read:CheckKey(checkSHA,addSHA)
  local keys = {'testr','rsitenrsi','rsiteunrsit'}
  local red = util:GetRedisReadConnection()

  local ok, err = red:evalsha(addSHA,0,'basekey',10000,0.01,'testr')
  if not ok then
    ngx.log(ngx.ERR, 'unable to add key: ',err)
  end

  red:init_pipeline()
    for k,v in pairs(keys) do
      red:evalsha(checkSHA,0,'basekey',10000,0.01,v)
    end
  local res, err = red:commit_pipeline()
  util:SetKeepalive(red)
  for k,v in pairs(res) do
    ngx.log(ngx.ERR,'k:',k,' v: ',v)
  end


end
--]]

function read:GetOldestJob(queueName)
  local realQName = 'queue:'..queueName
  --print('getting job: ',realQName)
  local red = util:GetRedisReadConnection()
  local ok, err = red:zrevrange(realQName, 0, 1)
  util:SetKeepalive(red)
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
  local red = util:GetRedisReadConnection()
  local ok, err = red:zcard(jobName)
  util:SetKeepalive(red)
  if not ok then
    return ok, err
  end

  return ok

end


function read:GetBacklogStats(jobName,startAt, endAt)
  jobName = 'backlog:'..jobName
  local red = util:GetRedisReadConnection()
  print('zrangebyscore ',jobName, ' ', startAt, ' ', endAt)
  local ok, err = red:zrangebyscore(jobName, startAt, endAt)

  util:SetKeepalive(red)
  return ok, err
end


function read:GetOldestJobs(jobName, size)
  jobName = 'queue:'..jobName

  local red = util:GetRedisReadConnection()

  local ok, err = red:zrange(jobName, 0, size)
  util:SetKeepalive(red)

  if (not ok) or ok == ngx.null then
    return nil, err
  else
    return ok, err
  end
end


function read:ConvertShortURL(shortURL)
  local red = util:GetRedisReadConnection()
  shortURL = 'su:'..shortURL
  local key, field = util:SplitShortURL(shortURL)
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
  local red = util:GetRedisReadConnection()
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

  local red = util:GetRedisReadConnection()
  red:init_pipeline()
    for _,v in pairs(tags) do
      --print('tag:filters:'..v.id)
      red:hgetall('tag:filters:'..v.name)
    end
  local results, err = red:commit_pipeline()
  util:SetKeepalive(red)

  for k,v in pairs(results) do
    results[k] = self:ConvertListToTable(v)
  end

  if err then
    ngx.log(ngx.ERR, 'error retrieving filters for tags:',err)
  end

  return results
end

function read:VerifyReset(emailAddr, resetKey)
  local red = util:GetRedisReadConnection()

  local ok, err = red:get('emailReset:'..emailAddr)
  if not ok then
    ngx.log(ngx.ERR, 'unable to get email reset: ',err)
  end

  if ok == resetKey then
    print('key is valid')
    return true
  end

end

function read:GetTag(tagName)
  local red = util:GetRedisReadConnection()
  local ok, err = red:hgetall('tag:'..tagName)
  util:SetKeepalive(red)
  if ok then
    return self:ConvertListToTable(ok)
  else
    return nil, err
  end
end

function read:GetAllTags()
  local red = util:GetRedisReadConnection()
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
  util:SetKeepalive(red)
  return results
end

function read:GetFiltersBySubs(startAt,endAt)
  local red = util:GetRedisReadConnection()
  local ok, err = red:zrange('filtersubs',startAt,endAt)

  if not ok then
    ngx.log(ngx.ERR, 'unable to get filters: ',err)
    util:SetKeepalive(red)
    return
  end

  if ok == ngx.null then
    util:SetKeepalive(red)
    return
  else
    return ok
  end
end

function read:GetUserThreads(userID)
  local red = util:GetRedisReadConnection()
  local ok, err = red:zrange('UserThreads:'..userID,0,10)
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
      ngx.log(ngx.ERR, 'found viewer:',k)
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
  local red = util:GetRedisReadConnection()

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
    thread.messages[k] = from_json(v)
  end

  return thread
end

function read:GetThreadInfos(threadIDs)
  local red = util:GetRedisReadConnection()
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

      msgs[k][m] = from_json(n)
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
  local red = util:GetRedisReadConnection()
  local ok, err = red:get('filterid:'..filterName)
  if not ok then
    ngx.log(ngx.ERR, 'unable to get filter id from name: ',err)
  end
  util:SetKeepalive(red)
  if ok == ngx.null then
    return nil
  else
    return ok
  end
end



function read:GetFilter(filterID)
  --print(to_json(filterID))
  local red = util:GetRedisReadConnection()
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
        banInfo = from_json(v)
        filter.bannedUsers[banInfo.userID] = banInfo
        filter[k] = nil
      elseif k:find('^bannedDomain:') then
        tinsert(filter.bannedDomains, from_json(v))
        banInfo = from_json(v)
        filter.bannedDomains[banInfo.domainName] = banInfo
        filter[k] = nil
      elseif k:find('mod:') then
        tinsert(filter.mods, from_json(v))
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
  local red = util:GetRedisReadConnection()
  print(searchString)
  local ok,err = red:sscan('filterNames', 0, 'match', searchString)
  print(to_json(ok))
  if ok then
    return ok[2]
  end
  return ok,err
end

function read:GetPost(postID)
  local red = util:GetRedisReadConnection()
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
      post.edits[k] = from_json(v)
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

  --[[
  ok,err = red:smembers('postfilters:'..postID)
  if not ok then
    ngx.log(ngx.ERR, 'could not load filters: ',err)
  end
  --ngx.log(ngx.ERR, to_json(ok))
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
  local red = util:GetRedisReadConnection()
  local ok, err = red:zrevrange(key..filter.id,0,50)
  if not ok then
    ngx.log(ngx.ERR, 'unable to get filter posts ',err)
  end
  ok = ok ~= ngx.null and ok or {}
  util:SetKeepalive(red)
  return ok
end


function read:GetAllNewPosts(rangeStart,rangeEnd)
  local red = util:GetRedisReadConnection()
  local ok, err = red:zrevrange('filterpostsall:date',rangeStart,rangeEnd)
  util:SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to get new posts: ',err)
  end

  return ok ~= ngx.null and ok or {}
end

function read:GetAllFreshPosts(rangeStart,rangeEnd)
  local red = util:GetRedisReadConnection()
  local ok, err = red:zrevrange('filterpostsall:datescore',rangeStart,rangeEnd)
  util:SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to get fresh posts: ',err)
  end

  return ok ~= ngx.null and ok or {}
end

function read:SearchTags(searchString)
  local red = util:GetRedisReadConnection()
  searchString = searchString..'*'
  local ok, err = red:sscan('tags', 0, 'match', searchString)
  util:SetKeepalive(red)
  if ok then
    return ok[2]
  else
    return ok, err
  end
end

function read:GetAllBestPosts(rangeStart,rangeEnd)
  local red = util:GetRedisReadConnection()
  local ok, err = red:zrevrange('filterpostsall:score',rangeStart,rangeEnd)
  util:SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to get best posts: ',err)
  end

  return ok ~= ngx.null and ok or {}
end


function read:BatchLoadPosts(posts)
  local red = util:GetRedisReadConnection()
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
  local red = util:GetRedisReadConnection()
  local ok, err = red:hgetall('tag:'..tagName)
  util:SetKeepalive(red)
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
  local red = util:GetRedisReadConnection()
  local ok, err = red:smembers('tagPosts:'..tagName)
  if not ok then
    return nil, err
  end

  return ok
end






return read
