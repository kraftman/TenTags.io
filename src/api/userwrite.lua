
local userwrite = {}

local redis = require 'resty.redis'
local to_json = (require 'lapis.util').to_json
local tinsert = table.insert
local addKey = require 'redisscripts.addkey'

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
  local ok, err = red:set_keepalive(10000, 200)
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

function userwrite:AddComment(commentInfo)
  local red = GetRedisConnection()
  local ok, err = red:zadd('userComments:'..commentInfo.createdBy, commentInfo.createdAt, commentInfo.postID..':'..commentInfo.id)
  if not ok then
    ngx.log(ngx.ERR, 'unable to add comment: ', err)
  end
end

function userwrite:CreateMasterUser(masterInfo)
  local red = GetRedisConnection()
  local ok, err = red:hmset('master:'..masterInfo.kv.id,masterInfo.kv)
  if not ok then
    ngx.log(ngx.ERR, 'unable to create master info:',err)
    return false
  end

  red:hset('useremails',masterInfo.kv.email,masterInfo.kv.id)

  for k, v in pairs(masterInfo.users) do
    ok, err = red:sadd('masterusers:'..masterInfo.kv.id, v)
  end

end

function userwrite:AddSeenPosts(userID,seenPosts)
  local red = GetRedisConnection()
  local addKeySHA1 = addKey:GetSHA1()

  red:init_pipeline()
    for k,postID in pairs(seenPosts) do
      red:evalsha(addKeySHA1,0,userID,10000,0.01,postID)
      red:zadd('userSeen:'..userID,ngx.time(),postID)
    end
  local res,err = red:commit_pipeline()
  SetKeepalive(red)
  if err then
    ngx.log(ngx.ERR, 'unable to add seen post: ',err)
    return nil
  end
  return true
end

function userwrite:CreateUser(userInfo)
  local red = GetRedisConnection()
  ngx.log(ngx.ERR, to_json(userInfo.filters))

  red:init_pipeline()
    red:hmset('user:'..userInfo.kv.id,userInfo.kv)
    for _,filterID in pairs(userInfo.filters) do
      red:sadd('userfilters:'..userInfo.kv.id,filterID)
    end
    red:hset('userToID',userInfo.kv.username,userInfo.kv.id)
  local results, err = red:commit_pipeline()

  SetKeepalive(red)
  if err then
    ngx.log(ngx.ERR, 'unable to create new user: ',err)
  end
end

function userwrite:ActivateAccount(userID)
  local red = GetRedisConnection()
  local ok, err = red:hset('master:'..userID,'active',1)
  SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to activate account:',err)
  end
end

function userwrite:SubscribeToFilter(userID,filterID)
  local userID = userID or 'default'
  local red = GetRedisConnection()
  local ok, err = red:sadd('userfilters:'..userID, filterID)

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

function userwrite:UnsubscribeFromFilter(userID, filterID)
  local red = GetRedisConnection()
  local ok, err = red:srem('userfilters:'..userID,filterID)
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

return userwrite
