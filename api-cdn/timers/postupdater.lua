
local CONFIG_CHECK_INTERVAL = 5

local config = {}
config.__index = config
config.http = require 'lib.http'
config.cjson = require 'cjson'

local userAPI = require 'api.users'
local tagAPI = require 'api.tags'
local cache = require 'api.cache'
local tinsert = table.insert
local TAG_BOUNDARY = 0.25
local to_json = (require 'lapis.util').to_json
local elastic = require 'lib.elasticsearch'

local SPECIAL_TAGS = {
	nsfw = 'nsfw',
	nsfl = 'nsfl',

}

local NSFW_LEVELS = {
	nsfw = 1,
	nsfw1 = 1,
	nsfw2 = 2,
	nsfw3 = 3
}

local common = require 'timers.common'
setmetatable(config, common)


function config:New(util)
  local c = setmetatable({},self)
  c.util = util
	c.common = common
	math.randomseed(ngx.now()+ngx.worker.pid())
	math.random() math.random() math.random()

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
  self:ProcessJob('CheckReposts', 'CheckReposts')
	self:ProcessJob('CreatePost', 'CreatePost')
	self:ProcessJob('votepost', 'VotePost')
	self:ProcessJob('UpdatePostFilters', 'UpdatePostFilters')
	self:ProcessJob('AddPostShortURL', 'AddPostShortURL')
	self:ProcessJob('ReIndexPost', 'ReIndexPost')
	self:EmptyOldFilters()
	self:ProcessJob('AddCommentShortURL', 'AddCommentShortURL')

end

function config:EmptyOldFilters()
	local ok, err = self.redisWrite:EmptyFilter()
	if not ok then
		ngx.log(ngx.ERR,'error emptying filters: ',err)
	end
end

function config:ReIndexPost(data)
	local post = self.redisRead:GetPost(data.id)
	if not post then
		return true
	end

	local indexable = {
		title = post.title,
		text = post.text,
		createdBy = post.createdBy,
		id = post.id,
		shortURL = post.shortURL or nil,
		url = post.link or nil
	}
	local ok, err = elastic:Index('post',indexable)
	if not ok then
		ngx.log(ngx.ERR, 'failed to index doc: ', err)
		return nil, err
	end

	return true
end


function config:VotePost(postVote)


	  	--[[
	  		when we vote down a post as a whole we are saying
	  		'this post is not good enough to be under these filters'
	  		or 'the tags this post has that match the filters i care about are
	  		not good'

	  	]]

	local user = cache:GetUser(postVote.userID)
	if userAPI:UserHasVotedPost(postVote.userID, postVote.postID) then
		if user.role ~= 'Admin' then
			return true
		end
	end

	local post = cache:GetPost(postVote.postID)
	if not post then
		return true
	end

	local matchingTags = tagAPI:GetMatchingTags(cache:GetUserFilterIDs(user.currentView),post.filters)

	-- filter out the tags they already voted on
	matchingTags = tagAPI:GetUnvotedTags(user,postVote.postID, matchingTags)
	if (next(matchingTags)~= nil) then
		self.userWrite:IncrementUserStat(postVote.userID, 'PostsVoted', 1)
		self.userWrite:IncrementUserStat(postVote.userID, 'PostsVoted:'..postVote.direction, 1)
	end
	for _,tagName in pairs(matchingTags) do
		for _,tag in pairs(post.tags) do
			if tag.name == tagName then
				tagAPI:AddVoteToTag(tag, postVote.direction)
				self.userWrite:IncrementUserStat(postVote.userID, 'TagVoted', 1)
				self.userWrite:IncrementUserStat(postVote.userID, 'TagVoted:'..postVote.direction, 1)
			end
		end
	end

	self.redisWrite:UpdatePostTags(post)


	ok, err = self.redisWrite:QueueJob('UpdatePostFilters', {id = post.id})

	self.userWrite:AddUserTagVotes(postVote.userID, postVote.postID, matchingTags)
	ok, err = self.userWrite:AddUserPostVotes(postVote.userID, post.createdAt, postVote.postID, postVote.direction)
	if not ok then
		print('couldnt add voted post: ', err)
	end
	cache:PurgeKey({keyType = 'postvote', id = postVote.userID})
	ok, err = self.redisWrite:InvalidateKey('postvote', postVote.userID)
	print('purged cache')

	return true

end




local function AverageTagScore(filterrequiredTagNames,postTags)

	local score = 0
	local count = 0

  for _,filterTagName in pairs(filterrequiredTagNames) do
    for _,postTag in pairs(postTags) do
      if filterTagName == postTag.name then
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

