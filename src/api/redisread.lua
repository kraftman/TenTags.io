

local redis = require "resty.redis"
local tinsert = table.insert
local from_json = (require 'lapis.util').from_json

local read = {}

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
  local ok, err = red:set_keepalive(10, 10)
  if not ok then
      ngx.say("failed to set keepalive: ", err)
      return
  end
end

function read:ConvertListToTable(list)
  local info = {}
  for i = 1,#list, 2 do
    info[list[i]] = list[i+1]
  end
  return info
end

function read:GetUnseenElements(checkSHA,baseKey, elements)
  local red = GetRedisConnection()
  red:init_pipeline()
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
  local red = GetRedisConnection()

  local ok, err = red:evalsha(addSHA,0,'basekey',10000,0.01,'testr')
  if not ok then
    ngx.log(ngx.ERR, 'unable to add key: ',err)
  end

  red:init_pipeline()
    for k,v in pairs(keys) do
      red:evalsha(checkSHA,0,'basekey',10000,0.01,v)
    end
  local res, err = red:commit_pipeline()
  SetKeepalive(red)
  for k,v in pairs(res) do
    ngx.log(ngx.ERR,'k:',k,' v: ',v)
  end


end
--]]

function read:GetOldestJob(queueName)
  local red = GetRedisConnection()
  local ok, err = red:zrevrange(queueName, 0, 1)
  SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'error getting job: ',err)
  end
  if (not ok) or ok == ngx.null then
    return nil
  else
    return ok[1]
  end

end

function read:ConvertShortURL(shortURL)
  local red = GetRedisConnection()
  local ok, err = red:get('shortURL:'..shortURL)
  if err then
    ngx.log(ngx.ERR, 'unable to get short url: ',err)
  end
  if ok == ngx.null then
    return nil
  end

  return ok, err
end

function read:GetFilterIDsByTags(tags)

  local red = GetRedisConnection()
  red:init_pipeline()
  for _,v in pairs(tags) do
    --print('tag:filters:'..v.id)
    red:hgetall('tag:filters:'..v.id)
  end
  local results, err = red:commit_pipeline()
  SetKeepalive(red)

  for k,v in pairs(results) do
    results[k] = self:ConvertListToTable(v)
  end

  if err then
    ngx.log(ngx.ERR, 'error retrieving filters for tags:',err)
  end

  return results
end

function read:VerifyReset(emailAddr, resetKey)
  local red = GetRedisConnection()

  local ok, err = red:get('emailReset:'..emailAddr)
  if not ok then
    ngx.log(ngx.ERR, 'unable to get email reset: ',err)
  end

  if ok == resetKey then
    print('key is valid')
    return true
  end

end

function read:GetAllTags()
  local red = GetRedisConnection()
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
  SetKeepalive(red)
  return results
end

function read:GetFiltersBySubs(startAt,endAt)
  local red = GetRedisConnection()
  local ok, err = red:zrange('filtersubs',startAt,endAt)

  if not ok then
    ngx.log(ngx.ERR, 'unable to get filters: ',err)
    SetKeepalive(red)
    return
  end

  if ok == ngx.null then
    SetKeepalive(red)
    return
  else
    return ok
  end
end

function read:GetUserThreads(userID)
  local red = GetRedisConnection()
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
  local red = GetRedisConnection()

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
  local red = GetRedisConnection()
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
  local red = GetRedisConnection()
  local ok, err = red:get('filterid:'..filterName)
  if not ok then
    ngx.log(ngx.ERR, 'unable to get filter id from name: ',err)
  end
  SetKeepalive(red)
  if ok == ngx.null then
    return nil
  else
    return ok
  end
end



function read:GetFilter(filterID)
  local red = GetRedisConnection()
  local ok, err = red:hgetall('filter:'..filterID)
  if not ok then
    ngx.log(ngx.ERR, 'unable to load filter info: ',err)
  end
  if ok == ngx.null then
    return nil
  end
  local filter = self:ConvertListToTable(ok)

  filter.bannedUsers = {}
  filter.bannedDomains = {}
  filter.mods = {}
  local banInfo
  for k, v in pairs(filter) do
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
    end
  end


  --print(to_json(filter))

  ok, err = red:smembers('filter:bannedtags:'..filterID)
  if not ok then
    ngx.log(ngx.ERR, 'unable to load banned tags: ',err)
  end
  if ok == ngx.null then
    filter.bannedTags = {}
  else
    filter.bannedTags = ok
  end

  ok, err = red:smembers('filter:requiredtags:'..filterID)
  if not ok then
    ngx.log(ngx.ERR, 'unable to load required tags: ',err)
  end
  if ok == ngx.null then
    filter.requiredTags = {}
  else
    filter.requiredTags = ok
  end
  return filter


end

function read:GetPost(postID)
  local red = GetRedisConnection()
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

  for k,_ in pairs(post) do
    print(k)
    if k:find('^viewer:') then
      local viewerID = k:match('^viewer:(%w+)')
      tinsert(post.viewers, viewerID)
      post[k] = nil
    elseif k:find('^filter:') then
      local filterID = k:match('^filter:(%w+)')
      print('adding filter: ',filterID)
      tinsert(post.filters, filterID)
      post[k] = nil
    end
  end

  local postTags
  postTags, err = red:smembers('post:tagIDs:'..postID)
  if not postTags then
    ngx.log(ngx.ERR, 'unable to get post tags:',err)
  end
  if postTags == ngx.null then
    postTags = {}
  end

  post.tags = {}

  for _, tagID in pairs(postTags) do
    ok, err = red:hgetall('posttags:'..postID..':'..tagID)
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

function read:GetFilterPosts(filter)
  local red = GetRedisConnection()
  local ok, err = red:zrange('filterposts:score:'..filter.id,0,50)
  if not ok then
    ngx.log(ngx.ERR, 'unable to get filter posts ',err)
  end
  ok = ok ~= ngx.null and ok or {}
  SetKeepalive(red)
  return ok
end


function read:GetAllNewPosts(rangeStart,rangeEnd)
  local red = GetRedisConnection()
  local ok, err = red:zrevrange('filterpostsall:date',rangeStart,rangeEnd)
  SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to get new posts: ',err)
  end

  return ok ~= ngx.null and ok or {}
end

function read:GetAllFreshPosts(rangeStart,rangeEnd)
  local red = GetRedisConnection()
  local ok, err = red:zrevrange('filterpostsall:datescore',rangeStart,rangeEnd)
  SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to get fresh posts: ',err)
  end

  return ok ~= ngx.null and ok or {}
end

function read:GetAllBestPosts(rangeStart,rangeEnd)
  local red = GetRedisConnection()
  local ok, err = red:zrevrange('filterpostsall:score',rangeStart,rangeEnd)
  SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to get best posts: ',err)
  end

  return ok ~= ngx.null and ok or {}
end


function read:BatchLoadPosts(posts)
  local red = GetRedisConnection()
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
  local red = GetRedisConnection()
  local ok, err = red:hgetall('tag:'..tagName)
  SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to load tag:',err)
    return
  end
  local tagInfo = self:ConvertListToTable(ok)

  return tagInfo
end






return read
