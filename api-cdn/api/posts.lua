
local cache = require 'api.cache'
local util = require 'api.util'
local uuid = require 'lib.uuid'
local worker = require 'api.worker'
local userAPI = require 'api.users'

local trim = (require 'lapis.util').trim
local api = {}
local tinsert = table.insert
local POST_TITLE_LENGTH = 300
local COMMENT_LENGTH_LIMIT = 2000

local TAG_START_DOWNVOTES = 0
local TAG_START_UPVOTES = 1
local MAX_ALLOWED_TAG_COUNT = 30

local function UserCanAddSource(tags, userID)
  for _,tag in pairs(tags) do
    if tag.name:find('^meta:sourcePost:') and tag.createdBy == userID then
      return false
    end
  end
  return true
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


function api:ConvertShortURL(postID)
  return cache:ConvertShortURL(postID)
end



function api:AddPostTag(userID, postID, tagName)

	local ok, err = util.RateLimit('AddPostTag:', userID, 1, 60)
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

		if postTag.name == newTag.name then
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
	newTag.score = util:GetScore(newTag.up, newTag.down)
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



function api:CreateTag(userID, tagName)


	tagName = tagName:gsub(' ','')

  if tagName == '' then
    return nil
  end

	tagName = util:SanitiseUserInput(tagName, 100)

  local tag = cache:GetTag(tagName)
  if tag then
		print(to_json(tag))
    return tag
  end

  local tagInfo = {
    createdAt = ngx.time(),
    createdBy = userID,
    name = tagName
  }

  local existingTag, err = worker:CreateTag(tagInfo)
	-- tag might exist but not be in cache
	if existingTag and existingTag ~= true then
		print('tag exists')
		return existingTag
	end
	print(to_json(tagInfo))
  return tagInfo
end




function api:VotePost(userID, postID, direction)

	local ok, err = util.RateLimit('VotePost:', userID, 10, 60)
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
	if userAPI:UserHasVotedPost(userID, postID) then
		if UNLIMITED_VOTING and user.role == 'Admin' then

		else
			return nil, 'already voted'
		end
	end

	if tonumber(user.hideVotedPosts) == 1 then
		print('hiding voted post')
		cache:AddSeenPost(userID, postID)
	end

	-- get tags matching the users filters' tags
--	print('get matching tags')
	-- do we want matching tags, or matching filters??
	local matchingTags = self:GetMatchingTags(cache:GetUserFilterIDs(userID),post.filters)
	--print(to_json(matchingTags))

	-- filter out the tags they already voted on
	--matchingTags = self:GetUnvotedTags(user,postID, matchingTags)
	for _,tagName in pairs(matchingTags) do
		for _,tag in pairs(post.tags) do
			if tag.name == tagName then
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

function api:SubscribePost(userID, postID)
	local ok, err = util.RateLimit('SubscribeComment:', userID, 3, 30)
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



function api:CreatePostTags(userID, postInfo)
	for k,tagName in pairs(postInfo.tags) do
		--print(tagName)

		tagName = trim(tagName:lower())
		postInfo.tags[k] = self:CreateTag(postInfo.createdBy, tagName)

		if postInfo.tags[k] then
			postInfo.tags[k].up = TAG_START_UPVOTES
			postInfo.tags[k].down = TAG_START_DOWNVOTES
			postInfo.tags[k].score = util:GetScore(TAG_START_UPVOTES,TAG_START_DOWNVOTES)
			postInfo.tags[k].active = true
			postInfo.tags[k].createdBy = userID
		end
	end
end




function api:FindPostTag(post, tagName)
	for _, tag in pairs(post.tags) do
		if tag.name== tagName then
			return tag
		end
	end
end


function api:AddSource(userID, postID, sourceURL)
	-- rate limit them
	-- check existing sources by this user


	local ok, err = util.RateLimit('AddSource:', userID, 1, 600)
	if not ok then
		return ok, err
	end

	local sourcePostID = sourceURL:match('/post/(%w+)')
	if not sourcePostID then
		return nil, 'source must be a post from this site!'
	end

	local post = cache:GetPost(postID)


	if UserCanAddSource(post.tags, userID) == false then
		return nil,  'you cannot add more than one source to a post'
	end

	local tagName = 'meta:sourcePost:'..sourcePostID
	local newTag = self:CreateTag(userID, tagName)
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
		if userVotedTags[postID..':'..tag.name] then
			tag.userHasVoted = true
		end
	end

  return post
end


function api:EditPost(userID, userPost)
	local ok, err = util.RateLimit('EditPost:', userID, 4, 300)
	if not ok then
		return ok, err
	end

	local post = cache:GetPost(userPost.id)

	if post.createdBy ~= userID then
		local user = cache:GetUser(userID)
		if not user or user.role ~= 'Admin' then
			return nil, 'you cannot edit other users posts'
		end
	end


	if not post then
		return nil, 'could not find post'
	end

	if ngx.time() - post.createdAt < 600 then
		post.title = util:SanitiseUserInput(userPost.title, POST_TITLE_LENGTH)
	end

	post.text = util:SanitiseUserInput(userPost.text, COMMENT_LENGTH_LIMIT)
	post.editedAt = ngx.time()

	ok, err = worker:CreatePost(post)
	return ok, err

end


function api:GeneratePostTags(post)
	if not post.link or trim(post.link) == '' then
		post.postType = 'self'
    tinsert(post.tags,'meta:self')
  end
	tinsert(post.tags, 'meta:all')

  tinsert(post.tags,'meta:createdBy:'..post.createdBy)
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
		title = util:SanitiseUserInput(post.title, POST_TITLE_LENGTH),
		link = util:SanitiseUserInput(post.link, 400),
		text = util:SanitiseUserInput(post.text, 2000),
		createdAt = ngx.time(),
		filters = {}
	}
	if newPost.link:gsub(' ','') == '' then
		newPost.link = nil
	end

	newPost.tags = {}
	if post.tags == ngx.null then
		return nil, 'post needs tags!'
	end

	if not post.tags then
		return nil, 'post has no tags!'
	end

	for _,v in pairs(post.tags) do
		tinsert(newPost.tags, util:SanitiseUserInput(v, 100))
	end


	return newPost

end


function api:CreatePost(userID, postInfo)
	local newPost, ok, err

	ok, err = util.RateLimit('CreatePost:',userID, 1, 300)
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

    local domain  = util:GetDomain(newPost.link)
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


return api
