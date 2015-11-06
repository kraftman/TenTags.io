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
local to_json = (require 'lapis.util').to_json
local magick = require 'magick'
local http = require 'lib.http'
--arbitrary, needs adressing later
local TAG_BOUNDARY = 0.15
local TAG_START_DOWNVOTES = 0
local TAG_START_UPVOTES = 5
--local permission = require 'userpermission'

function api:UpdateUser(userID, userToUpdate)
	if userID ~= userToUpdate.id then
		local user = cache:GetUserInfo(userID)
		if user.role ~= 'Admin' then
			return nil, 'you must be admin to edit a users details'
		end
	end

	local userInfo = {
		id = userToUpdate.id,
		enablePM = userToUpdate.enablePM and 1 or 0,
		hideSeenPosts = userToUpdate.hideSeenPosts and 1 or 0
	}

	return worker:UpdateUser(userInfo)
end

function api:SanitiseHTML(str)
	local html = {
		["<"] = "&lt;",
		[">"] = "&gt;",
		["&"] = "&amp;",
	}
	return string.gsub(tostring(str), "[<>&]", function(char)
		return html[char] or char
	end)
end

function api:GetUserFilters(userID)
	-- can only get your own filters
  if not userID then
    userID = 'default'
  end
  local filterIDs = cache:GetUserFilterIDs(userID)

  return cache:GetFilterInfo(filterIDs)
end


function api:GetFilterInfo(filterIDs)
	return cache:GetFilterInfo(filterIDs)
end

function api:GetPostComments(postID,sortBy)
  return cache:GetPostComments(postID,sortBy)
end

function api:GetComment(postID, commentID)
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

function api:UserIsMod(userID, filterID)

end

function api:UserIsAdmin(user)


end

function api:UserCanEditFilter(userID, filterID)
	local user = cache:GetUserInfo(userID)

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
  -- TODO: need to also update the users lastcheckedAt
  -- both in redis and the cache (when it caches)

  return alerts
end

function api:UpdateLastUserAlertCheck(userID)
	-- can only edit their own
  return worker:UpdateLastUserAlertCheck(userID)
end

function api:VerifyMessageSender(userID, messageInfo)
	messageInfo.createdBy = messageInfo.createdBy or userID
	if userID ~= messageInfo.createdBy then
		--check if they can send a message as another user
		local user = cache:GetInfo(userID)
		if user.role ~= 'Admin' then
			messageInfo.createdBy = userID
		end
	end
end

function api:CreateMessageReply(userID, messageInfo)

	self:VerifyMessageSender(userID, messageInfo)

  -- TODO: validate message info
  messageInfo.id = uuid.generate_random()
  messageInfo.createdAt = ngx.time()
  worker:CreateMessage(messageInfo)

  local thread = cache:GetThread(messageInfo.threadID)
  for _,userID in pairs(thread.viewers) do
    if userID ~= messageInfo.createdBy then
      ngx.log(ngx.ERR,'adding alert for user: ',userID)
      worker:AddUserAlert(userID, 'thread:'..thread.id..':'..messageInfo.id)
    end
  end

end

function api:CreateThread(userID, messageInfo)

	self:VerifyMessageSender(userID, messageInfo)

  local recipientID = cache:GetUserID(messageInfo.recipient)
  ngx.log(ngx.ERR,'recipientID ',recipientID)

  local thread = {
    id = uuid.generate_random(),
    createdBy = messageInfo.createdBy,
    createdAt = ngx.time(),
    title = messageInfo.title,
    viewers = {messageInfo.createdBy,recipientID},
    lastUpdated = ngx.time()

  }

  local msg = {
    id = uuid.generate_random(),
    createdBy = messageInfo.createdBy,
    body = messageInfo.body,
    createdAt = ngx.time(),
    threadID = thread.id
  }

  worker:CreateThread(thread)
  worker:CreateMessage(msg)
  worker:AddUserAlert(recipientID, 'thread:'..thread.id..':'..msg.id)

end

function api:GetUserID(username)
	return cache:GetUserID(username)
end

function api:GetThreads(userID)
  return cache:GetThreads(userID)
