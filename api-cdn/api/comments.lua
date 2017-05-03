
local uuid = require 'lib.uuid'
local cache = require 'api.cache'
local util = require 'api.util'
local commentWrite = require 'api.commentwrite'
local redisWrite = require 'api.rediswrite'

local api = {}

local COMMENT_START_DOWNVOTES = 0
local COMMENT_START_UPVOTES = 1
local COMMENT_LENGTH_LIMIT = 2000


function api:VoteComment(userID, postID, commentID,direction)

	local ok, err = util.RateLimit('VoteComment:', userID, 5, 10)
	if not ok then
		return ok, err
	end

	if self:UserHasVotedComment(userID, commentID) then
		return nil, 'cannot vote more than once!'
	end

	local commentVote = {
		userID = userID,
		postID = postID,
		commentID = commentID,
		direction = direction,
		id = userID..':'..commentID
	}

	return commentWrite:QueueJob('commentvote', commentVote)

end

function api:ConvertUserCommentToComment(userID, comment)

	comment.createdBy = comment.createdBy or userID
	if comment.createdBy ~= userID then
		local user = cache:GetUser(userID)
		if user.role ~= 'Admin' then
			return nil, 'you cannot create a comment on behalf of someone else'
		end
	end

	local newComment = {
		id = uuid.generate_random(),
		createdAt = ngx.time(),
		createdBy = util:SanitiseUserInput(comment.createdBy),
		up = COMMENT_START_UPVOTES,
		down = COMMENT_START_DOWNVOTES,
		score = util:GetScore(COMMENT_START_UPVOTES,COMMENT_START_DOWNVOTES),
		viewers = {comment.createdBy},
		text = util:SanitiseUserInput(comment.text, COMMENT_LENGTH_LIMIT),
		parentID = util:SanitiseUserInput(comment.parentID),
		postID = util:SanitiseUserInput(comment.postID)
	}

	return newComment
end

function api:SubscribeComment(userID, postID, commentID)

	local ok, err = util.RateLimit('SubscribeComment:', userID, 3, 10)
	if not ok then
		return ok, err
	end

	local commentSub = {
		userID = userID,
		postID = postID,
		commentID = commentID,
		action = 'sub',
		id = userID..':'..commentID
	}

	return commentWrite:QueueJob('commentsub', commentSub)

end


function api:EditComment(userID, userComment)
	-- not moving this to backend for now
	-- fairly low cost and users want immediate updates
	local ok, err = util.RateLimit('EditComment:', userID, 4, 120)
	if not ok then
		return ok, err
	end

	if not userComment or not userComment.id or not userComment.postID then
		return nil, 'invalid comment provided'
	end

	local comment = cache:GetComment(userComment.postID, userComment.id)
	if not comment then
		return nil, 'comment not found'
	end

	if comment.createdBy ~= userID then
		local user = cache:GetUser(userID)
		if not user or user.role ~= 'Admin' then
			return nil, 'you cannot edit other users comments'
		end
	end


	comment.text = util:SanitiseUserInput(userComment.text,2000)
	comment.editedAt = ngx.time()

  ok, err = commentWrite:CreateComment(comment)
  if not ok then
    return ok, err
  end

  return true

end

function api:CreateComment(userID, userComment)

		local ok, err = util:RateLimit('CreateComment:', userID, 1, 30)
		if not ok then
			return ok, err
		end

		local newComment = api:ConvertUserCommentToComment(userID, userComment)

		local parentPost = cache:GetPost(newComment.postID)
		if not parentPost then
			return nil, 'could not find parent post'
		end

		ok, err = commentWrite:CreateComment(newComment)
		if not ok then
			ngx.log(ngx.ERR, 'unable to create comment: ', err)
			return nil, 'error creating comment'
		end

		local commentUpdate = {
			id = newComment.postID..':'..newComment.id,
			postID = newComment.postID,
			commentID = newComment.id,
			userID = userID
		}

		-- queue the rest
		ok, err = redisWrite:QueueJob('CreateComment', commentUpdate)
		if not ok then
			ngx.log(ngx.ERR, 'unable to queue comment create: ', err)
			return nil, 'error creating comment'
		end

		return true

end

function api:GetComment(postID, commentID)
	if not postID then
		return nil, 'no postID or commentURL'
	end
	if not commentID then
	 	local postIDCommentID = cache:ConvertShortURL(postID)
		postID, commentID = postIDCommentID:match('(%w+):(%w+)')
		if (not postID) or (not commentID) then
			return nil, 'error getting url'
		end
	end

  return cache:GetComment(postID, commentID)
end


function api:UserHasVotedComment(userID, commentID)
	-- can only see own
	local userCommentVotes = cache:GetUserCommentVotes(userID)
	return userCommentVotes[commentID]
end



function api:GetUserComments(userID, targetUserID)
	-- check if they allow it
	local targetUser = cache:GetUser(targetUserID)
	if not targetUser then
		return nil, 'could not find user by ID '..targetUserID
	end

	if targetUser.hideComments then
		local user = cache:GetUser(userID)
		if not user.role == 'Admin' then
			return nil, 'user has disabled comment viewing'
		end
	end

  local comments = cache:GetUserComments(targetUserID)
  return comments
end

function api:DeleteComment(userID, postID, commentID)

	local ok, err = util.RateLimit('DeleteComment:', userID, 6, 60)
	if not ok then
		return ok, err
	end

	local post = cache:GetPost(postID)
	if userID ~= post.createdBy then
		local user = cache:GetUser(userID)
		if user.role ~= 'Admin' then
			return nil, 'cannot delete other users posts'
		end
	end

	local comment = cache:GetComment(postID, commentID)
	if not comment then
		return nil, 'error loading comment'
	end
	comment.deleted = 'true'
	return commentWrite:UpdateComment(comment)

end


function api:GetPostComments(userID, postID,sortBy)
	local comments = cache:GetSortedComments(userID, postID,sortBy)


	return comments
end


return api
