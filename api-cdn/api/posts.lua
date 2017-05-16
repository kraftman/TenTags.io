

local cache = require 'api.cache'
local uuid = require 'lib.uuid'

local tagAPI = require 'api.tags'

local trim = (require 'lapis.util').trim
local base = require 'api.base'
local api = setmetatable({}, base)
local tinsert = table.insert
local POST_TITLE_LENGTH = 300
local COMMENT_LENGTH_LIMIT = 2000
local userlib = require 'lib.userlib'
local TAG_START_DOWNVOTES = 10
local TAG_START_UPVOTES = 11
local MAX_ALLOWED_TAG_COUNT = 30
local userAPI = require 'api.users'

local function UserCanAddSource(tags, userID)
  for _,tag in pairs(tags) do
    if tag.name:find('^meta:sourcePost:') and tag.createdBy == userID then
      return false
    end
  end
  return true
end

function api:ConvertShortURL(postID)
  return cache:ConvertShortURL(postID)
end

function api:UserCanAddTag(userID, newTag, tags)

	local count = 0
	for _,postTag in pairs(tags) do

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

  return true
end

function api:AddPostTag(userID, postID, tagName)

	local ok, err = self:RateLimit('AddPostTag:', userID, 1, 60)
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


  local newTag = tagAPI:CreateTag(userID, tagName)

  ok, err = self:UserCanAddTag(userID, newTag, post.tags)
  if not ok then
    return nil, err
  end


  self.userWrite:IncrementUserStat(userID, 'TagsAdded', 1)

	newTag.up = TAG_START_UPVOTES
	newTag.down = TAG_START_DOWNVOTES
	newTag.score = self:GetScore(newTag.up, newTag.down)
	newTag.active = true
	newTag.createdBy = userID

	tinsert(post.tags, newTag)

	ok, err = self.redisWrite:QueueJob('UpdatePostFilters', {id = post.id})
	if not ok then
		return ok, err
	end

	ok, err = self.redisWrite:UpdatePostTags(post)
	return ok, err

end






function api:VotePost(userID, postID, direction)

	local ok, err = self:RateLimit('VotePost:', userID, 10, 60)
	if not ok then
		return ok, err
	end

  local postVote = {
    userID = userID,
    postID = postID,
    id = userID..':'..postID,
    direction = direction
  }

  local user = cache:GetUser(userID)
	if tonumber(user.hideVotedPosts) == 1 then
		cache:AddSeenPost(userID, postID)
	end

  return self.redisWrite:QueueJob('votepost',postVote)

end

function api:SubscribePost(userID, postID)
	local ok, err = self:RateLimit('SubscribeComment:', userID, 3, 30)
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

	ok, err = self.redisWrite:CreatePost(post)
	return ok, err

end



function api:CreatePostTags(userID, postInfo)
	for k,tagName in pairs(postInfo.tags) do
		--print(tagName)

		tagName = trim(tagName:lower())
		postInfo.tags[k] = tagAPI:CreateTag(postInfo.createdBy, tagName)

		if postInfo.tags[k] then
			postInfo.tags[k].up = TAG_START_UPVOTES
			postInfo.tags[k].down = TAG_START_DOWNVOTES
			postInfo.tags[k].score = self:GetScore(TAG_START_UPVOTES,TAG_START_DOWNVOTES)
			postInfo.tags[k].active = true
			postInfo.tags[k].createdBy = userID
		end
	end
end



function api:AddSource(userID, postID, sourceURL)

	local ok, err = self:RateLimit('AddSource:', userID, 1, 600)
	if not ok then
		return ok, err
	end

	local sourcePostID = sourceURL:match('/post/(%w+)')
	if not sourcePostID then
		return nil, 'source must be a post from this site!'
	end

	local post = cache:GetPost(postID)

	if not UserCanAddSource(post.tags, userID) then
		return nil,  'you cannot add more than one source to a post'
	end

	local tagName = 'meta:sourcePost:'..sourcePostID
	local newTag = tagAPI:CreateTag(userID, tagName)
	newTag.up = TAG_START_UPVOTES
	newTag.down = TAG_START_DOWNVOTES
	newTag.score = self:GetScore(TAG_START_UPVOTES,TAG_START_DOWNVOTES)
	newTag.active = true

	tinsert(post.tags, newTag)

	ok, err = self.redisWrite:UpdatePostTags(post)
	if not ok then
		return ok,err
	end


  self.userWrite:IncrementUserStat(userID, 'SourcesAdded', 1)

	ok, err = self.redisWrite:QueueJob('UpdatePostFilters', {id = post.id})
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

	return self.redisWrite:DeletePost(postID)

