

local redis = require "resty.redis"
local to_json = (require 'lapis.util').to_json

local commentwrite = {}

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

function commentwrite:ConvertListToTable(list)
  local info = {}
  for i = 1,#list, 2 do
    info[list[i]] = list[i+1]
  end
  return info
end

function commentwrite:CreateComment(commentInfo)

  local red = GetRedisConnection()
  local serialComment = to_json(commentInfo)
  local ok, err = red:hmset('postComment:'..commentInfo.postID,commentInfo.id,serialComment)
  SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to write comment info: ',err)
    return false
  end
  return true
end


return commentwrite
