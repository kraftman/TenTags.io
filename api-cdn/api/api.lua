--[[
  access control
  rate limitting
  business logic
]]

local cache = require 'api.cache'
local api = {}
local uuid = require 'lib.uuid'
local worker = require 'api.worker'
local tinsert = table.insert
local trim = (require 'lapis.util').trim
local scrypt = require 'lib.scrypt'
local salt = 'poopants'
--local to_json = (require 'lapis.util').to_json
--local magick = require 'magick'
local http = require 'lib.http'
local rateDict = ngx.shared.ratelimit
--arbitrary, needs adressing later
local TAG_BOUNDARY = 0.15
local TAG_START_DOWNVOTES = 0
local TAG_START_UPVOTES = 1
local COMMENT_START_DOWNVOTES = 0
local COMMENT_START_UPVOTES = 1
local COMMENT_LENGTH_LIMIT = 2000
local POST_TITLE_LENGTH = 300
local UNLIMITED_VOTING = true
local SOURCE_POST_THRESHOLD = 0.75
--local permission = require 'userpermission'

local ENABLE_RATELIMIT = false
local MAX_ALLOWED_TAG_COUNT = 20
local MAX_MOD_COUNT = 3
local RATELIMIT_ENABLED = false

local function AverageTagScore(filterRequiredTagIDs,postTags)

	local score = 0
	local count = 0

  for _,filterTagID in pairs(filterRequiredTagIDs) do
    for _,postTag in pairs(postTags) do
      if filterTagID == postTag.id then
				if (not postTag.name:find('^meta:')) and
					(not postTag.name:find('^source:')) and
					postTag.score > TAG_BOUNDARY then
	        	score = score + postTag.score
						count = count + 1
				end
      end
    end
  end

	if count == 0 then
		return 0
	end

	return score / count
end

local function RateLimit(action, userID, limit, duration)
	if not RATELIMIT_ENABLED then
		return true
	end

	if not userID then
		return nil, 'you must be logged in to do that'
	end
	local key = action..userID
	if not ENABLE_RATELIMIT then
		return true
	end

	local ok, err = rateDict:get(key)
	if err then
		ngx.log(ngx.ERR, 'error getting rate limit key ',key)
	end

	if not ok then
		rateDict:set(key, 0, duration)
	end

	rateDict:incr(key,1)

	if not ok then
		return true
	end

	if ok <= limit then
		return ok
	else
		return nil, 429
	end

end


local function SanitiseHTML(str)
	local html = {
		["<"] = "&lt;",
		[">"] = "&gt;",
		["&"] = "&amp;",
	}
	return string.gsub(tostring(str), "[<>&]", function(char)
		return html[char] or char
	end)
end

function api:DeleteComment(userID, postID, commentID)

	local ok, err = RateLimit('DeleteComment:', userID, 1, 60)
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

function api:LabelUser(userID, targetUserID, label)

	local ok, err = RateLimit('UpdateUser:',userID, 1, 60)
	if not ok then
		return ok, err
	end

	ok, err = worker:LabelUser(userID, targetUserID, label)
	return ok, err

end

function api:UpdateUser(userID, userToUpdate)

	local ok, err = RateLimit('UpdateUser:',userID, 3, 30)
	if not ok then
		return ok, err
	end

	if userID ~= userToUpdate.id then
		local user = cache:GetUser(userID)
		if user.role ~= 'Admin' then
			return nil, 'you must be admin to edit a users details'
		end
	end
	print('HIDING SEEN POSTS: ',userToUpdate.hideSeenPosts)
	local userInfo = {
		id = userToUpdate.id,
		enablePM = userToUpdate.enablePM and 1 or 0,
		hideSeenPosts = tonumber(userToUpdate.hideSeenPosts) == 0 and 0 or 1,
		hideVotedPosts = tonumber(userToUpdate.hideVotedPosts) == 0 and 0 or 1,
		hideClickedPosts = tonumber(userToUpdate.hideClickedPosts) == 0 and 0 or 1,
		showNSFW = tonumber(userToUpdate.showNSFW) == 0 and 0 or 1,
		username = userToUpdate.username
	}


	print('HIDING SEEN POSTS: ',userInfo.hideSeenPosts)

	for k,v in pairs(userToUpdate) do
		if k:find('^filterStyle:') then
			k = k:sub(1,100)
			userInfo[k] = v:sub(1,100)
		end
	end

	return worker:UpdateUser(userInfo)
end

function api:GetFilters(filterIDs)
	local filters = {}
	for k,v in pairs(filterIDs) do
		table.insert(filters, cache:GetFilterByID(v))
	end
	return filters
end


function api:GetUserFilters(userID)
	-- can only get your own filters
  if not userID then
    userID = 'default'
  end
  local filterIDs = cache:GetUserFilterIDs(userID)
	--print(to_json(filterIDs))
	local filters = cache:GetFilterInfo(filterIDs)
	--print(to_json(filters))
	return filters
end

function api:ConvertShortURL(shortURL)
	return cache:ConvertShortURL(shortURL)
end


function api:GetFilterInfo(filterIDs)
	return cache:GetFilterInfo(filterIDs)
end

function api:GetPostComments(userID, postID,sortBy)
	local comments = cache:GetSortedComments(userID, postID,sortBy)


	return comments
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

function api:GetThread(threadID)
  return cache:GetThread(threadID)
end

function api:UserHasAlerts(userID)
	--can only get your own alerts
  local alerts = cache:GetUserAlerts(userID)
  return #alerts > 0
end

function api:UserCanEditFilter(userID, filterID)
	local user = cache:GetUser(userID)

	if not user then
		return nil, 'userID not found'
	end

	if user.role == 'Admin' then
		return true
	end

	local filter = cache:GetFilterByID(filterID)

	if filter.ownerID == userID then
		return true
	end

	for _,mod in pairs(filter.mods) do
		if mod.id == userID then
			return true
		end
	end

	return false, 'you must be admin or mod to edit filters'
end


function api:FilterBanUser(userID, filterID, banInfo)

	local ok, err = self:UserCanEditFilter(userID, filterID)
	if not ok then
		return ok, err
	end

	banInfo.bannedAt = ngx.time()
	return worker:FilterBanUser(filterID, banInfo)
end

