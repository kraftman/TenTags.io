

local redis = require "resty.redis"
local to_json = (require 'lapis.util').to_json
local from_json = (require 'lapis.util').from_json
local util = require 'util'
local commentwrite = {}


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
  local red = util:GetCommentWriteConnection()
  local ok, err = red:hget('postComment:'..postID,commentID)
  if err then
    ngx.log(ngx.ERR, 'error getting comment: ',err)
    return ok, err
  end

  local comment  = from_json(ok)
  comment[field] = newValue
  local serialComment = to_json(comment)

  ok, err = red:hmset('postComment:'..comment.postID,comment.id,serialComment)
  util:SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to write comment info: ',err)
    return false
  end
  return true
end

function commentwrite:LoadScript(script)
  local red = util:GetCommentWriteConnection()
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

  local red = util:GetCommentWriteConnection()
  local serialComment = to_json(commentInfo)
  print('creating comment: ',commentInfo.postID,commentInfo.id)
  local ok, err = red:hmset('postComment:'..commentInfo.postID,commentInfo.id,serialComment)
  util:SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to write comment info: ',err)
    return false, err
  end
  return true
end


return commentwrite