function config:CreatePost(post)
	post = self.redisRead:GetPost(post.id)
	if not post then
		return nil, 'couldnt load post'
	end

	local ok, err

	-- add stats, but dont return if they fail
	ok, err = self.userWrite:IncrementUserStat(post.createdBy, 'PostsCreated', 1)
	if not ok then
		ngx.log(ngx.ERR, 'unable to add stat: ', err)
	end

	local user = self.userRead:GetUser(post.createdBy)
	for _,subscriberID in pairs(user.postSubscribers) do
		self.userWrite:AddUserAlert(post.createdAt, subscriberID, 'post:'..post.id)
    cache:PurgeKey({keyType = 'useralert', id = subscriberID})
    ok, err = self.redisWrite:InvalidateKey('useralert', subscriberID)
	end


  ok, err = self.userWrite:AddPost(post)
  if not ok then
    return ok, err
  end

	self.redisWrite:IncrementSiteStat('PostsCreated', 1)
	if not ok then
		ngx.log(ngx.ERR, 'unable to add stat')
	end

	if post.link and post.link ~= '' then
		ok, err = self.redisWrite:QueueJob('GeneratePostIcon', {id = post.id})
	  if not ok then
	    return ok, err
	  end
	end

  ok, err = self.redisWrite:QueueJob('UpdatePostFilters',{id = post.id})
  if not ok then
    return ok, err
  end

  ok, err = self.redisWrite:QueueJob('AddPostShortURL',{id = post.id})
  if not ok then
    return ok, err
  end

  ok, err = self.redisWrite:QueueJob('CheckReposts', {id = post.id})
  if not ok then
    return ok, err
  end

  ok, err = self.redisWrite:QueueJob('ReIndexPost', {id = post.id})
  if not ok then
    return ok, err
  end


	return true

end


function config:GetValidFilters(filter, post)


	--rather than just checking they exist, also need to get
	-- all intersecting tags, and calculate an average score

	filter.score = AverageTagScore(filter.requiredTagNames, post.tags)

	if (filter.bannedUsers[post.createdBy]) then
		ngx.log(ngx.ERR, 'ignoring filter: ',filter.id,' as user: ',post.createdBy, ' is banned')
		return nil
	elseif filter.bannedDomains[post.domain] then
		ngx.log(ngx.ERR, 'ignoring filter: ',filter.id,' as domain ',post.domain, ' is banned ' )
		return nil
	end

	return filter
end

function config:TagsMatch(filter, post)
  -- the post needs to have all of the tags that the filter wants in order to be valid
  local found
  for _,filterTagName in pairs(filter.requiredTagNames) do
    found = false

    for _,postTag in pairs(post.tags) do
      if filterTagName == postTag.name then
				found = true
      end
    end

    if not found then
      return false
    end
  end
  return true
end


function config:CalculatePostFilters(post)
	-- get all the filters that care about this posts' tags

	-- only include tags above threshold
	local validTags = {}
  --print(to_json(post))

  -- get the required tags that we actually care about
	for _, tag in pairs(post.tags) do
		if tag.score > TAG_BOUNDARY then
			tinsert(validTags, tag)
		end
	end

  --get all filters that match any of these tags
	local chosenFilterIDs, err = cache:GetRelevantFilters(validTags)
	if not chosenFilterIDs then
		print(err)
	end
	-- we need a list of filters, and the tags they are interested in,
	-- and why they are interested in them

  local chosenFilters = {}
  -- if there are any tags the filter doesnt want, remove it
  -- else load it
	for _,filterID in pairs(chosenFilterIDs) do
    chosenFilters[filterID] = cache:GetFilterByID(filterID)
    if not chosenFilters[filterID] then
      ngx.log(ngx.ERR,'filter not found: ',filterID)
    end
  end

  --at this point we know that the filters want at least one tag
  --that the post has

  for filterID, filter in pairs(chosenFilters) do
    if self:TagsMatch(filter, post) then
		  chosenFilters[filterID] = self:GetValidFilters(filter, post)
    else
      chosenFilters[filterID] = nil
    end
  end

	-- dodgy: filter now contains the new score for the post

  return chosenFilters
end


