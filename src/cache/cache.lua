


local redis = require "resty.redis"

local M = {}


local util = require("lapis.util")


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


function M:LoadFilterList(username)

  local red = GetRedisConnection()
  local ok, err = red:smembers('filterlist:'..username)
  SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'error getting filter list for user "',username,'", error:',err)
    return
  end

  if ok == ngx.null then
    return {}
  else
    return ok
  end
end

function M:LoadFilterPosts(filterList,startAt,endAt)
    startAt = startAt or 0
    local red = GetRedisConnection()
    red:init_pipeline()
    for k, v in pairs(filterList) do
      red:zrange(v..':score',startAt,endAt)
    end
    local results, err = red:commit_pipeline()

    if not results then
      ngx.log(ngx.ERR, 'error getting posts for filters:',err)
      return {}
    end

    return results

end

function M:BatchLoadPosts(posts)
  local red = GetRedisConnection()
  red:init_pipeline()
  for k,postID in pairs(posts) do
      red:hgetall(postID)
  end
  local results, err = red:commit_pipeline()
  if not results then
    ngx.log(ngx.ERR, 'unable batch get post info:', err)
  end
  return results
end



return M