end

function api:SubscribeComment(userID, postID, commentID)
  local comment = cache:GetComment(postID, commentID)
  -- check they dont exist
  for _, v in pairs(comment.viewers) do
    if v == userID then
      return
    end
  end
  tinsert(comment.viewers, userID)
  worker:ent(comment)
end


function api:GetUserComments(userID, targetUserID)
	-- check if they allow it
	local targetUser = cache:GetUserInfo(targetUserID)
	if not targetUser then
		return nil, 'could not find user by ID '..targetUserID
	end

	if targetUser.hideComments then
		local user = cache:GetUserInfo(userID)
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
	for _,v in pairs(userCommentVotes) do
		if v:find(commentID) then
			return true
		end
	end
	return false
end

function api:UserHasVotedPost(userID, postID)
	-- can only see own
	local userPostVotes = cache:GetUserPostVotes(userID)
	for _,v in pairs(userPostVotes) do
		if v:find(postID) then
			return true
		end
	end
	return false
end

function api:UserHasVotedTag(userID, postID, tagID)
	-- can only see own
	local userTagVotes = cache:GetUserTagVotes(userID)
	for _,v in pairs(userTagVotes) do
		if v:find(postID..':'..tagID) then
			return true
		end
	end
	return false
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
	worker:UpdateComment(comment)
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
					print('adding tag: ',tagID)
					-- prevent duplicates
					matchingTags[tagID] = tagID
				end
			end
		end
	end
	return matchingTags
end

function api:GetUnvotedTags(user,postID, tagIDs)
	local votedTags = cache:GetUserTagVotes(user.id)
	if user.role == 'admin' then
		return tagIDs
	end

	local keyedVotedTags = {}
	for _,v in pairs(votedTags) do
		keyedVotedTags[v] = v
	end
	local unvotedTags = {}
	for _, v in pairs(tagIDs) do
		if not keyedVotedTags[postID..':'..v] then
			tinsert(unvotedTags, v)
		end
	end
	return unvotedTags

end

function api:UpdateFilterTags(userID, filter, requiredTags, bannedTags)
	local ok, err = self:UserCanEditFilter(userID)
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

	local newPosts, oldPostIDs = worker:GetUpdatedFilterPosts(filter, requiredTags, bannedTags)

  -- filter needs to have a score per post
  for _, newPost in pairs(newPosts) do
    local matchingTags = self:GetPostFilterTagIntersection(requiredTags, newPost.tags)
		local score = 0
		local count = 0
		for _,tag in pairs(matchingTags) do
			if not tag.name:find('^meta:') then
				score = score + tag.score
				count = count + 1
			end
		end
		newPost.score = score / count
  end

  worker:AddPostsToFilter(filter, newPosts)


  worker:RemovePostsFromFilter(filter.id, oldPostIDs)
  return worker:UpdateFilterTags(filter, requiredTags, bannedTags)


end

function api:UpdatePostFilters(post)
	--[[
		since addfilters and updatefilters are the same, we can just add
		all of the newfilters, even if they already exist
	]]
	local ok, err = self:UserCanEditFilter(userID)
	if not ok then
		return ok, err
	end


	local newFilters = self:CalculatePostFilters(post)
	local purgeFilterIDs = {}

	for _,filterID in pairs(post.filters) do
		if not newFilters[filterID] then
			purgeFilterIDs[filterID] = filterID
		end
	end

	worker:RemovePostFromFilters(post.id, purgeFilterIDs)
	worker:AddPostToFilters(post, newFilters)

	post.filters = newFilters
end

function api:VotePost(userID, postID, direction)
	--[[
		when we vote down a post as a whole we are saying
		'this post is not good enough to be under these filters'
		or 'the tags this post has that match the filters i care about are
		not good'

	]]
	local post = self:GetPost(postID)
	if not post then
		return nil, 'post not found'
	end
	--local user = cache:GetUserInfo(userID)
	--if self:UserHasVotedPost(userID, postID) then
	--	return nil, 'already voted'
	--end

	-- get tags matching the users filters' tags
	print('get matching tags')
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

	self:UpdatePostFilters(post)
	worker:UpdatePostTags(post)

	worker:AddUserTagVotes(userID,postID, matchingTags)
	worker:AddUserPostVotes(userID, postID)

	return true


