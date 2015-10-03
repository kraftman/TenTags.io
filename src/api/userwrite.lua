
local userwrite = {}

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


function userwrite:ConvertListToTable(list)
  local info = {}
  for i = 1,#list, 2 do
    info[list[i]] = list[i+1]
  end
  return info
end

function userwrite:CreateUser(userInfo)
  local red = GetRedisConnection()
  local userFilters = userInfo.filters
  userInfo.filters = nil
  red:init_pipeline()
    red:hmset('user:'..userInfo.id,userInfo)
    for _,filterID in pairs(userFilters) do
      red:sadd('userfilters:'..userInfo.id,filterID)
    end
    red:hset('useremails',userInfo.email,userInfo.id)
  local results, err = red:commit_pipeline()
  SetKeepalive(red)
  if err then
    ngx.log(ngx.ERR, 'unable to create new user: ',err)
  end
end

function userwrite:ActivateAccount(userID)
  local red = GetRedisConnection()
  local ok, err = red:hset('user:'..userID,'active',1)
  SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to activate account:',err)
  end
end

return userwrite
