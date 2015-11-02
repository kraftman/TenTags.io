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
--arbitrary, needs adressing later
local TAG_BOUNDARY = 0.15
local TAG_START_DOWNVOTES = 0
local TAG_START_UPVOTES = 5

function api:UpdateUser(user)
	-- update cache later
	worker:UpdateUser(user)
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
  local alerts = cache:GetUserAlerts(userID)
  --ngx.log(ngx.ERR, #alerts)
  return #alerts > 0
end

function api:FilterBanUser(filterID, banInfo)
	banInfo.bannedAt = ngx.time()
	return worker:FilterBanUser(filterID, banInfo)
end

function api:FilterUnbanDomain(filterID, domainName)
	domainName = self:GetDomain(domainName) or domainName
	return worker:FilterUnbanDomain(filterID, domainName)
end

function api:GetUserAlerts(userID)
  local alerts = cache:GetUserAlerts(userID)
  -- need to also update the users lastcheckedAt
  -- both in redis and the cache (when it caches)

  return alerts
end

function api:UpdateLastUserAlertCheck(userID)
  return worker:UpdateLastUserAlertCheck(userID)
end

function api:CreateMessageReply(messageInfo)
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

function api:CreateThread(messageInfo)
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


function api:GetUserComments(userID)

  ngx.log(ngx.ERR, 'userID:',to_json(userID))
  local comments = cache:GetUserComments(userID)
  return comments
end

function api:UserHasVotedComment(userID, commentID)
	local userCommentVotes = cache:GetUserCommentVotes(userID)
	for _,v in pairs(userCommentVotes) do
		if v:find(commentID) then
			return true
		end
	end
	return false
end

function api:UserHasVotedPost(userID, postID)
	local userPostVotes = cache:GetUserPostVotes(userID)
	for _,v in pairs(userPostVotes) do
		if v:find(postID) then
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

function api:UpdatePostFilters(post)
	--[[
		since addfilters and updatefilters are the same, we can just add
		all of the newfilters, even if they already exist
	]]

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
	local user = cache:GetUserInfo(userID)
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

function api:CreateComment(commentInfo)

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

function api:GetFilterPosts(filterName,username,offset,sort)

  -- get large list of posts that match the user filter
  -- load the


  offset = offset or 0
  --sort = sort or 'fresh'
  if not sort or filterName then
    print('no sort')
  end

  --local filterPosts = cache:GetFilterPosts(filterName,username,offset,sort)



  local userSeenPosts = cache:GetUserSeenPosts(username) or {}
  local userFilters = cache:GetIndexedUserFilterIDs(username)

  local finalPosts = {}
  local unfilteredPosts
  local unfilteredOffset = 0

  local postID, filterID
  local postInfo

  local finalPostIDs = {}

  while #finalPostIDs < offset + 10 do
    unfilteredPosts = cache:GetMorePosts(unfilteredOffset,unfilteredOffset+1000)

    for _,v in pairs(unfilteredPosts) do
      filterID,postID = v:match('(%w+):(%w+)')
      if userFilters[filterID] then
        postInfo = cache:GetPost(postID)
        if not userSeenPosts[postInfo.nodeID] then
          tinsert(finalPosts, postInfo)
          userSeenPosts[postInfo.nodeID] = true
        end
      end
    end
  end

  if username ~= 'default' then
    cache:UpdateUserSeenPosts(username,userSeenPosts)
    worker:UpdateUserSeenPosts(username,userSeenPosts)
  end

  return finalPosts

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
	local userInfo  = cache:GetUserInfo(userID)

	return userInfo
end

function api:FilterUnbanUser(filterID, userID)
	return worker:FilterUnbanUser(filterID, userID)
end

function api:FilterBanDomain(filterID, banInfo)
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
  return cache:GetUserFrontPage(userID,filter,range)
end

function api:FlushAllPosts()
  return worker:FlushAllPosts()
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

  -- need to update master info with list of sub users
end

function api:GetMasterUsers(masterID)
  local master = cache:GetMasterUserInfo(masterID)
  local users = {}
  local user
  for _, userID in pairs(master.users) do
      user = cache:GetUserInfo(userID)
      if user then
        tinsert(users, user)
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

function api:UnsubscribeFromFilter(username,filterID)
  local filterIDs = cache:GetUserFilterIDs(username)
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

  worker:UnsubscribeFromFilter(username,filterID)

end

function api:CreateTag(tagName,createdBy)
  --check if the tag already exists
  -- create it
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
    createdBy = createdBy,
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

function api:VoteTag(postID, tagID, direction)
	-- check post for existing vote
	-- check tag for existing vote


	local post = cache:GetPost(postID)

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
		postInfo.tags[k] = self:CreateTag(v,postInfo.createdBy)

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
	for _,tag in pairs(matchingTags) do
		score = score + tag.score
	end
	filter.score = score / #matchingTags
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
			print('valid tag: ',tag.id)
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

function api:CreatePost(postInfo)
  -- rate limit
  -- basic sanity check
  -- send to worker
	-- TODO: move most of this to worker

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

function api:CreateFilter(filterInfo)

  if not api:FilterIsValid(filterInfo) then
    return false
  end

  filterInfo.id = uuid.generate_random()
  filterInfo.name = filterInfo.name:lower()
  filterInfo.subs = 1

  local tags = {}

  for k,tagName in pairs(filterInfo.requiredTags) do
    local tag = self:CreateTag(tagName, filterInfo.createdBy)
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
