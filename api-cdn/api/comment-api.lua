
local cache = require 'api.cache'
local util = require 'util'
local api = {}
local tinsert = table.insert


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
		createdBy = self:SanitiseUserInput(comment.createdBy),
		up = COMMENT_START_UPVOTES,
		down = COMMENT_START_DOWNVOTES,
		score = self:GetScore(COMMENT_START_UPVOTES,COMMENT_START_DOWNVOTES),
		viewers = {comment.createdBy},
		text = self:SanitiseUserInput(comment.text, COMMENT_LENGTH_LIMIT),
		parentID = self:SanitiseUserInput(comment.parentID),
		postID = self:SanitiseUserInput(comment.postID)
	}

	return newComment
end


function api:EditComment(userID, userComment)
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

	comment.text = self:SanitiseUserInput(userComment.text,2000)
	comment.editedAt = ngx.time()

	ok, err = worker:CreateComment(comment)

	return ok, err

	-- dont change post comment count

end

function api:CreateComment(userID, userComment)
	-- check if they are who they say they are

	local ok, err = util.RateLimit('CreateComment:', userID, 1, 30)
	if not ok then
		return ok, err
	end

	local newComment = api:ConvertUserCommentToComment(userID, userComment)


  local filters = {}
	local parentPost = cache:GetPost(newComment.postID)
	if not parentPost then
		return nil, 'could not find parent post'
	end


  local postFilters = parentPost.filters

  local userFilters = self:GetUserFilters(newComment.createdBy)

	-- get shared filters between user and post
  for _,userFilter in pairs(userFilters) do
    for _,postFilterID in pairs(postFilters) do
      if userFilter.id == postFilterID then
        tinsert(filters, userFilter)
      end
    end
  end

  newComment.filters = filters

  ok, err = worker:CreateComment(newComment)
	if not ok then
		return ok, err
	end

  -- need to add alert to all parent comment viewers
  if newComment.parentID == newComment.postID then
    local post = cache:GetPost(newComment.postID)
		if post then
			for _,viewerID in pairs(post.viewers) do
				worker:AddUserAlert(viewerID, 'postComment:'..newComment.postID..':'..newComment.id)
			end
		end
  else
    local parentComment = self:GetComment(newComment.postID, newComment.parentID)
    for _,viewerID in pairs(parentComment.viewers) do
      worker:AddUserAlert(viewerID, 'postComment:'..newComment.postID..':'..newComment.id)
    end
  end

	local post = cache:GetPost(newComment.postID)

	worker:UpdatePostField(newComment.postID, 'commentCount',post.commentCount+1)


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

	local ok, err = util.RateLimit('DeleteComment:', userID, 1, 60)
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
	return worker:CreateComment(comment)

end


function api:GetPostComments(userID, postID,sortBy)
	local comments = cache:GetSortedComments(userID, postID,sortBy)


	return comments
end


return api