end



function api:AddVoteToTag(tag,direction)
	if direction == 'up' then
		print('vote up')
		tag.up = tag.up + 1
	elseif direction == 'down' then
		print('vote down')
		tag.down = tag.down + 1
	end
	-- recalculate the tag score
	tag.score = self:GetScore(tag.up,tag.down)
end

function api:CreateComment(userID, commentInfo)
	-- check if they are who they say they are
	commentInfo.createdBy = commentInfo.createdBy or userID
	if commentInfo.createdBy ~= userID then
		local user = cache:GetUserInfo(userID)
		if user.role ~= 'Admin' then
			return nil, 'you cannot create a comment on behalf of someone else'
		end
	end

  commentInfo.id = uuid.generate_random()
  commentInfo.createdAt = ngx.time()
  commentInfo.up = 1
  commentInfo.down = 0
  commentInfo.score = self:GetScore(commentInfo.up, commentInfo.down)
  commentInfo.viewers = {commentInfo.createdBy}
  commentInfo.text = self:SanitiseHTML(commentInfo.text)

  local filters = {}
  local postFilters = self:GetPost(commentInfo.postID).filters
  ngx.log(ngx.ERR, to_json(postFilters))
  local userFilters = self:GetUserFilters(commentInfo.createdBy)

  for _,userFilter in pairs(userFilters) do
    for _,postFilterID in pairs(postFilters) do
      print(to_json(userFilter.id), to_json(postFilterID))
      if userFilter.id == postFilterID then
        print('test', to_json(userFilter))
        tinsert(filters, userFilter)
      end
    end
  end
  commentInfo.filters = filters

   worker:CreateComment(commentInfo)
  -- need to add alert to all parent comment viewers
  if commentInfo.parentID == commentInfo.postID then
    -- whole other kettle of fish
  else
    local parentComment = self:GetComment(commentInfo.postID, commentInfo.parentID)
    for _,userID in pairs(parentComment.viewers) do
      worker:AddUserAlert(userID, 'postComment:'..commentInfo.postID..':'..commentInfo.id)
    end
  end

	local post = self:GetPost(commentInfo.postID)

	worker:UpdatePostField(commentInfo.postID, 'commentCount',post.commentCount+1)

	return true

 --need to add comment to comments, commentid to user

 -- also increment post comment count
end

function api:GetPost(postID)
  return cache:GetPost(postID)
end

function api:GetDefaultFrontPage(range,filter)
  range = range or 0
  filter = filter or 'fresh'
  return cache:GetDefaultFrontPage(range,filter)
end


function api:SubscribeToFilter(userID,filterID)

  local filterIDs = cache:GetUserFilterIDs(userID)

  for _, v in pairs(filterIDs) do
    if v == filterID then
      -- they are already subbed
      return
    end
  end

  worker:SubscribeToFilter(userID,filterID)

end

function api:GetUserInfo(userID)
	-- can only get own for now
	if not userID or userID == '' then
		return nil
	end

	local userInfo  = cache:GetUserInfo(userID)

	return userInfo
end

function api:FilterUnbanUser(filterID, userID)
	local ok, err = self:UserCanEditFilter(userID, filterID)
	if not ok then
		return ok, err
	end

	return worker:FilterUnbanUser(filterID, userID)
end

function api:FilterBanDomain(filterID, banInfo)
	local ok, err = self:UserCanEditFilter(userID, filterID)
	if not ok then
		return ok, err
	end

	banInfo.bannedAt = ngx.time()
	banInfo.domainName = self:GetDomain(banInfo.domainName) or banInfo.domainName
	return worker:FilterBanDomain(filterID, banInfo)
end

function api:ValidateMaster(userCredentials)
  local masterInfo = cache:GetMasterUserByEmail(userCredentials.email)

  if not masterInfo then
    return
  end

  if masterInfo.active == 0 then
    return nil,true
  end

  local valid = scrypt.check(userCredentials.password,masterInfo.passwordHash)
  if valid then
    masterInfo.passwordHash = nil
    return masterInfo
  end

