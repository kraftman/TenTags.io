
local CONFIG_CHECK_INTERVAL = 5

local config = {}
config.__index = config
config.http = require 'lib.http'

local commentAPI = require 'api.comments'
local cache = require 'api.cache'
local tinsert = table.insert
local from_json = (require 'lapis.util').from_json
local updateDict = ngx.shared.updateQueue


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
  --self:ProcessJob('commentvote', 'ProcessCommentVote')
  self:ProcessJob('commentsub', 'ProcessCommentSub')
  self:ProcessJob('CreateComment', 'CreateComment')


  self:GetNewComments()
  self:GetCommentEdits()
  self:GetCommentDeletions()
  self:GetCommentVotes()

end

function config:GetNewComments()
	local comment, err = updateDict:rpop('comment:create')
	if not comment then
		if err then
			ngx.log(ngx.ERR, err)
		end
		return
	end

	comment = from_json(comment)

	self:CreateComment(comment)
end

function config:GetCommentEdits()
  local comment, ok, err
	comment, err = updateDict:rpop('comment:edit')
	if not comment then
		if err then
			ngx.log(ngx.ERR, err)
		end
		return
	end

	comment = from_json(comment)

  ok, err = self.commentWrite:CreateComment(comment)
  if not ok then
    ngx.log(ngx.ERR, 'couldnt update comment: ', err)
  end

  ok, err = self.redisWrite:InvalidateKey('comment', comment.postID)
  if not ok then
    ngx.log(ngx.ERR, 'couldnt invalidate cache: ', err)
  end

end

function config:GetCommentDeletions()
  local comment, ok, err
  comment, err = updateDict:rpop('comment:delete')
	if not comment then
		if err then
			ngx.log(ngx.ERR, err)
		end
		return
	end

  comment = from_json(comment)

  ok, err = self.commentWrite:UpdateCommentField(comment.postID, comment.id, 'deleted', 'true')
  if not ok then
    ngx.log(ngx.ERR, 'unable to update comment: ', err)
  end

  ok , err = self.redisWrite:InvalidateKey('comment', comment.postID)
  if not ok then
    ngx.log(ngx.ERR, 'unable to flush comment: ', err)
  end

end

function config:GetCommentVotes()
  local commentVote, err = updateDict:rpop('comment:vote')
	if not commentVote then
		if err then
			ngx.log(ngx.ERR, err)
		end
		return
	end

  commentVote = from_json(commentVote)
  self:ProcessCommentVote(commentVote)

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

  local ok, err = self.userWrite:AddUserCommentVotes(commentVote.userID, commentVote.commentID)
  if not ok then
    return ok, err
  end

  if commentVote.direction == 'up' then
		ok, err = self.userWrite:IncrementUserStat(comment.createdBy, 'stat:commentvoteup',1)
	else
		ok, err = self.userWrite:IncrementUserStat(comment.createdBy, 'stat:commentvotedown',1)
	end
	if not ok then
		return ok, err
	end

  ok, err = self.userWrite:AddComment(comment)
  if not ok then
    return ok, err
  end

	ok, err = self.commentWrite:CreateComment(comment)
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

  return self.commentWrite:CreateComment(comment)
end



function config:UpdateFilters(post, comment)
  local filters = {}

  local postFilters = post.filters

  local userFilters = cache:GetViewFilterIDs(comment.viewID)

	-- get shared filters between user and post
  for _,userFilterID in pairs(userFilters) do
    for _,postFilterID in pairs(postFilters) do
      if userFilterID == postFilterID then
        tinsert(filters, userFilterID)
      end
    end
  end

  return filters
end

function config:AddAlerts(post, comment)
  --tell all the users that care that the comment they are watchin has a new reply

  -- need to add alert to all parent comment viewers
  local parentComment, ok, err, viewer
  if comment.parentID == comment.postID then
    parentComment = post
  else
    parentComment = self.commentRead:GetComment(comment.postID, comment.parentID)
  end

  -- alert anyone subscribed to the post
  for _,viewerID in pairs(post.viewers) do
    viewer = cache:GetUser(viewerID)
    local blocked
    -- check they arent blocked
    for _,v in pairs(viewer.blockedUsers) do
      if comment.createdBy == v then
        blocked = true
        break
      end
    end

    if not blocked then
      cache:PurgeKey({keyType = 'useralert', id = viewerID})
      ok, err = self.redisWrite:InvalidateKey('useralert', viewerID)
      self.userWrite:AddUserAlert(comment.createdAt, viewerID, 'postComment:'..comment.postID..':'..comment.id)
    end
  end

  -- alert anyone subscribed to the user
  local user = cache:GetUser(post.createdBy)
  if not user then
    return true
  end

  -- if they are subscribed to them lets assume they havent blocked them
  for subscriberID, _ in pairs(user.commentSubscribers) do
    print('alerting subscriber: ',subscriberID)
    self.userWrite:AddUserAlert(comment.createdAt, subscriberID, 'postComment:'..comment.postID..':'..comment.id)
    cache:PurgeKey({keyType = 'useralert', id = subscriberID})
    ok, err = self.redisWrite:InvalidateKey('useralert', subscriberID)
  end

  return true

end

function config:CreateComment(comment)

  local ok, err

  if not comment then
    return true, 'comment not found'
  end
  local post = cache:GetPost(comment.postID)
  if not post then
    return nil, 'no parent post for comment: ', comment.id, ' postID: ', comment.postID
  end


  ok, err = self.commentWrite:CreateComment(comment)
  if not ok then
    ngx.log(ngx.ERR, 'unable to create comment in commentupdater: ', err)
    return ok, err
  end

  -- add stats, but dont return if they fail
	ok, err = self.userWrite:IncrementUserStat(comment.createdBy, 'CommentsCreated', 1)
	if not ok then
		ngx.log(ngx.ERR, 'unable to add stat: ', err)
	end

	self.redisWrite:IncrementSiteStat('CommentsCreated', 1)
	if not ok then
		ngx.log(ngx.ERR, 'unable to add stat')
	end

  ok, err = self.redisWrite:QueueJob('AddCommentShortURL',{id = comment.postID..':'..comment.id})
  if not ok then
    return ok, err
  end

  ok, err = self.userWrite:AddComment(comment)
  if not ok then
    return ok, err
  end

  ok, err = self:UpdateFilters(post, comment)
  if not ok then
    print('error getting filters: ', err)
    return nil, err
  else
    comment.filters = ok
  end


  if not ok then
    ngx.log(ngx.ERR, 'unable to create comment: ', err)
  end

  self:AddAlerts(post, comment)
  cache:PurgeKey {keyType = 'comment', id = post.id}

	ok , err = self.redisWrite:InvalidateKey('comment', post.id)
	if not ok then
		print('error invalidating key: ', err)
	end

  ok, err = self.redisWrite:IncrementPostStat(comment.postID, 'commentCount',1)
  if not ok then
    ngx.log(ngx.ERR, 'unable to incr post field: ', err)
  end


  cache:PurgeKey {keyType = 'post', id = post.id}

  ok, err = self.redisWrite:InvalidateKey('post', post.id)
  if not ok then
    ngx.log(ngx.ERR, 'unable to invalidatekey: ', err)
  end
  return true

end




return config