end


function api:GetPost(userID, postID)
  if not postID then
    return nil, 'no post id'
  end

	local post = cache:GetPost(postID)

	if not post then
		return nil, 'post not found'
	end

	local userVotedTags = cache:GetUserTagVotes(userID)


	local user = cache:GetUser(userID)

	if user.hideClickedPosts == '1' then
		cache:AddSeenPost(userID, postID)
	end

	for _,tag in pairs(post.tags) do
		if userVotedTags[postID..':'..tag.name] then
			tag.userHasVoted = true
		end
	end

  return post
end


function api:EditPost(userID, userPost)
	local ok, err = self:RateLimit('EditPost:', userID, 4, 300)
	if not ok then
		return ok, err
	end

	local post = cache:GetPost(userPost.id)

	if not post then
		return nil, 'could not find post'
	end

	if post.createdBy ~= userID then
		local user = cache:GetUser(userID)
		if not user or user.role ~= 'Admin' then
			return nil, 'you cannot edit other users posts'
		end
	end

  -- only allow changing the title for newly made posts
	if ngx.time() - post.createdAt < 600 then
		post.title = self:SanitiseUserInput(userPost.title, POST_TITLE_LENGTH)
	end

  -- save EditPost
  local newText = self:SanitiseUserInput(userPost.text, COMMENT_LENGTH_LIMIT)
  if post.text ~= newText then
    -- save the edit history
    post.edits = post.edits or {}
    post.edits[ngx.time()] = {time = ngx.time(), editedBy = userID, original = post.text}
  end

	post.text = self:SanitiseUserInput(userPost.text, COMMENT_LENGTH_LIMIT)
	post.editedAt = ngx.time()

	ok, err = self.redisWrite:CreatePost(post)
	return ok, err

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
  local user = cache:GetUser(userID)
  if user.role == 'Admin' and user.fakeNames then
    local account = cache:GetAccount(user.parentID)
    local newUserName = userlib:GetRandom()
    print(newUserName)
    user = userAPI:CreateSubUser(account.id, newUserName) or cache:GetUserID(newUserName)
    if user then
      post.createdBy = user.id
    end
  else
    post.createdBy = userID
  end


	local newID = uuid.generate_random()

	local newPost = {
		id = newID,
		parentID = newID,
		createdBy = post.createdBy,
    creatorName = user.username,
		commentCount = 0,
		title = self:SanitiseUserInput(post.title, POST_TITLE_LENGTH),
		link = self:SanitiseUserInput(post.link, 400),
		text = self:SanitiseUserInput(post.text, 2000),
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
		tinsert(newPost.tags, self:SanitiseUserInput(v, 100))
	end

  for k,tagName in pairs(newPost.tags) do
		if tagName:find('^meta:') then
			newPost.tags[k] = ''
		end
	end

  if (not post.link) or trim(post.link) == '' then
		newPost.postType = 'self'
    tinsert(newPost.tags,'meta:self')
  end
	tinsert(newPost.tags, 'meta:all')

  tinsert(newPost.tags,'meta:createdBy:'..post.createdBy)

  if newPost.link then

    local domain  = self:GetDomain(newPost.link)
    if not domain then
      ngx.log(ngx.ERR, 'invalid url: ',newPost.link)
      return nil, 'invalid url'
    end



    newPost.domain = domain
    tinsert(newPost.tags,'meta:link:'..newPost.link)
    tinsert(newPost.tags,'meta:domain:'..domain)
  end

  newPost.viewers = {userID}


	return newPost

end


function api:CreatePost(userID, postInfo)

	local newPost, ok, err

	ok, err = self:RateLimit('CreatePost:',userID, 1, 300)
	if not ok then
		return ok, err
	end

	newPost, err = self:ConvertUserPostToPost(userID, postInfo)
	if not newPost then
    ngx.log(ngx.ERR, 'error creating post: ',err)
		return newPost, 'error creating post'
	end

  self:CreatePostTags(userID, newPost)
  ok, err = self.redisWrite:CreatePost(newPost)
  if not ok then
    ngx.log(ngx.ERR, 'unable to createpost: ',err)
    return nil, 'error creating new post'
  end

  local info = {
    id = newPost.id
  }

  ok, err = self.redisWrite:QueueJob('CreatePost', info)
  if not ok then
    ngx.log(ngx.ERR, 'couldnt queue createpost: ', err)
    return nil, 'error processing post'
  end

  return newPost
end


return api