end

function api:CreateActivationKey(masterInfo)
  local key = ngx.md5(masterInfo.id..masterInfo.email..salt)
  return key:match('.+(........)$')
end

function api:ActivateAccount(email, key)
  email = email and email:lower() or ''
  if email == '' then
    return nil, 'email is blank!'
  end

  local userInfo = cache:GetMasterUserByEmail(email)
  if not userInfo then
    return nil, 'could not find account with this email'
  end

  local realKey = self:CreateActivationKey(userInfo)
  if key == realKey then
    --cache:UpdateUserInfo(userInfo)
    worker:ActivateAccount(userInfo.id)
    return true
  else
    return nil, 'activation key incorrect'
  end
end

function api:GetUserFrontPage(userID,filter,range)
	-- can only get own
  return cache:GetUserFrontPage(userID,filter,range)
end


function api:CreateSubUser(masterID, username)

  local subUser = {
    id = uuid.generate(),
    username = username,
    filters = cache:GetUserFilterIDs('default'),
    parentID = masterID,
    enablePM = 1
  }

  local master = cache:GetMasterUserInfo(masterID)
  tinsert(master.users,subUser.id)

  worker:CreateMasterUser(master)

  return worker:CreateSubUser(subUser)

  -- TODO: need to update master info with list of sub users
end

function api:GetMasterUsers(userID, masterID)
  local master = cache:GetMasterUserInfo(masterID)
  local users = {}
  local user = cache:GetUserInfo(userID)

	if user.role ~= 'Admin' then
		local found = nil
		for _,subUserID in pairs(master.users) do
			if userID == subUserID then
				found = true
				break
			end
		end
		if not found then
			return nil, 'must be admin to view other users'
		end
	end

	local subUser
  for _, subUserID in pairs(master.users) do
      subUser = cache:GetUserInfo(subUserID)
      if user then
        tinsert(users, subUser)
      end
  end
  return users
end


function api:CreateMasterUser(confirmURL, userInfo)
  userInfo.username = userInfo.username and userInfo.username:lower() or ''
  userInfo.password = userInfo.password and userInfo.password:lower() or ''
  userInfo.email = userInfo.email and userInfo.email:lower() or ''

  if trim(userInfo.username) == '' then
    return nil, 'no username provided!'
  elseif trim(userInfo.email) == '' then
    return nil, 'no email provided!'
  elseif trim(userInfo.password) == '' then
    return nil, 'no password provided!'
  end

  local masterInfo = {
    email = userInfo.email,
    passwordHash = scrypt.crypt(userInfo.password),
    id = uuid.generate_random(),
    active = 0,
    userCount = 1,
    users = {}
  }

  local firstUser = {
    id = uuid.generate_random(),
    username = userInfo.username,
    filters = cache:GetUserFilterIDs('default'),
    parentID = masterInfo.id
  }

  tinsert(masterInfo.users,firstUser.id)
  masterInfo.currentUserID = firstUser.id

  local activateKey = self:CreateActivationKey(masterInfo)
  local url = confirmURL..'?email='..userInfo.email..'&activateKey='..activateKey
  worker:SendActivationEmail(url, userInfo.email)
  worker:CreateMasterUser(masterInfo)
  worker:CreateSubUser(firstUser)
  return true

end

function api:UnsubscribeFromFilter(userID, subscriberID,filterID)
	if userID ~= subscriberID then
		local user = cache:GetUserInfo(userID)
		if user.role ~= 'Admin' then
			return nil, 'you must be admin to change another users subscriptions'
		end
	end


  local filterIDs = cache:GetUserFilterIDs(userID)
  local found = false
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

  if tagName:gsub(' ','') == '' then
    return nil
  end

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

  worker:CreateTag(tagInfo)
  return tagInfo
end

function api:PostIsValid(postInfo)
  return postInfo
end

function api:GetDomain(url)
  return url:match('^%w+://([^/]+)')
end

