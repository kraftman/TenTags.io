
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
local userAPI = require 'api.users'
local userWrite = require 'api.userwrite'
local cache = require 'api.cache'
local tinsert = table.insert


local common = require 'timers.common'
setmetatable(config, common)

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
  self.startTime = ngx.now()
  self:ProcessJob('commentvote', 'ProcessCommentVote')
  self:ProcessJob('commentsub', 'ProcessCommentSub')
  self:ProcessJob('CreateComment', 'CreateComment')

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

  ok, err = userWrite:AddComment(comment)
  if not ok then
    return ok, err
  end

	ok, err = commentWrite:CreateComment(comment)
  return ok, err

end



function config:ProcessCommentSub(commentSub)

  local comment = cache:GetComment(commentSub.postID, commentSub.commentID)
  -- check they dont exist
  for _, v in pairs(comment.viewers) do
    if v == commentSub.userID then
      if commentSub.action == 'sub' then
        return true
      end
    end
  end

  if commentSub.action == 'sub' then
    tinsert(comment.viewers, commentSub.userID)
  elseif commentSub.action == 'unsub' then
    for i = #comment.viewers, 1, -1 do
      if comment.viewers[i] == commentSub.userID then
        comment.viewers[i] = nil
      end
    end
  end

  return commentWrite:CreateComment(comment)
end



function config:UpdateFilters(post, comment)
  local filters = {}

  local postFilters = post.filters

  local userFilters = userAPI:GetUserFilters(comment.createdBy)

	-- get shared filters between user and post
  for _,userFilter in pairs(userFilters) do
    for _,postFilterID in pairs(postFilters) do
      if userFilter.id == postFilterID then
        tinsert(filters, userFilter)
      end
    end
  end

  return filters
end

function config:AddAlerts(post, comment)
  --tell all the users that care that the comment they are watchin has a new reply

  -- need to add alert to all parent comment viewers
  if comment.parentID == comment.postID then
		for _,viewerID in pairs(post.viewers) do
			userWrite:AddUserAlert(viewerID, 'postComment:'..comment.postID..':'..comment.id)
		end
  else
    local parentComment = self:GetComment(comment.postID, comment.parentID)
    for _,viewerID in pairs(parentComment.viewers) do
      userWrite:AddUserAlert(viewerID, 'postComment:'..comment.postID..':'..comment.id)
    end
  end

  return true

end

function config:CreateComment(commentInfo)
  print('creating comment')
  local ok, err
  local comment = cache:GetComment(commentInfo.postID, commentInfo.commentID)
  local post = cache:GetPost(comment.postID)
  if not post then
    return nil, 'no parent post for comment: ', comment.commentID, ' postID: ', commentInfo.postID
  end

  ok, err = redisWrite:QueueJob('AddCommentShortURL',{id = commentInfo.postID..':'..commentInfo.id})
  if not ok then
    return ok, err
  end
  print('adding comment to user')
  ok, err = userWrite:AddComment(comment)
  if not ok then
    return ok, err
  end



  ok, err = self:UpdateFilters(post, comment)
  if not ok then
    return ok, err
  else
    comment.filters = ok
  end

  self:AddAlerts(post, comment)


  redisWrite:UpdatePostField(comment.postID, 'commentCount',post.commentCount+1)

  return true

end




return config
