

local base = require 'redis.base'
local commentwrite = setmetatable({}, base)


function commentwrite:ConvertListToTable(list)
  local info = {}
  for i = 1,#list, 2 do
    info[list[i]] = list[i+1]
  end
  return info
end

function commentwrite:UpdateCommentField(postID,commentID,field,newValue)
  --print(postID, commentID)
  --get the comment, update, rediswrite
  local red = self:GetCommentWriteConnection()
  local ok, err = red:hget('postComment:'..postID,commentID)
  if err then
    ngx.log(ngx.ERR, 'error getting comment: ',err)
    return ok, err
  end

  local comment  = self:from_json(ok)
  comment[field] = newValue
  local serialComment = self:to_json(comment)

  ok, err = red:hmset('postComment:'..comment.postID,comment.id,serialComment)
  self:SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to write comment info: ',err)
    return false
  end
  return true
end

function commentwrite:LoadScript(script)
  local red = self:GetCommentWriteConnection()
  local ok, err = red:script('load',script)
  if not ok then
    ngx.log(ngx.ERR, 'unable to add script to redis:',err)
    return nil
  else
    ngx.log(ngx.ERR, 'added script to redis: ',ok)
  end

  return ok
end


function commentwrite:CreateComment(commentInfo)

  local red = self:GetCommentWriteConnection()
  local serialComment = self:to_json(commentInfo)

  local ok, err = red:hmset('postComment:'..commentInfo.postID,commentInfo.id,serialComment)
  self:SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to write comment info: ',err)
    return false, err
  end
  return true
end


return commentwrite