function api:VoteTag(userID, postID, tagID, direction)
	-- check post for existing vote
	-- check tag for existing vote

	--if self:UserHasVotedPost(userID, postID) then
		--return nil, 'already voted'
	--end



	local post = cache:GetPost(postID)

	if self:UserHasVotedTag(userID, postID, tagID) then
		return nil, 'already voted on tag'
	end

	for _, tag in pairs(post.tags) do
		if tag.id == tagID then
			self:AddVoteToTag(tag, direction)
		end
	end

	self:UpdatePostFilters(post)
	worker:UpdatePostTags(post)

end


function api:AddPostTags(postInfo)
	for k,v in pairs(postInfo.tags) do

		v = trim(v:lower())
		postInfo.tags[k] = self:CreateTag(postInfo.createdBy, v)

		if postInfo.tags[k] then
			postInfo.tags[k].up = TAG_START_UPVOTES
			postInfo.tags[k].down = TAG_START_DOWNVOTES
			postInfo.tags[k].score = self:GetScore(TAG_START_UPVOTES,TAG_START_DOWNVOTES)
			postInfo.tags[k].active = true
		end
	end
end

function api:GetValidFilters(filterID, post)

	local filter = cache:GetFilterByID(filterID)
	if not filter then
		ngx.log(ngx.ERR,'filter not found: ',filterID)
		return nil
	end

	--rather than just checking they exist, also need to get
	-- all intersecting tags, and calculate an average score

	-- check all desired tags are present on the post
	local matchingTags = self:GetPostFilterTagIntersection(filter.requiredTags, post.tags)
	if not matchingTags or #matchingTags == 0 then
		--print('tags dont match')
		return nil
	end

	local score = 0
	local count = 0
	for _,tag in pairs(matchingTags) do
		if not tag.name:find('^meta:') then
			--print(tag.name.. ' '..tag.up.. ' '..tag.down)
			score = score + tag.score
			count = count + 1
		end
	end
	filter.score = score / count
	--print(filter.score)


	if (filter.bannedUsers[post.createdBy]) then
		ngx.log(ngx.ERR, 'ignoring filter: ',filter.id,' as user: ',post.createdBy, ' is banned')
		return nil
	elseif filter.bannedDomains[post.domain] then
		ngx.log(ngx.ERR, 'ignoring filter: ',filter.id,' as domain ',post.domain, ' is banned ' )
		return nil
	end
	return filter
end

function api:CalculatePostFilters(post)
	-- get all the filters that care about this posts' tags

	-- only include tags above threshold
	local validTags = {}
	for _, tag in pairs(post.tags) do
		if tag.score > TAG_BOUNDARY then
			--print('valid tag: ',tag.id)
			tinsert(validTags, tag)
		end
	end

	local filterIDs = cache:GetFilterIDsByTags(post.tags)
  local chosenFilterIDs = {}

  -- add all the filters that want these tags
  for _,v in pairs(filterIDs) do
    for filterID,filterType in pairs(v) do
      if filterType == 'required' then
				--print('wants this tag: ',filterID)
        chosenFilterIDs[filterID] = filterID
      end
    end
  end

  -- remove all the filters that dont, or have bans
  for _,v in pairs(filterIDs) do
    for filterID,filterType in pairs(v) do
			if filterType == 'banned' then
				--print('doesnt want this tag: ',filterID)
				chosenFilterIDs[filterID] = nil
			else
				chosenFilterIDs[filterID] = self:GetValidFilters(filterID, post)
			end
    end
  end

	-- we now have [filterID] = {filter}
	-- also filter contains the new score

  return chosenFilterIDs
end

function api:LoadImage(httpc, imageInfo)
	local res, err = httpc:request_uri(imageInfo.link)
	if not res then
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
	for k,v in pairs(imageLinks) do
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