function config:CreateShortURL(postID)
  local urlChars = 'abcdefghjkmnopqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789'

  local newURL = ''
  for _ = 1, 7 do
    local v = math.random(#urlChars)
    newURL = newURL..urlChars:sub(v,v)
  end

  --check if its taken
  return newURL
end

function config:AddPostShortURL(data)
	local post = self.redisRead:GetPost(data.id)
	if not post then
		return true
	end

	local ok, err

  local shortURL
  for i = 1, 6 do
    shortURL = self:CreateShortURL(post.id)
    ok, err = self.redisWrite:SetShortURL(shortURL, post.id)
    if err then
      ngx.log(ngx.ERR, 'unable to set shorturl: ',shortURL, ' postID: ', post.id)
      return nil
    end

    if ok ~= ngx.null then
      break
    end

    if (i == 6) then
      ngx.log(ngx.ERR, 'unable to generate short url for post ID: ', post.id)
      return
    end
  end

  -- add short url to hash
  -- deleted job
  ok, err = self.redisWrite:UpdatePostField(post.id, 'shortURL', shortURL)
	cache:PurgeKey({keyType = 'post', id = post.id})
	self.redisWrite:InvalidateKey('post', post.id)
  if not ok then
    print('error updating post field: ',err)
    return nil
  end

	return true

  --ngx.log(ngx.ERR, 'successfully added shortURL for postID ', postID,' shortURL: ',shortURL)

end

function config:AddCommentShortURL(data)

	local commentPostPair = data.id

  local shortURL, ok, err
  for i = 1, 6 do
    shortURL = self:CreateShortURL()
    ok, err = self.redisWrite:SetShortURL(shortURL, commentPostPair)
    if err then
      ngx.log(ngx.ERR, 'unable to set shorturl: ',shortURL, ' commentPostPair: ', commentPostPair)
      return nil
    end

    if ok ~= ngx.null then
      break
    end

    if (i == 6) then
      ngx.log(ngx.ERR, 'unable to generate short url for post ID: ', commentPostPair)
      return nil
    end
  end

  local postID, commentID = commentPostPair:match('(%w+):(%w+)')

  ok, err = self.commentWrite:UpdateCommentField(postID, commentID, 'shortURL', shortURL)
  if not ok then
    print('error updating post field: ',err)
    return
  end
	cache:PurgeKey {keyType = 'comment', id = postID}

	ok , err = self.redisWrite:InvalidateKey('comment', postID)
	if not ok then
		print('error invalidating key: ', err)
	end

  ngx.log(ngx.ERR, 'successfully added shortURL for commentID ', commentPostPair,' shortURL: ',shortURL)
	return true
end




function config:UpdatePostFilters(data)
	local post = self.redisRead:GetPost(data.id)
	if not post then
		ngx.log(ngx.ERR 'post not found: ', to_json(data))
		return true
	end

	local newFilters = self:CalculatePostFilters(post)
	local purgeFilterIDs = {}

	for _,filterID in pairs(post.filters) do
		if not newFilters[filterID] then
			purgeFilterIDs[filterID] = filterID
		end
	end

	local nsfwLevel = 0
  for _,tag in pairs(post.tags) do
		--print(tag.name)
    if tag.name:find('nsfl') then
			post.nsfl = 'true'
		end
		if NSFW_LEVELS[tag.name] then
			nsfwLevel = math.max(nsfwLevel, NSFW_LEVELS[tag.name])
		end
  end
	print('nsfw level: ',nsfwLevel)
	if nsfwLevel > 0 then
		post.nsfwLevel = nsfwLevel
	else
		post.nsfwLevel = nil
	end


  --print('removing from: '..to_json(purgeFilterIDs))
  --print('adding to: '..to_json(newFilters))

	local ok, err = self.redisWrite:RemovePostFromFilters(post.id, purgeFilterIDs)
	if not ok then
		print('couldnt remove post from filters: ',err)
		return ok, err
	end
--	print(to_json(post))
	--print(to_json(newFilters))
	ok, err = self.redisWrite:AddPostToFilters(post, newFilters)
	if not ok then
		print('couldnt add post to filters',ok, '|',err)
		return ok, err
	end

	post.filters = newFilters
  post.filters = {}
  for _,filter in pairs(newFilters) do
    tinsert(post.filters,filter.id)
  end

  ok, err = self.redisWrite:CreatePost(post)
	if not ok then
		ngx.log(ngx.ERR, err)
	end
	cache:PurgeKey({keyType = 'post', id = post.id})
	ok,err = self.redisWrite:InvalidateKey('post', post.id)
	if not ok then
		ngx.log(ngx.ERR, err)
	end
	return true
end

function config:CheckReposts(postData)

  local post = self.redisRead:GetPost(postData.id)
	if not post then
		return true
	end

  if not post.link then
    return true
  end

  local linkTag
  for _,tag in pairs(post.tags) do
    if tag.name == 'meta:link:'..post.link:lower() then
      linkTag = tag
      break
    end
  end
  if not linkTag then
    print('cant find link tag')
    return true
  end

  local posts, err = self.redisRead:GetTagPosts(linkTag.name)
  if not posts then
    print(err)
  end
  if not next(posts) then
    print('no posts found')
    return true
  end


  for k,id in pairs(posts) do
    posts[k] = self.redisRead:GetPost(id)
  end


	table.sort(posts, function(a,b) return a.createdAt < b.createdAt end)

  local parentPost = posts[1]
  post.parentID = parentPost.id
  --updating parent ID
  self.redisWrite:UpdatePostParentID(post)

	return true

end



return config
