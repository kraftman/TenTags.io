

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

function write:CreateFilter(filterInfo)
  local requiredTags = filterInfo.requiredTags
  local bannedTags = filterInfo.bannedTags
  filterInfo.bannedTags = nil
  filterInfo.requiredTags = nil

  -- add id to name conversion table
  local red = GetRedisConnection()
  local ok, err = red:set('filterid:'..filterInfo.name,filterInfo.id)
  if not ok then
    ngx.log(ngx.ERR, 'unable to add filter id, err: ',err)
  end

  -- add to list ranked by subs
  local ok, err = red:zadd('filtersubs',filterInfo.subs, filterInfo.id)

  -- add to list of filters
  local ok, err = red:zadd('filters',filterInfo.createdAt,filterInfo.id)
  if not ok then
    ngx.log(ngx.ERR, 'unable to add filter to sorted set:',err)
  end
  -- add all filter info
  ok, err = red:hmset('filter:'..filterInfo.id, filterInfo)
  if not ok then
    ngx.log(ngx.ERR, 'unablet to add filter info: ',err)
  end

  -- add list of required tags
  for k, v in pairs(requiredTags) do
    ok, err = red:sadd('filter:requiredtags:'..filterInfo.id,v)
    if not ok then
      ngx.log(ngx.ERR, 'unable to add required tags: ',err)
    end
  end

  -- add list of banned tags
  for k, v in pairs(bannedTags) do
    ok, err = red:sadd('filter:bannedtags:'..filterInfo.id,v)
    if not ok then
      ngx.log(ngx.ERR, 'unable to add banned tags: ',err)
    end
  end
end



function write:ConvertListToTable(list)
  local info = {}
  for i = 1,#list, 2 do
    info[list[i]] = list[i+1]
  end
  return info
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
  local tagNames = {}

  for k,tag in pairs(tags) do
    tinsert(tagNames,tag.name)
    local ok, err = red:hmset('posttags:'..postInfo.id..':'..tag.name,tag)
  end

  local ok, err = red:sadd('post:tags:'..postInfo.id,unpack(tagNames))
  local ok, err = red:hmset('post:'..postInfo.id,postInfo)
  if not ok then
    ngx.log(ngx.ERR, 'unable to create post:',err)
  end
  local ok, err = red:zadd('posts',postInfo.createdAt,postInfo.id)

  -- find filters that want the tags
  -- find filters that dont want the tags
  -- subtract 2nd set from first


  SetKeepalive(red)
end


return write