function api:CreatePost(userID, postInfo)
  -- rate limit
  -- basic sanity check
  -- send to worker
	-- TODO: move most of this to worker
	if not userID then
		return nil, 'no userID'
	end

	postInfo.createdBy = postInfo.createdBy or userID
	if userID ~= postInfo.createdBy then
		local user = cache:GetUserInfo(userID)
		if user.role ~= 'Admin' then
			postInfo.createdBy = userID
		end
	end

  if not api:PostIsValid(postInfo) then
    return false
  end

  postInfo.id = uuid.generate()
  postInfo.parentID = postInfo.id
  postInfo.createdBy = postInfo.createdBy or 'default'
  postInfo.commentCount = 0
  postInfo.score = 0

  if not postInfo or trim(postInfo.link) == '' then
    tinsert(postInfo.tags,'meta:type:self')
  end


  tinsert(postInfo.tags,'meta:user:'..postInfo.createdBy)
  if postInfo.link then
		self:GetIcon(postInfo)
    local domain  = self:GetDomain(postInfo.link)
    if not domain then
      ngx.log(ngx.ERR, 'invalid url: ',postInfo.link)
      return nil, 'invalid url'
    end
    postInfo.domain = domain
    tinsert(postInfo.tags,'meta:type:link')
    tinsert(postInfo.tags,'meta:link:'..domain)
  end
	self:AddPostTags(postInfo)


	local postFilters = self:CalculatePostFilters(postInfo)

	postInfo.filters = {}
	for k,_ in pairs(postFilters) do
		tinsert(postInfo.filters,k)
	end

  worker:AddPostToFilters(postInfo, postFilters)
  worker:CreatePost(postInfo)
  return true
end

function api:GetPostFilterTagIntersection(filterTags,postTags)

	local matchingTags = {}
  for _,filterTagID in pairs(filterTags) do
    for _,postTag in pairs(postTags) do
      if filterTagID == postTag.id then
        tinsert(matchingTags,postTag)
      end
    end
  end
	if #matchingTags == 0 then
		return nil
	end

  return matchingTags
end

function api:FilterIsValid(filterInfo)
  return filterInfo
  -- lower case it
  -- check for invalid chars
  -- check it doesnt already exist
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

	return worker:DelMod(filterID, modID)

end

function api:AddMod(userID, filterID, newModName)
	local filter = cache:GetFilterByID(filterID)

	if userID ~= filter.ownerID then
		local user = cache:GetUserInfo(userID)
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

	local modInfo = {
		id = newModID,
		createdAt = ngx.time(),
		createdBy = userID,
		up = 10,
		down = 0,
	}
	return worker:AddMod(filterID, modInfo)

end

function api:CreateFilter(userID, filterInfo)
	filterInfo.createdBy = filterInfo.createdBy or {}
	if userID ~= filterInfo.createdBy then
		local user = cache:GetUserInfo(userID)
		if user.role ~= 'Admin' then
			filterInfo.createdBy = userID
		end
	end

  if not api:FilterIsValid(filterInfo) then
    return false
  end

  filterInfo.id = uuid.generate_random()
  filterInfo.name = filterInfo.name:lower()
  filterInfo.subs = 1
	filterInfo.mods = {}

  local tags = {}

  for k,tagName in pairs(filterInfo.requiredTags) do
    local tag = self:CreateTag(filterInfo.createdBy,tagName)
    if tag then
      tag.filterID = filterInfo.id
      tag.filterType = 'required'
      tag.createdBy = filterInfo.createdBy
      tag.createdAt = filterInfo.createdAt
      tinsert(tags,tag)
      filterInfo.requiredTags[k] = tag
    else
      filterInfo.requiredTags[k] = nil
    end
  end

  for k,tagName in pairs(filterInfo.bannedTags) do
    local tag = self:CreateTag(tagName, filterInfo.createdBy)
    if tag then
      tag.filterID = filterInfo.id
      tag.filterType = 'banned'
      tag.createdBy = filterInfo.createdBy
      tag.createdAt = filterInfo.createdAt
      tinsert(tags,tag)
      filterInfo.bannedTags[k] = tag
    else
      --if its blank
      filterInfo.bannedTags[k] = nil
    end
  end
  filterInfo.tags = tags

  worker:CreateFilter(filterInfo)


  return true
end


function api.GetAllTags()
  return cache:GetAllTags()
end


return api
