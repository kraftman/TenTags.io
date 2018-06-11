
local base = require 'redis.base'
local commentread = setmetatable({}, base)


function commentread:ConvertListToTable(list)
  local info = {}
  for i = 1,#list, 2 do
    info[list[i]] = list[i+1]
  end
  return info
end

function commentread:GetPostComments(postID)
  local red = self:GetCommentReadConnection()

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

  local red = self:GetCommentReadConnection()
  local postID, commentID
  red:init_pipeline()
    for _,v in pairs(postIDcommentIDs) do
      postID, commentID = v:match('(%w+):(%w+)')
      red:hget('postComment:'..postID,commentID)
    end
  local res, err = red:commit_pipeline()
  self:SetKeepalive(red)

  if err then
    ngx.log(ngx.ERR, 'unable to get comments: ',err)
    return {}
  end
  local realComments = {}
  for k,v in pairs(res) do
    if v ~= ngx.null then
      table.insert(realComments, v)
    end
  end

  return realComments
end


function commentread:GetOldestJobs(jobName, size)
   jobName = 'queue:'..jobName

  local red = self:GetRedisReadConnection()
  local ok, err = red:zrange(jobName, 0, size)
  self:SetKeepalive(red)

  if (not ok) or ok == ngx.null then
    return nil, err
  else
    return ok, err
  end
end

function commentread:GetComment(postID, commentID)
  print(postID, commentID)
  local red = self:GetCommentReadConnection()
  local ok, err = red:hget('postComment:'..postID,commentID)
  if not ok then
    ngx.log(ngx.ERR, 'unable to get comment info: ',err)
    return nil
  end

  if ok == ngx.null or not ok  then
    return nil
  else
    ok = self:from_json(ok)
    if not ok.viewID then
      ok.viewID = 'default'
    end
    return ok
  end

end

function commentread:GetCommentInfos(commentIDs)
  local red = self:GetCommentReadConnection()
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