function api:FilterUnbanPost(userID, filterID, postID)
	local ok, err = self:UserCanEditFilter(userID, filterID)
	if not ok then
		return ok, err
	end


	local tagName = 'meta:filterban:'..filterID
	local post = cache:GetPost(postID)
	if not post then
		return nil, 'post doesnt exist'
	end

	local newTag = self:CreateTag(userID, tagName)
	local found = false
	for _,postTag in pairs(post.tags) do
		if postTag.id == newTag.id then
			found = true
			break
		end
	end
	if not found then
		return nil, 'not banned'
	end


	newTag.up = 0
	newTag.down = -100
	newTag.score = self:GetScore(newTag.up, newTag.down)
	newTag.active = true

	ok, err = worker:QueueJob('UpdatePostFilters', post.id)
	if not ok then
		return ok, err
	end

	ok, err = worker:UpdatePostTags(post)
	return ok, err

end

function api:FilterBanPost(userID, filterID, postID)

	local ok, err = self:UserCanEditFilter(userID, filterID)
	if not ok then
		return ok, err
	end

	local tagName = 'meta:filterban:'..filterID
	local post = cache:GetPost(postID)
	if not post then
		return nil, 'post not found'
	end

	local newTag = self:CreateTag(userID, tagName)

	for _,postTag in pairs(post.tags) do
		if postTag.id == newTag.id then
			return nil, 'tag already exists'
		end
	end

	newTag.up = 100
	newTag.down = 0
	newTag.score = self:GetScore(newTag.up, newTag.down)
	newTag.active = true
	newTag.createdBy = userID

	tinsert(post.tags, newTag)

	ok, err = worker:QueueJob('UpdatePostFilters', post.id)
	if not ok then
		return ok, err
	end

	ok, err = worker:UpdatePostTags(post)
	return ok, err
end

function api:FilterUnbanDomain(userID, filterID, domainName)
	local ok, err = self:UserCanEditFilter(userID, filterID)
	if not ok then
		return ok, err
	end

	domainName = self:GetDomain(domainName) or domainName
	return worker:FilterUnbanDomain(filterID, domainName)
end

function api:GetUserAlerts(userID)
	-- can only get their own
  local alerts = cache:GetUserAlerts(userID)

  return alerts
end

function api:UpdateLastUserAlertCheck(userID)
	local ok, err = RateLimit('UpdateUserAlertCheck:',userID, 5, 10)
	if not ok then
		return ok, err
	end
	-- can only edit their own
  return worker:UpdateLastUserAlertCheck(userID)
end

function api:VerifyMessageSender(userID, messageInfo)
	messageInfo.createdBy = messageInfo.createdBy or userID
	if userID ~= messageInfo.createdBy then
		--check if they can send a message as another user
		local user = cache:GetInfo(userID)
		if not user then
			return nil, 'could not find user'
		end
		if user.role and user.role ~= 'Admin' then
			messageInfo.createdBy = userID
		end
	end
	return true
end

function api:SanitiseUserInput(msg, length)
	if type(msg) ~= 'string' then
		ngx.log(ngx.ERR, 'string expected, got: ',type(msg))
		return ''
	end
	msg = trim(msg)

	if msg == '' then
		ngx.log(ngx.ERR, 'string is blank')
		return ''
	end

	msg = SanitiseHTML(msg)
	if not length then
		return msg
	end

	return msg:sub(1, length)

end

function api:ConvertUserMessageToMessage(userID, userMessage)
	if not userMessage.threadID then
		return nil, 'no thread id'
	end

	if not userMessage.createdBy then
		userMessage.createdBy = userID
	end

	local newInfo = {
		threadID = self:SanitiseUserInput(userMessage.threadID, 200),
		body = self:SanitiseUserInput(userMessage.body, 2000),
		id = uuid.generate_random(),
		createdAt = ngx.time(),
		createdBy = self:SanitiseUserInput(userMessage.createdBy)
	}

	local ok, err = self:VerifyMessageSender(userID, newInfo)
	if not ok then
		return ok, err
	end

	return newInfo
end

function api:CreateMessageReply(userID, userMessage)
	local newMessage, ok, err

	newMessage, err = self:ConvertUserMessageToMessage(userID, userMessage)

	if not newMessage then
		return newMessage, err
	end

  ok, err = worker:CreateMessage(userMessage)
	if not ok then
		return ok, err
	end

  local thread = cache:GetThread(newMessage.threadID)
  for _,viewerID in pairs(thread.viewers) do
    if viewerID ~= newMessage.createdBy then
      worker:AddUserAlert(viewerID, 'thread:'..thread.id..':'..newMessage.id)
    end
  end

end



function api:CreateThread(userID, messageInfo)

	local ok, err = self:VerifyMessageSender(userID, messageInfo)
	if not ok then
		print(ok,err)
		return err
	end

	ok, err = RateLimit('CreateThread:', userID, 2, 60)
	if not ok then
		return ok, err
	end

	messageInfo.title = messageInfo.title or ''
	messageInfo.body = messageInfo.body or ''

	if messageInfo.title:gsub(' ','')== '' or messageInfo.body:gsub(' ','') == '' then
		return nil, 'blank message!'
	end


  local recipientID = cache:GetUserID(messageInfo.recipient)
	if not recipientID then
		ngx.log(ngx.ERR, 'user not found: ',messageInfo.recipint)
		return nil, 'couldnt find recipient user'
	end

  local thread = {
    id = uuid.generate_random(),
    createdBy = messageInfo.createdBy,
    createdAt = ngx.time(),
    title = SanitiseHTML(messageInfo.title),
    viewers = {messageInfo.createdBy,recipientID},
    lastUpdated = ngx.time()
  }

  local msg = {
    id = uuid.generate_random(),
    createdBy = messageInfo.createdBy,
    body = SanitiseHTML(messageInfo.body),
    createdAt = ngx.time(),
    threadID = thread.id
  }
	print('create thread2')
  ok, err = worker:CreateThread(thread)
	if not ok then
		return ok, err
	end

  ok, err = worker:CreateMessage(msg)
	if not ok then
		return ok, err
	end

  ok, err = worker:AddUserAlert(recipientID, 'thread:'..thread.id..':'..msg.id)
	return ok, err
end

function api:GetUserID(username)
	return cache:GetUserID(username)
end

function api:GetThreads(userID)
  return cache:GetThreads(userID)
end

function api:SubscribePost(userID, postID)
	local ok, err = RateLimit('SubscribeComment:', userID, 3, 30)
	if not ok then
		return ok, err
	end

	local post = cache:GetPost(postID)
	for _,viewerID in pairs(post.viewers) do
		if viewerID == userID then
			return nil, 'already subscribed'
		end
	end
	tinsert(post.viewers, userID)

	ok, err = worker:CreatePost(post)
	return ok, err

end

