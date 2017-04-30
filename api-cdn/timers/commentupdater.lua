
local CONFIG_CHECK_INTERVAL = 5

local config = {}
config.__index = config
config.http = require 'lib.http'
config.cjson = require 'cjson'

local redisRead = require 'api.redisread'
local redisWrite = require 'api.rediswrite'
local commentWrite = require 'api.commentwrite'
local commentRead = require 'api.commentread'
local commentAPI = require 'api.comments'
local userWrite = require 'api.userwrite'
local cache = require 'api.cache'
local tinsert = table.insert
local to_json = (require 'lapis.util').to_json
local from_json = (require 'lapis.util').from_json

function config:New(util)
  local c = setmetatable({},self)
  c.util = util
	math.randomseed(ngx.now()+ngx.worker.pid())
	math.random()

  return c
end


function config.Run(_,self)
  local ok, err = ngx.timer.at(CONFIG_CHECK_INTERVAL, self.Run, self)
  if not ok then
    if not err:find('process exiting') then
      ngx.log(ngx.ERR, 'WARNING: unable to reschedule postupdater: '..err)
    end
  end

  -- no need to lock since we should be grabbing a different one each time anyway
  self:UpdateCommentVotes()

end

function config:ConvertCommentVotes(jsonData)
  -- this also removes duplicates, using the newest only
  -- as they are already sorted old -> new by redis
  local commentVotes = {}
  local converted
  for _,v in pairs(jsonData) do
    converted = from_json(v)
    converted.json = v
    commentVotes[converted.id] = converted
  end
  return commentVotes
end

function config:ProcessCommentVote(commentVote)
  local comment = commentAPI:GetComment(commentVote.postID, commentVote.commentID)

  if commentAPI:UserHasVotedComment(commentVote.userID, commentVote.commentID) then
		return true
	end
  if commentVote.direction == 'up' then
		comment.up = comment.up + 1
	elseif commentVote.direction == 'down' then
		comment.down = comment.down + 1
	end

  comment.score = self.util:GetScore(comment.up, comment.down)

  local ok, err = userWrite:AddUserCommentVotes(commentVote.userID, commentVote.commentID)
  if not ok then
    return ok, err
  end

  if commentVote.direction == 'up' then
		ok, err = userWrite:IncrementUserStat(comment.createdBy, 'stat:commentvoteup',1)
	else
		ok, err = userWrite:IncrementUserStat(comment.createdBy, 'stat:commentvotedown',1)
	end
	if not ok then
		return ok, err
	end

	ok, err = commentWrite:CreateComment(comment)
  return ok, err

end

function config:UpdateCommentVotes()

  local ok,err = commentRead:GetOldestJobs('commentvote', 1000)
  if err then
    ngx.log(ngx.ERR, 'unable to get list of comment votes:' ,err)
    return
  end

  local commentVotes = self:ConvertCommentVotes(ok)

  -- now try and lock them
  for commentVoteID,commentVote in pairs(commentVotes) do
    ok, err = redisWrite:GetLock('L:CommentVote:'..commentVoteID,10)
    if err then
      ngx.log(ngx.ERR, 'unable to lock commentvote: ',err)
    elseif ok ~= ngx.null then

      ok, err = self:ProcessCommentVote(commentVote)
      if ok then
        commentWrite:RemoveJob()
        -- purge the comment from the cache
        -- dont remove lock, just to limit updates a bit
      else
        ngx.log(ngx.ERR, 'unable to process commentvote: ', err)
        redisWrite:RemLock('L:CommentVote:'..commentVoteID)
      end

    end
  end


end

return config
