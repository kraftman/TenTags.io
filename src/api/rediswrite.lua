

local write = {}

local redis = require 'resty.redis'
local to_json = (require 'lapis.util').to_json
local tinsert = table.insert

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


function write:ConvertListToTable(list)
  local info = {}
  for i = 1,#list, 2 do
    info[list[i]] = list[i+1]
  end
  return info
end

function write:CreateFilter(filterInfo)
  local requiredTags = filterInfo.requiredTags
  local bannedTags = filterInfo.bannedTags
  filterInfo.bannedTags = nil
  filterInfo.requiredTags = nil

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

  -- add list of required tags
  for k, tagInfo in pairs(requiredTags) do
    red:sadd('filter:requiredtags:'..filterInfo.id,tagInfo.id)
  end

  -- add list of banned tags
  for k, tagInfo in pairs(bannedTags) do
    red:sadd('filter:bannedtags:'..filterInfo.id,tagInfo.id)
  end

  -- add filter to required tag
  for k, tagInfo in pairs(requiredTags) do
    red:hset('tag:filters:'..tagInfo.id,filterInfo.id,'required')
  end
  -- add filter to banned tag
  for k, tagInfo in pairs(bannedTags) do
    red:hset('tag:filters:'..tagInfo.id,filterInfo.id,'banned')
  end
  local results, err = red:commit_pipeline()
  if err then
    ngx.log(ngx.ERR, 'unable to add filter to redis: ',err)
  end
end

function write:AddPostToFilters(filters,postInfo)
  -- add post to the filters that want it
  -- by post score, and by date
  local red = GetRedisConnection()
    red:init_pipeline()
    for _, filterInfo in pairs(filters) do
      red:zadd('filterposts:date:'..filterInfo.id,postInfo.createdAt,postInfo.id)
      red:zadd('filterposts:score:'..filterInfo.id,postInfo.score,postInfo.id)
    end
  local results, err = red:commit_pipeline()

  if err then
    ngx.log(ngx.ERR, 'unable to add posts to filters: ',err)
  end
  return
end



function write:SubscribeToFilter(username,filterID)
  local red = GetRedisConnection()
  local ok, err = red:sadd('filterlist:'..username, filterID)

  if not ok then
    SetKeepalive(red)
    ngx.log(ngx.ERR, 'unable to add filter to list: ',err)
    return
  end

  ok, err = red:hincrby('filter:'..filterID,'subs',1)
  SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to incr subs: ',err)
  end

end

function write:UnsubscribeFromFilter(username, filterID)
  local red = GetRedisConnection()
  local ok, err = red:srem('filterlist:'..username,filterID)
  if not ok then
    SetKeepalive(red)
    ngx.log(ngx.ERR, 'unable to remove filter from users list:',err)
    return
  end

  ok, err = red:hincrby('filter:'..filterID,'subs',-1)
  SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to incr subs: ',err)
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

function write:CreatePost(postInfo)
  local red = GetRedisConnection()
  local tags = postInfo.tags
  postInfo.tags = nil
  local tagIDs = {}

  red:init_pipeline()
    for k,tag in pairs(tags) do
      tinsert(tagIDs,tag.id)
      red:hmset('posttags:'..postInfo.id..':'..tag.id,tag)
    end
    -- add to /f/all
    red:zadd('allposts:score',postInfo.score,postInfo.id)
    red:zadd('allposts:date',postInfo.createdAt,postInfo.id)

    -- add post info
    red:hmset('post:'..postInfo.id,postInfo)


    local results,err = red:commit_pipeline()
    if err then
      ngx.log(ngx.ERR, 'unable to create post:',err)
    end

  SetKeepalive(red)
end


return write
