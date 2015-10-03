

local redis = require "resty.redis"
local tinsert = table.insert

local read = {}

local function GetRedisConnection()
  local red = redis:new()
  red:set_timeout(1000)
  local ok, err = red:connect("127.0.0.1", 6379)
  if not ok then
      ngx.say("failed to connect: ", err)
      return
  end
  return red
end

local function SetKeepalive(red)
  local ok, err = red:set_keepalive(10000, 100)
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


function read:GetFilterIDsByTags(tags)

  local red = GetRedisConnection()
  red:init_pipeline()
  for k,v in pairs(tags) do
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

function read:GetAllTags()
  local red = GetRedisConnection()
  local ok, err = red:smembers('tags')
  if not ok then
    ngx.log(ngx.ERR, 'unable to load tags:',err)
    return {}
  end

  red:init_pipeline()
  for k,v in pairs(ok) do
    red:hgetall('tag:'..v)
  end
  local results, err = red:commit_pipeline(#ok)

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
  local ok, err = red:zrange('filters',startAt,endAt)

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

function read:GetFilterID(filterName)
  local red = GetRedisConnection()
  local ok, err = red:get('filterid:'..filterName)
  if not ok then
    ngx.log(ngx.ERR, 'unable to get filter id from name: ',err)
  end
  SetKeepalive(red)
  if ok == ngx.null then
    return {}
  else
    return ok
  end
end

function read:GetUserFilterIDs(username)

  local red = GetRedisConnection()

  local ok, err

  ok, err = red:smembers('userfilters:'..username)

  SetKeepalive(red)

  if not ok then
    ngx.log(ngx.ERR, 'error getting filter list for user "',username,'", error:',err)
    return {}
  end

  if ok == ngx.null then
    return {}
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

  local postTags,err = red:smembers('post:tagIDs:'..postID)
  if not postTags then
    ngx.log(ngx.ERR, 'unable to get post tags:',err)
  end
  if postTags == ngx.null then
    postTags = {}
  end


  post.tags = {}

  for k, tagName in pairs(postTags) do
    ok, err = red:hgetall('posttags:'..postID..':'..tagName)
    if not ok then
      ngx.log(ngx.ERR, 'unable to load posttags:',err)
    end

    if ok ~= ngx.null then
      tinsert(post.tags,self:ConvertListToTable(ok))
    end
  end

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
  local ok, err = red:zrange('filterpostsall:date',rangeStart,rangeEnd)
  SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to get new posts: ',err)
  end

  return ok ~= ngx.null and ok or {}
end

function read:GetAllFreshPosts(rangeStart,rangeEnd)
  local red = GetRedisConnection()
  local ok, err = red:zrange('filterpostsall:datescore',rangeStart,rangeEnd)
  SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to get fresh posts: ',err)
  end

  return ok ~= ngx.null and ok or {}
end

function read:GetAllBestPosts(rangeStart,rangeEnd)
  local red = GetRedisConnection()
  local ok, err = red:zrange('filterpostsall:score',rangeStart,rangeEnd)
  SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to get best posts: ',err)
  end

  return ok ~= ngx.null and ok or {}
end

function read:LoadFrontPageList(username,startTime, endTime)
  local filterIDs = self:GetUserFilterIDs(username)

  local red = GetRedisConnection()

  startAt = startAt or 0
  local postsByFilter = {}
  local ok, err

  for _, filterID in pairs(filterIDs) do

    ok, err = red:zrangebyscore('filterposts:date:'..filterID,endTime,startTime)

    postsByFilter[filterID] = postsByFilter[filterID] or {}
    if not ok then
      ngx.log(ngx.ERR,'unable to read filters posts: ',err)
    else
      if ok ~= ngx.null then
        for k,postID in pairs(ok)do
          tinsert(postsByFilter[filterID],postID)
        end
      end
    end
  end

  return postsByFilter

end

function read:BatchLoadPosts(posts)
  local red = GetRedisConnection()
  red:init_pipeline()
  for k,postID in pairs(posts) do
      red:hgetall('post:'..postID)
  end
  local results, err = red:commit_pipeline()
  if not results then
    ngx.log(ngx.ERR, 'unable batch get post info:', err)
  end
  local processedResults = {}

  for k,v in pairs(results) do
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