function api:SubscribeComment(userID, postID, commentID)

	local ok, err = RateLimit('SubscribeComment:', userID, 3, 10)
	if not ok then
		return ok, err
	end

  local comment = cache:GetComment(postID, commentID)
  -- check they dont exist
  for _, v in pairs(comment.viewers) do
    if v == userID then
      return
    end
  end
  tinsert(comment.viewers, userID)
  worker:UpdateComment(comment)
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

function api:UserHasVotedComment(userID, commentID)
	-- can only see own
	local userCommentVotes = cache:GetUserCommentVotes(userID)
	return userCommentVotes[commentID]
end

function api:UserHasVotedPost(userID, postID)
	-- can only see own
	local userPostVotes = cache:GetUserPostVotes(userID)
	return userPostVotes[postID]

end

function api:UserHasVotedTag(userID, postID, tagID)
	-- can only see own
	local userTagVotes = cache:GetUserTagVotes(userID)
	return userTagVotes[postID..':'..tagID]

end

function api:GetScore(up,down)
	--http://julesjacobs.github.io/2015/08/17/bayesian-scoring-of-ratings.html
	--http://www.evanmiller.org/bayesian-average-ratings.html
	if up == 0 then
      return -down
  end
  local n = up + down
  local z = 1.64485 --1.0 = 85%, 1.6 = 95%
  local phat = up / n
  return (phat+z*z/(2*n)-z*math.sqrt((phat*(1-phat)+z*z/(4*n))/n))/(1+z*z/n)

end

function api:VoteComment(userID, postID, commentID,direction)
	-- do we ever need permissions for this??

	-- check if the user has already voted
	-- if theyve voted down then remove down entry,
	-- check if they can vote more than once
	-- increment comment votes
	-- recalculate score
	-- add to user voted in cache
	-- add to user voted in redis
	-- for now dont allow unvoting

	--if self:UserHasVotedComment(userID, commentID) then
		--return if they cant multivote
	--end


	local comment = api:GetComment(postID, commentID)
	if direction == 'up' then
		comment.up = comment.up + 1
	elseif direction == 'down' then
		comment.down = comment.down + 1
	end

	comment.score = self:GetScore(comment.up,comment.down)

	local ok, err = worker:AddUserCommentVotes(userID, commentID)
	if not ok then
		return ok, err
	end

	if direction == 'up' then
		ok, err = worker:IncrementUserStat(comment.createdBy, 'stat:commentvoteup',1)
	else
		ok, err = worker:IncrementUserStat(comment.createdBy, 'stat:commentvotedown',1)
	end
	if not ok then
		return ok, err
	end

	return worker:UpdateComment(comment)

	-- also add to user voted comments?

end

function api:GetMatchingTags(userFilterIDs, postFilterIDs)
	-- find the filters that intersect
	-- find the tags of the filters
	local matchingTags = {}
	local matchedFilter
	for _,userFilterID in pairs(userFilterIDs) do
		for _, postFilterID in pairs(postFilterIDs) do
			if userFilterID == postFilterID then
				--print('found matching: ',userFilterID)
				matchedFilter = cache:GetFilterByID(userFilterID)
				for _,tagID in pairs(matchedFilter.requiredTags) do
					--print('adding tag: ',tagID)
					-- prevent duplicates
					matchingTags[tagID] = tagID
				end
			end
		end
	end
	return matchingTags
end

function api:GetUnvotedTags(user,postID, tagIDs)
	if user.role == 'Admin' then
		return tagIDs
	end

	local keyedVotedTags = cache:GetUserTagVotes(user.id)

	local unvotedTags = {}
	for _, v in pairs(tagIDs) do
		if not keyedVotedTags[postID..':'..v] then
			tinsert(unvotedTags, v)
		end
	end
	return unvotedTags

end

local function UpdateFilterTags(filter, newRequiredTags,newBannedTags)

		local ok, err
		local newPosts, oldPostIDs = worker:GetUpdatedFilterPosts(filter, newRequiredTags, newBannedTags)

	  -- filter needs to have a score per post
	  for _, newPost in pairs(newPosts) do
	    newPost.score = AverageTagScore(newRequiredTags, newPost.tags)
	  end
	  -- TODO: could make this more efficient by adding/removing just the effected filterID
		-- instead of recaculating lal filters'
		for k,v in pairs(newPosts) do
			ok, err = worker:QueueJob('UpdatePostFilters', v.id)
			if not ok then
				return ok, err
			end
		end
		for k,v in pairs(oldPostIDs) do
			ok, err = worker:QueueJob('UpdatePostFilters', v)
			if not ok then
				return ok, err
			end
		end

	  ok , err = worker:AddPostsToFilter(filter, newPosts)
		if not ok then
			return ok, err
		end

	  ok, err = worker:RemovePostsFromFilter(filter.id, oldPostIDs)
		if not ok then
			return ok, err
		end

	  return worker:UpdateFilterTags(filter, newRequiredTags, newBannedTags)

end

function api:GetRelatedFilters(filter, requiredTags)

	-- for each tag, get filters that also have that tag
	local tagIDs = {}
	for k,v in pairs(requiredTags) do
		table.insert(tagIDs, {id = v})
	end

	--print(to_json(tagIDs))
	local filterIDs = cache:GetFilterIDsByTags(tagIDs)
	local filters = {}
	for _,v in pairs(filterIDs) do
		for filterID,filterType in pairs(v) do
			if filterID ~= filter.id then
				table.insert(filters, cache:GetFilterByID(filterID))
			end
			--print(filterID)
		end
	end

