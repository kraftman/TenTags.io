

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

function write:FlushAllPosts()
  local red = GetRedisConnection()

  --get all post ids
  --for each post
  -- remove the post from each of the subs it belongs to
  -- remove the post from the global list

  red:init_pipeline()

  local res, err = red:commit_pipeline()


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
    ngx.log(ngx.ERR,to_json(tagInfo))
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
      red:zadd('filterposts:datescore:'..filterInfo.id,postInfo.createdAt + postInfo.score,postInfo.id)
      red:zadd('filterpostsall:datescore',postInfo.createdAt + postInfo.score,filterInfo.id..':'..postInfo.id)
      red:zadd('filterpostsall:date',postInfo.createdAt,filterInfo.id..':'..postInfo.id)
      red:zadd('filterpostsall:score',postInfo.createdAt,filterInfo.id..':'..postInfo.id)
  end
  local results, err = red:commit_pipeline()

  if err then
    ngx.log(ngx.ERR, 'unable to add posts to filters: ',err)
  end
  return
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
  local filters = postInfo.filters
  postInfo.filters = nil

  red:init_pipeline()
    -- add all filters that the post has
    red:sadd('postfilters:'..postInfo.id,filters)
    -- collect tag ids and add taginfo to hash
    for k,tag in pairs(tags) do

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
end


return write
