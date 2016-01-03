
local redis = require "resty.redis"
local from_json = (require 'lapis.util').from_json

local commentread = {}

local function GetRedisConnection()
  local red = redis:new()
  red:set_timeout(1000)
  local ok, err = red:connect("127.0.0.1", 6379)
  if not ok then
      ngx.say("failed to connect: ", err)
      return
  end
  red:select(1)
  return red
end

local function SetKeepalive(red)
  local ok, err = red:set_keepalive(10, 10)
  if not ok then
      ngx.say("failed to set keepalive: ", err)
      return
  end
end

function commentread:ConvertListToTable(list)
  local info = {}
  for i = 1,#list, 2 do
    info[list[i]] = list[i+1]
  end
  return info
end

function commentread:GetPostComments(postID)
  local red = GetRedisConnection()

  local ok, err = red:hgetall('postComment:'..postID)
  if not ok then
    ngx.log(ngx.ERR, 'unable to get post comments: ',err)
    return {}
  end

  if ok == ngx.null then
    return {}
  end

  return self:ConvertListToTable(ok)
end


function commentread:GetUserComments(postIDcommentIDs)
  -- split the postID and commentID apart
  -- pipelined the requsts

  local red = GetRedisConnection()
  local postID, commentID
  red:init_pipeline()
    for _,v in pairs(postIDcommentIDs) do
      ngx.log(ngx.ERR,v)
      postID, commentID = v:match('(%w+):(%w+)')
      red:hget('postComment:'..postID,commentID)
    end
  local res, err = red:commit_pipeline()
  SetKeepalive(red)
  if err then
    ngx.log(ngx.ERR, 'unable to get comments: ',err)
    return {}
  end

  return res
end



function commentread:GetComment(postID, commentID)
  local red = GetRedisConnection()
  local ok, err = red:hget('postComment:'..postID,commentID)
  if not ok then
    ngx.log(ngx.ERR, 'unable to get comment info: ',err)
    return nil
  end

  if ok == ngx.null then
    return nil
  else
    return from_json(ok)
  end

end

function commentread:GetCommentInfos(commentIDs)
  local red = GetRedisConnection()
  red:init_pipeline()
  for _,v in pairs(commentIDs) do
    red:hgetall('comments:'..v)
  end
  local res, err = red:commit_pipeline()
  if err then
    ngx.log(ngx.ERR, 'unable to get comments: ',err)
    return {}
  end


  local sorted = {}
  for k,v in pairs(res) do
    sorted[k] = self:ConvertListToTable(v)
  end

  return sorted

end



return commentread