--	print('this: ',to_json(filters))
	for _,filter in pairs(filters) do
		local count = 0
		for _,relatedTagID in pairs(requiredTags) do
			for _, filterTagID in pairs(filterIDs) do
				if relatedTagID == filterTagID then
					count = count + 1
				end
			end
		end
		filter.relatedTagsCount = count
	end

	table.sort(filters, function(a,b) return a.relatedTagsCount > b.relatedTagsCount end)

	local finalFilters = {}
	for i = 1, math.min(5, #filters) do
		table.insert(finalFilters, filters[i].id)
	end

	return finalFilters

end

function api:UpdateFilterTags(userID, filterID, requiredTags, bannedTags)
	--print(filterID)
	if not filterID then
		--return nil, 'no filter id!'
	end
	local ok, err = self:UserCanEditFilter(userID,filterID)
	if not ok then
		return ok, err
	end

	-- get the actual tag from the tagID

	for k,v in pairs(requiredTags) do
		if v ~= '' then
			requiredTags[k] = self:CreateTag(userID, v).id
		end
	end
	for k,v in pairs(bannedTags) do
		if v ~= '' then
			bannedTags[k] = self:CreateTag(userID, v).id
		end
	end

	local filter = cache:GetFilterByID(filterID)

	ok, err = UpdateFilterTags(filter, requiredTags, bannedTags)

	if not ok then
		print('failed: ',err)
		return ok, err
	end

	local relatedFilters = self:GetRelatedFilters(filter, requiredTags)
	ok, err = worker:UpdateRelatedFilters(filter, relatedFilters)

	ok, err = worker:LogChange(filter.id..'log', ngx.time(), {changedBy = userID, change= 'UpdateFilterTag'})
	if not ok then
		return ok,err
	end

end



function api:VotePost(userID, postID, direction)

	local ok, err = RateLimit('VotePost:', userID, 10, 60)
	if not ok then
		return ok, err
	end

	--[[
		when we vote down a post as a whole we are saying
		'this post is not good enough to be under these filters'
		or 'the tags this post has that match the filters i care about are
		not good'

	]]
	local post = cache:GetPost(postID)
	if not post then
		return nil, 'post not found'
	end

	local user = cache:GetUser(userID)
	if self:UserHasVotedPost(userID, postID) then
		if UNLIMITED_VOTING and user.role == 'Admin' then

		else
			--return nil, 'already voted'
		end
	end
	--print(user.hideVotedPosts)
	if tonumber(user.hideVotedPosts) == 1 then
		--print('hiding voted post')
		cache:AddSeenPost(userID, postID)
	end

	-- get tags matching the users filters' tags
--	print('get matching tags')
	-- do we want matching tags, or matching filters??
	local matchingTags = self:GetMatchingTags(cache:GetUserFilterIDs(userID),post.filters)
	--print(to_json(matchingTags))

	-- filter out the tags they already voted on
	--matchingTags = self:GetUnvotedTags(user,postID, matchingTags)
	for _,tagID in pairs(matchingTags) do
		for _,tag in pairs(post.tags) do
			--print(tagID ,' ', tag.id)
			if tag.id == tagID then
				self:AddVoteToTag(tag, direction)
			end
		end
	end


	ok, err = worker:QueueJob('UpdatePostFilters', post.id)
	if not ok then
		return ok, err
	end
	worker:UpdatePostTags(post)

	worker:AddUserTagVotes(userID, postID, matchingTags)
	worker:AddUserPostVotes(userID, postID)

	return true


end

function api:AddVoteToTag(tag,direction)
	if direction == 'up' then
		tag.up = tag.up + 1
	elseif direction == 'down' then
		tag.down = tag.down + 1
	end
	-- recalculate the tag score
	tag.score = self:GetScore(tag.up,tag.down)
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

function api:EditPost(userID, userPost)
	local ok, err = RateLimit('EditPost:', userID, 4, 300)
	if not ok then
		return ok, err
	end

	local post = cache:GetPost(userPost.id)

	if post.createdBy ~= userID then
		print(userPost)
		local user = cache:GetUser(userID)
		if not user or user.role ~= 'Admin' then
			return nil, 'you cannot edit other users posts'
		end
	end


	if not post then
		return nil, 'could not find post'
	end

	if ngx.time() - post.createdAt < 600 then
		post.title = self:SanitiseUserInput(userPost.title, POST_TITLE_LENGTH)
	end

	post.text = self:SanitiseUserInput(userPost.text, COMMENT_LENGTH_LIMIT)
	post.editedAt = ngx.time()

	ok, err = worker:CreatePost(post)
	return ok, err

end

function api:UpdateFilterDescription(userID, filterID, newDescription)
	local ok, err = RateLimit('EditFilter:', userID, 4, 120)
	if not ok then
		return ok, err
	end

	local filter = cache:GetFilterByID(filterID)
	if not filter then
		return nil, 'could not find filter'
	end

	if userID ~= filter.ownerID then
		local user = cache:GetUser(userID)
		if user.role ~= 'Admin' then
			return nil, 'you must be admin or filter owner to add mods'
		end
	end

	filter.description = self:SanitiseUserInput(newDescription, 2000)

	return worker:UpdateFilterDescription(filter)

end

function api:UpdateFilterTitle(userID, filterID, newTitle)
	local ok, err = RateLimit('EditFilterTitle:', userID, 4, 120)
	if not ok then
		return ok, err
	end

	local filter = cache:GetFilterByID(filterID)
	if not filter then
		return nil, 'could not find filter'
	end

	if userID ~= filter.ownerID then
		local user = cache:GetUser(userID)
		if user.role ~= 'Admin' then
			return nil, 'you must be admin or filter owner to add mods'
		end
	end

	filter.title = self:SanitiseUserInput(newTitle, POST_TITLE_LENGTH)

	return worker:UpdateFilterTitle(filter)

end

function api:EditComment(userID, userComment)
	local ok, err = RateLimit('EditComment:', userID, 4, 120)
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

	local ok, err = RateLimit('CreateComment:', userID, 1, 30)
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

function api:GetPost(userID, postID)

	if not postID then
		return nil, 'no postID!'
	end

	local post = cache:GetPost(postID)
	--print(postID, to_json(post))
	if not post then
		return nil, 'post not found'
	end

	local userVotedTags = cache:GetUserTagVotes(userID)

	if userID then
		local user = cache:GetUser(userID)

		if user.hideClickedPosts == '1' then
			cache:AddSeenPost(userID, postID)
		end
	end

	for _,tag in pairs(post.tags) do
		if userVotedTags[postID..':'..tag.id] then
			tag.userHasVoted = true
		end
	end

  return post
end

function api:GetDefaultFrontPage(range,filter)
  range = range or 0
  filter = filter or 'fresh'
  return cache:GetDefaultFrontPage(range,filter)
end


function api:SubscribeToFilter(userID,userToSubID, filterID)

  local filterIDs = cache:GetUserFilterIDs(userID)

	if userID ~= userToSubID then
		local user = cache:GetUser(userID)
		if user.role ~= 'Admin' then
			return nil, 'you must be admin to do that'
		end
	end


  for _, v in pairs(filterIDs) do
    if v == userToSubID then
      -- they are already subbed
      return nil, userToSubID..' is already subbed!'
    end
  end

  worker:SubscribeToFilter(userToSubID,filterID)

end

function api:GetUser(userID)
	-- can only get own for now
	if not userID or userID == '' then
		return nil
	end

	local userInfo  = cache:GetUser(userID)

	return userInfo
end

function api:FilterUnbanUser(filterID, userID)
	local ok, err = self:UserCanEditFilter(userID, filterID)
	if not ok then
		return ok, err
	end

	return worker:FilterUnbanUser(filterID, userID)
end

function api:FilterBanDomain(userID, filterID, banInfo)
	local ok, err = self:UserCanEditFilter(userID, filterID)
	if not ok then
		return ok, err
	end

	banInfo.bannedAt = ngx.time()
	banInfo.domainName = self:GetDomain(banInfo.domainName) or banInfo.domainName
	return worker:FilterBanDomain(filterID, banInfo)
end


function api:VerifyReset(emailAddr, resetKey)
  return cache:VerifyReset(emailAddr, resetKey)
end

function api:ResetPassword(email, key, password)
	local ok, err
	ok = cache:VerifyReset(email, key)
	if not ok then
		return nil, 'validation failed'
	end

	if password < 8 then
		return nil, 'password must be at least 8 characters!'
	end

	local master = cache:GetMasterUserByEmail(email)
	print('new password:',password)
	local passwordHash = scrypt.crypt(password)
	ok = worker:ResetMasterPassword(master.id, passwordHash)
	if not ok then
		return nil, 'validation failed'
	end
	ok, err = worker:DeleteResetKey(email)
	return ok, err
	-- can set new password
end

function api:ValidateMaster(userCredentials)
  local masterInfo = cache:GetMasterUserByEmail(userCredentials.email)

  if not masterInfo then
		print('master not found')
    return nil, 'error getting profile'
  end

  if masterInfo.active == 0 then
    return nil,true
  end
	print(userCredentials.password, ' =',masterInfo.passwordHash, '=')
  local valid = scrypt.check(userCredentials.password,masterInfo.passwordHash)

	if not valid then
		return nil
	end

	local loginInfo = {
		userIP = ngx.var.host,
		userAgent = ngx.var.http_user_agent,
		loginTime = ngx.time()
	}

	worker:LogSuccessfulLogin(masterInfo.id, loginInfo)

  masterInfo.passwordHash = nil
  return masterInfo

end

function api:SendPasswordReset(url, email)

	email = self:SanitiseUserInput(email, 200)

	local masterInfo = cache:GetMasterUserByEmail(email)
	if not masterInfo then
		return true
	end

	local resetKey = uuid.generate_random()
	return worker:SendPasswordReset(url, email, resetKey)

end

function api:GetHash(values)
  local str = require 'resty.string'
  local resty_sha1 = require 'resty.sha1'
  local sha1 = resty_sha1:new()

  local ok, err = sha1:update(values)

  local digest = sha1:final()

  return str.to_hex(digest)
end

function api:SanitiseSession(session)

	local newSession = {
		ip = session.ip,
		userAgent = session.userAgent,
		id = self:GetHash(ngx.time()..session.email..session.ip),
		email = session.email:lower(),
		createdAt = ngx.time(),
		activated = false,
		validUntil = ngx.time()+5184000,
		activationTime = ngx.time() + 1800,
	}
	return newSession
end



function api:ConfirmLogin(userSession, key)

	local sessionID, accountID = key:match('(.+)%-(%w+)')
	if not key then
		print('no key')
		return nil, 'bad key'
	end
	local account = cache:GetAccount(accountID)
	if not account then
		print('no account')
		return nil, 'no account'
	end

	local accountSession = account.sessions[sessionID]
	if not accountSession then
		print('bad session')
		return nil, 'bad session'
	end


	if accountSession.activated then
		print('invalid session')
		--return nil, 'invalid session'
	end
	if accountSession.validUntil < ngx.time() then
		print('expired session')
		--return nil, 'expired'
	end

	-- maybe check useragent/ip?

	accountSession.lastSeen = ngx.time()
	accountSession.activated = true
	account.lastSeen = ngx.time()
	account.active = true
	worker:UpdateAccount(account)

	return account, accountSession.id

end


function api:RegisterAccount(session, confirmURL)
	-- TODO rate limit
	session = self:SanitiseSession(session)
	session.confirmURL = confirmURL
	local emailLib = require 'email'
	local ok, err = emailLib:IsValidEmail(session.email)
	if not ok then
		ngx.log(ngx.ERR, 'invalid email: ',session.email, ' ',err)
		return false, 'Email provided is invalid'
	end

	session = to_json(session)
	print(session)
	ok, err = worker:RegisterAccount(session)
	return ok, err
end

function api:CreateActivationKey(masterInfo)
  local key = ngx.md5(masterInfo.id..masterInfo.email..salt)
  return key:match('.+(........)$')
end


function api:GetUserFrontPage(userID,filter,range)
	-- can only get own

  return cache:GetUserFrontPage(userID,filter,range)
end

function api:CreateSubUser(accountID, username)

  local subUser = {
    id = uuid.generate(),
    username = SanitiseHTML(username,20),
    filters = cache:GetUserFilterIDs('default'),
    parentID = accountID,
    enablePM = 1
  }

	local existingUserID = cache:GetUserID(subUser.username)
	if existingUserID then
		return nil, 'username is taken'
	end

	local account = cache:GetAccount(accountID)
	tinsert(account.users, subUser.id)
	account.userCount = account.userCount + 1
	account.currentUsername = subUser.username
	account.currentUserID = subUser.id
	local ok, err = worker:UpdateAccount(account)
	if not ok then
		return ok, err
	end
  local ok, err = worker:CreateSubUser(subUser)
	if ok then
		return subUser
	else
		return ok, err
	end
end

function api:GetAccountUsers(userAccountID, accountID)
	local userAccount = cache:GetAccount(userAccountID)

	if userAccount.role ~= 'Admin' and userAccountID ~= accountID then
		return nil, 'must be admin to view other users'
	end

	local queryAccount = cache:GetAccount(accountID)
	if not queryAccount then
		return nil, 'account not found'
	end

	local users = {}
	local subUser
  for _, subUserID in pairs(queryAccount.users) do
    subUser = cache:GetUser(subUserID)
    if subUser then
      tinsert(users, subUser)
    end
  end
  return users
end

function api:SwitchUser(accountID, userID)
	local account = cache:GetAccount(accountID)
	local user = cache:GetUser(userID)

	if user.parentID ~= accountID and account.role ~= 'admin' then
		return nil, 'noooope'
	end

	account.currentUserID = user.id
	account.currentUsername = user.username

	local ok, err = worker:UpdateAccount(account)
	if not ok then
		return ok, err
	end

	return user
end

function api:SanitizeMasterUser(master)


	if not master.username then
		return nil, 'no username given'
	end

	if not master.password then
		return nil, 'no password given'
	end

	if not master.email then
		return nil, 'no email given'
	end

	master.username = master.username:gsub(' ','')
	master.password = master.password:gsub(' ','')
	master.email = master.email:gsub(' ','')

	if #master.password > 200 then
		return nil, 'password must be shorter than 200 chars'
	end
	if #master.password < 8 then
		return nil, 'password must be longer than 8 chars'
	end

	local newMaster = {
		username = self:SanitiseUserInput(master.username, 20),
		email = self:SanitiseUserInput(master.email),
		passwordHash = scrypt.crypt(master.password),
		id = uuid.generate_random(),
		active = 0,
		userCount = 1,
		users = {}
	}

	return newMaster

end




function api:CreateMasterUser(confirmURL, userInfo)
	local ok, err,newMaster

	newMaster,err = api:SanitizeMasterUser(userInfo)
	if not newMaster then
		return newMaster, err
	end

  local firstUser = {
    id = uuid.generate_random(),
    username = newMaster.username,
    filters = cache:GetUserFilterIDs('default'),
    parentID = newMaster.id
  }

	local existingUserID = cache:GetUserID(newMaster.username)
	if existingUserID then
		return nil, 'username is taken'
	end


  tinsert(newMaster.users,firstUser.id)
  newMaster.currentUserID = firstUser.id

  local activateKey = self:CreateActivationKey(newMaster)
  local url = confirmURL..'?email='..userInfo.email..'&activateKey='..activateKey

	ok, err = worker:SendActivationEmail(url, userInfo.email)
	if err then
		return ok, err
	end

  worker:CreateMasterUser(newMaster)
  worker:CreateSubUser(firstUser)
  return true

end

function api:AddPostTag(userID, postID, tagName)

	local ok, err = RateLimit('AddPostTag:', userID, 1, 60)
	if not ok then
		return ok, err
	end

	if tagName:find('^meta:') then
		return nil, 'users cannot add meta tags'
	end

	local post = cache:GetPost(postID)
	if not post then
		return nil, 'post not found'
	end

	local newTag = self:CreateTag(userID, tagName)

	local count = 0
	for _,postTag in pairs(post.tags) do	print('a')

		if postTag.id == newTag.id then
			return nil, 'tag already exists'
		end
		if postTag.createdBy == userID then
			count = count +1
			if count > MAX_ALLOWED_TAG_COUNT then
				return nil, 'you cannot add any more tags'
			end
		end
	end

	newTag.up = TAG_START_UPVOTES
	newTag.down = TAG_START_DOWNVOTES
	newTag.score = self:GetScore(newTag.up, newTag.down)
	newTag.active = true
	newTag.createdBy = userID

	tinsert(post.tags, newTag)

	ok, err = worker:QueueJob('UpdatePostFilters', post.id)
	if not ok then
		return ok, err
	end

	ok, err = worker:UpdatePostTags(post)
	return ok, err

end

function api:UnsubscribeFromFilter(userID, subscriberID,filterID)
	if userID ~= subscriberID then
		local user = cache:GetUser(userID)
		if user.role ~= 'Admin' then
			return nil, 'you must be admin to change another users subscriptions'
		end
	end


  local filterIDs = cache:GetUserFilterIDs(userID)
  local found = nil
  for _,v in pairs(filterIDs) do
    if v == filterID then
      found = true
    end
  end
  if not found then
    -- no need to unsubscribe
    return
  end

  worker:UnsubscribeFromFilter(subscriberID,filterID)


end

function api:CreateTag(userID, tagName)

	tagName = tagName:gsub(' ','')

  if tagName == '' then
    return nil
  end
	--print(#tagName)
	tagName = self:SanitiseUserInput(tagName, 100)
	--print(#tagName)
  local tag = cache:GetTag(tagName)
  if tag then
    return tag
  end

  local tagInfo = {
    id = uuid.generate_random(),
    createdAt = ngx.time(),
    createdBy = userID,
    name = tagName
  }

  local existingTag, err = worker:CreateTag(tagInfo)
	-- tag might exist but not be in cache
	if existingTag and existingTag ~= true then
		print('tag exists: ',to_json(existingTag))
		return existingTag
	end

  return tagInfo
end



function api:GetDomain(url)
  return url:match('^%w+://([^/]+)')
end

local function CheckPostParent(post)
	local sourceTags = {}
	for _, tag in pairs(post.tags) do
		if tag.name:find('^meta:sourcePost:') then
			tinsert(sourceTags, tag)
		end
	end

	-- set a new parentID for the post if the source is over the threshold
	table.sort(sourceTags, function(a,b) return a.score > b.score end)

	if sourceTags[1] and sourceTags[1].score > SOURCE_POST_THRESHOLD then
		local parentID = sourceTags[1].name:match('meta:sourcePost:(%w+)')

		if parentID and post.parentID ~= parentID then
			post.parentID = parentID
			worker:UpdatePostParentID(post)
		end
	end
end

function api:UserCanVoteTag(userID, postID, tagID)
	if self:UserHasVotedTag(userID, postID, tagID) and (not UNLIMITED_VOTING) then
		local user = cache:GetUser(userID)
		if user.role ~= 'admin' then
			return false
		end
	end
	return true
end

function api:FindPostTag(post, tagID)
	for _, tag in pairs(post.tags) do
		if tag.id == tagID then
			return tag
		end
	end
end

function api:VoteTag(userID, postID, tagID, direction)

	if not RateLimit('VoteTag:', userID, 5, 30) then
		return nil, 'rate limited'
	end

	if not self:UserCanVoteTag(userID, postID, tagID) then
		return nil, 'cannot vote again!'
	end

	local post = cache:GetPost(postID)

	local thisTag = self:FindPostTag(post, tagID)
	if not thisTag then
		return nil, 'unable to find tag'
	end

	self:AddVoteToTag(thisTag, direction)

	--needs renaming, finds the parent of the post from source tag
	CheckPostParent(post)

	-- mark tag as voted on by user
	local ok, err = worker:AddUserTagVotes(userID, postID, {tagID})
	if not ok then
		return ok, err
	end

	-- increment how many tags the user has voted on
	if direction == 'up' then
		worker:IncrementUserStat(thisTag.createdBy, 'stat:tagvoteup',1)
	else
		worker:IncrementUserStat(thisTag.createdBy, 'stat:tagvotedown',1)
	end

	-- Is this a meaningful stat?
	for _,tag in pairs(post.tags) do
		if tag.name:find('meta:self') then
			if direction == 'up' then
				ok, err = worker:IncrementUserStat(thisTag.createdBy, 'stat:selftagvoteup',1)
			else
				ok, err = worker:IncrementUserStat(thisTag.createdBy, 'stat:selftagvotedown',1)
			end
			break -- stop as soon as we know what kind of post it is
		elseif tag.name:find('meta:link') then
			if direction == 'up' then
				ok, err = worker:IncrementUserStat(thisTag.createdBy, 'stat:linktagvoteup',1)
			else
				ok, err = worker:IncrementUserStat(thisTag.createdBy, 'stat:linktagvotedown',1)
			end
			break
		end
	end

	if not ok then
		return ok, err
	end

	ok, err = worker:QueueJob('UpdatePostFilters', post.id)
	if not ok then
		return ok, err
	end
	ok, err = worker:UpdatePostTags(post)
	return ok, err

end


function api:CreatePostTags(userID, postInfo)
	for k,tagName in pairs(postInfo.tags) do

		tagName = trim(tagName:lower())
		postInfo.tags[k] = self:CreateTag(postInfo.createdBy, tagName)


		if postInfo.tags[k] then
			postInfo.tags[k].up = TAG_START_UPVOTES
			postInfo.tags[k].down = TAG_START_DOWNVOTES
			postInfo.tags[k].score = self:GetScore(TAG_START_UPVOTES,TAG_START_DOWNVOTES)
			postInfo.tags[k].active = true
			postInfo.tags[k].createdBy = userID
		end
	end
end





function api:LoadImage(httpc, imageInfo)
	local res, err = httpc:request_uri(imageInfo.link)
	if err then
		--print(' cant laod image: ',imageInfo.link, ' err: ',err)
		return nil
	end
	--print(imageInfo.link, type(res.body), res.body)
	if res.body:len() > 0 then
		return res.body

	else
		print('empty body for '..imageInfo.link)
	end
	return nil
end

function api:GetIcon(newPost)
	--see if we can get the webpage
	--scan the webpage for image links
	--get the size of each link
	--create an icon from the largest image
	local httpc = http.new()
	local res, err = httpc:request_uri(newPost.link)
	if not res then
		print('failed: ', err)
		return
	end

	--print(res.body)
	local imageLinks = {}
	for imgTag in res.body:gmatch('<img.-src=[\'"](.-)[\'"].->') do
		if imgTag:find('^//') then
			imgTag = 'http:'..imgTag
		end
		tinsert(imageLinks, {link = imgTag})
	end

	for _, imageInfo in pairs(imageLinks) do
		local imageBlob = self:LoadImage(httpc, imageInfo)
		imageInfo.size = 0
		if imageBlob then
			local image = assert(magick.load_image_from_blob(imageBlob))

			--local icon = assert(magick.thumb(imageBlob, '100x100'))

			if image then
				imageInfo.image = image
				local w,h = image:get_width(), image:get_height()
				imageInfo.size = w*h
			end
		end
	end

	table.sort(imageLinks, function(a,b) return a.size > b.size end)

	local finalImage
	for _,v in pairs(imageLinks) do
		if v.image then
			finalImage = v
			break
		end
	end

	if not finalImage then
		return nil
	end

	finalImage.image:resize_and_crop(100,100)
	finalImage.image:set_format('png')
	if finalImage.link:find('.gif') then
		print('trying to coalesce')
		finalImage.image:coalesce()
	end
	--newPost.icon = finalImage:get_blob()
	newPost.icon = finalImage.image:get_blob()
	finalImage.image:write('static/icons/'..newPost.id..'.png')
	print('icon added, written to: ',newPost.id..'.png')

end


-- sanitise user input
function api:ConvertUserPostToPost(userID, post)

	if not userID then
		return nil, 'no userID'
	end
	if not post then
		return nil, 'no post info'
	end

	post.createdBy = post.createdBy or userID
	if userID ~= post.createdBy then
		local user = cache:GetUser(userID)
		if user.role ~= 'Admin' then
			post.createdBy = userID
		end
	end

	local newID = uuid.generate_random()

	local newPost = {
		id = newID,
		parentID = newID,
		createdBy = post.createdBy,
		commentCount = 0,
		title = self:SanitiseUserInput(post.title, POST_TITLE_LENGTH),
		link = post.link,
		text = self:SanitiseUserInput(post.text, 2000),
		createdAt = ngx.time(),
		filters = {}
	}

	newPost.tags = {}
	if post.tags == ngx.null then
		return nil, 'post needs tags!'
	end

	if not post.tags then
		return nil, 'post has no tags!'
	end

	for _,v in pairs(post.tags) do
		tinsert(newPost.tags, self:SanitiseUserInput(v, 100))
	end


	return newPost

end

function api:GeneratePostTags(post)
	if not post.link or trim(post.link) == '' then
    tinsert(post.tags,'meta:self')
  end
	tinsert(post.tags, 'meta:all')

  tinsert(post.tags,'meta:createdBy:'..post.createdBy)
end

function api:CreatePost(userID, postInfo)
	local newPost, ok, err

	ok, err = RateLimit('CreatePost:',userID, 1, 300)
	if not ok then
		return ok, err
	end

	newPost, err = self:ConvertUserPostToPost(userID, postInfo)
	if not newPost then
		return newPost, err
	end

	-- clear out any tags that shouldnt be allowed
	for k,tagName in pairs(newPost.tags) do
		if tagName:find('^meta:') then
			newPost.tags[k] = ''
		end
	end


	self:GeneratePostTags(newPost)

  if newPost.link then

    local domain  = self:GetDomain(newPost.link)
    if not domain then
      ngx.log(ngx.ERR, 'invalid url: ',newPost.link)
      return nil, 'invalid url'
    end

		ok, err = worker:QueueJob('GeneratePostIcon', newPost.id)
		if not ok then
			return ok, err
		end

    newPost.domain = domain
    tinsert(newPost.tags,'meta:link:'..newPost.link)
    tinsert(newPost.tags,'meta:domain:'..domain)
  end

	self:CreatePostTags(userID, newPost)

	newPost.viewers = {userID}
	print('creating new post')
	return worker:CreatePost(newPost)
end



function api:GetFilterPosts(filter)
  return cache:GetFilterPosts(filter)
end

function api:GetFilterByName(filterName)
  return cache:GetFilterByName(filterName)
end

function api:GetFiltersBySubs(offset,count)
  offset = offset or 0
  count = count or 10
  local filters = cache:GetFiltersBySubs(offset,count)
  return filters
end

function api:DelMod(userID, filterID, modID)

	local filter = cache:GetFilterByID(filterID)
	if not filter.ownerID == userID then
		local user = cache:GetUser(userID)
		if not user.role ~= 'Admin' then
			return nil, 'you must be admin or filter owner to remove mods'
		end
	end

	local found
	for _,mod in pairs(filter.mods) do
		if mod.id == userID then
			found = true
			break
		end
	end

	if not found then
		return nil, 'user is not a mod of this filter'
	end
	local user = cache:GetUser(modID)
	local account = cache:GetAccount(user.parentID)
	account.modCount = account.modCount - 1
	worker:UpdateAccount(account)
	return worker:DelMod(filterID, modID)

end

function api:AddMod(userID, filterID, newModName)
	local filter = cache:GetFilterByID(filterID)

	if userID ~= filter.ownerID then
		local user = cache:GetUser(userID)
		if user.role ~= 'Admin' then
			return nil, 'you must be admin or filter owner to add mods'
		end
	end


	local newModID = cache:GetUserID(newModName)
	if not newModID then
		return nil, 'could not find user with that name'
	end

	-- check they arent there already
	-- check they can be made mod of this sub
	local newMod = cache:GetUser(newModID)
	local account = cache:GetAccount(newMod.parentID)
	if account.modCount >= MAX_MOD_COUNT and account.role ~= 'admin' then
		return nil, 'mod of too many filters'
	end

	account.modCount = account.modCount + 1
	worker:UpdateAccount(account)

	local modInfo = {
		id = newModID,
		createdAt = ngx.time(),
		createdBy = userID,
		up = 10,
		down = 0,
	}
	return worker:AddMod(filterID, modInfo)

end

function api:ConvertUserFilterToFilter(userID, userFilter)
	userFilter.createdBy = userFilter.createdBy or userID
	if userID ~= userFilter.createdBy then
		local user = cache:GetUser(userID)
		if user.role ~= 'Admin' then
			userFilter.createdBy = userID
		end
	end



	local newFilter = {
		id = uuid.generate_random(),
		name = self:SanitiseUserInput(userFilter.name, 30),
		description = self:SanitiseUserInput(userFilter.name, 2000),
		title = self:SanitiseUserInput(userFilter.name, 200),
		subs = 1,
		mods = {},
		requiredTags = {},
		bannedTags = {},
		ownerID = self:SanitiseUserInput(userFilter.ownerID,50),
		createdBy = self:SanitiseUserInput(userFilter.createdBy, 50),
		createdAt = ngx.time()
	}

	local existingFilter = cache:GetFilterByName(newFilter.name)
	if existingFilter then
		return nil, 'filter name is taken'
	end

	return newFilter
end

function api:CreateFilter(userID, filterInfo)

	local newFilter, err, ok

	ok, err = RateLimit('CreateFilter:', userID, 1, 600)
	if not ok then
		return ok, err
	end

	local user = cache:GetUser(userID)
	local account = cache:GetAccount(user.parentID)
	if (account.modCount >= MAX_MOD_COUNT) and (account.role ~= 'admin') then
		--return nil, 'you cant mod any more subs!'
	end
	account.modCount = account.modCount + 1
	worker:UpdateAccount(account)


	newFilter, err = self:ConvertUserFilterToFilter(userID, filterInfo)
	if not newFilter then
		return newFilter, err
	end

  local tags = {}
	if type(filterInfo.requiredTags) ~= 'table' then
		return nil, 'required tags not provided'
	end

  for _,tagName in pairs(filterInfo.requiredTags) do
		tagName = self:SanitiseUserInput(tagName, 100)
    local tag = self:CreateTag(newFilter.createdBy,tagName)
    if tag and tagName ~= '' then
      tag.filterID = newFilter.id
      tag.filterType = 'required'
      tag.createdBy = newFilter.createdBy
      tag.createdAt = newFilter.createdAt
      tinsert(tags,tag)
      tinsert(newFilter.requiredTags, tag)
    end
  end

	if type(filterInfo.bannedTags) ~= 'table' then
		filterInfo.bannedTags = {}
	end

	table.insert(filterInfo.bannedTags, 'meta:filterban:'..newFilter.id)

  for _,tagName in pairs(filterInfo.bannedTags) do
    local tag = self:CreateTag(newFilter.createdBy,tagName)
		tagName = self:SanitiseUserInput(tagName, 100)
    if tag and tagName ~= '' then
      tag.filterID = newFilter.id
      tag.filterType = 'banned'
      tag.createdBy = newFilter.createdBy
      tag.createdAt = newFilter.createdAt
      tinsert(tags,tag)
      tinsert(newFilter.bannedTags, tag)
    end
  end
  newFilter.tags = tags

  worker:CreateFilter(newFilter)

	UpdateFilterTags(newFilter, newFilter.requiredTags, newFilter.bannedTags)

  return true
end

function api:DeletePost(userID, postID)

	local post = cache:GetPost(postID)
	if post.createdby ~= userID then
		local user = cache:GetUser(userID)
		if user.Role ~= 'Admin' then
			return nil, 'you cannot delete other peoples posts'
		end
	end

	return worker:DeletePost(postID)

end

local function UserCanAddSource(tags, userID)
	for _,tag in pairs(tags) do
		if tag.name:find('^meta:sourcePost:') and tag.createdBy == userID then
			print('found: ',tag.name, ' user id: ',userID)
			return false
		end
	end
	return true
end

function api:AddSource(userID, postID, sourceURL)
	-- rate limit them
	-- check existing sources by this user


	local ok, err = RateLimit('AddSource:', userID, 1, 600)
	if not ok then
		return ok, err
	end

	print(sourceURL)
	local sourcePostID = sourceURL:match('/post/(%w+)')
	print(sourcePostID)
	if not sourcePostID then
		return nil, 'source must be a post from this site!'
	end

	local post = cache:GetPost(postID)


	if UserCanAddSource(post.tags, userID) == false then
		return nil,  'you cannot add more than one source to a post'
	end

	local tagName = 'meta:sourcePost:'..sourcePostID
	local newTag = self:CreateTag(userID, tagName)
	print(newTag.name)
	newTag.up = TAG_START_UPVOTES
	newTag.down = TAG_START_DOWNVOTES
	newTag.score = self:GetScore(TAG_START_UPVOTES,TAG_START_DOWNVOTES)
	newTag.active = true

	tinsert(post.tags, newTag)

	ok, err = worker:UpdatePostTags(post)
	if not ok then
		return ok,err
	end

	ok, err = worker:QueueJob('UpdatePostFilters', post.id)
	if not ok then
		return ok, err
	end

	return true
end


function api.GetAllTags()
  return cache:GetAllTags()
end



return api
