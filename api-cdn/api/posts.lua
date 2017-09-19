
local app_helpers = require("lapis.application")
local capture_errors, assert_error = app_helpers.capture_errors, app_helpers.assert_error


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

function api:ReloadImage(userID, postID)
  local user = cache:GetUser(userID)
  if not user then
    return nil, 'couldnt find user'
  end
  if user.role ~= 'Admin' then
    return nil, 'admins only!'
  end

  local post = cache:GetPost(postID)

  if (not post.link) or post.link == "" then
    return nil, 'post has no link'
  end

  assert_error(self.redisWrite:QueueJob('GeneratePostIcon', {id = post.id}))

  return true
end



function api:ReportPost(userID, postID, reportText)

  local post = cache:GetPost(postID)
  if post.reports[userID] then
    return nil, 'youve already reported this post'
  end

  post.reports = post.reports or {}
  post.reports[userID] = self:SanitiseUserInput(reportText, 300)

  self.redisWrite:CreatePost(post)
  if not ok then
    return nil, err
  end
  self.redisWrite:AddReport(userID, postID)
  self:InvalidateKey('post',postID)

  return ok,err

  --check they havent already reported it
  -- add it to the list of reports attached to the postID
  -- add it to the admin list of reports
end

function api:AddPostTag(userID, postID, tagName)

	if tagName:find('^meta:') then
		return nil, 'users cannot add meta tags'
	end

	local post = cache:GetPost(postID)

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

	self.redisWrite:QueueJob('UpdatePostFilters', {id = post.id})

	return self.redisWrite:UpdatePostTags(post)

end

function api:VotePost(userID, postID, direction)


  local postVote = {
    userID = userID,
    postID = postID,
    id = userID..':'..postID,
    direction = direction
  }

  local user = cache:GetUser(userID)
	if user.hideVotedPosts then
		cache:AddSeenPost(userID, postID)
	end

  return self.redisWrite:QueueJob('votepost',postVote)

end

function api:SubscribePost(userID, postID)

	local post = cache:GetPost(postID)
  local found
	for i,viewerID in ipairs(post.viewers) do
		if viewerID == userID then
			table.remove(post.viewers, i)
      found = true
		end
	end
  if not found then
	   tinsert(post.viewers, userID)
  end
	self.redisWrite:CreatePost(post)
  return self:InvalidateKey('post', post.id)

end

function api:CreatePostTags(userID, postInfo)
	for k,tagName in pairs(postInfo.tags) do

		tagName = trim(tagName:lower())
		postInfo.tags[k] = {name = tagName}

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

	local sourcePostID = sourceURL:match('/p/(%w+)')
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

	self.redisWrite:UpdatePostTags(post)
  self.userWrite:IncrementUserStat(userID, 'SourcesAdded', 1)

	self.redisWrite:QueueJob('UpdatePostFilters', {id = post.id})

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
	local userVotedTags = cache:GetUserTagVotes(userID)
	local user = cache:GetUser(userID)


	if user and user.hideClickedPosts then
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

	local post = cache:GetPost(userPost.id)


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

	post.text = newText
  print('setting new text to',newText)
	post.editedAt = ngx.time()


	self.redisWrite:CreatePost(post)

  return self:InvalidateKey('post', post.id)
end

-- sanitise user input
function api:ConvertUserPostToPost(userID, post)

	post.createdBy = post.createdBy or userID
  local user = cache:GetUser(userID)
  if user.role == 'Admin' and user.fakeNames then

    local account = cache:GetAccount(user.parentID)
    local newUserName = userlib:GetRandom()

    user = userAPI:CreateSubUser(account.id, newUserName) or cache:GetUser(cache:GetUserID(newUserName))
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
		commentCount = 0,
		title = self:SanitiseUserInput(post.title, POST_TITLE_LENGTH),
		link = self:SanitiseUserInput(post.link, 2083),
		text = self:SanitiseUserInput(post.text, 2000),
		createdAt = ngx.time(),
		filters = {},
    bbID = post.bbID,
    images = post.images,
	}
	if newPost.link:gsub(' ','') == '' then
		newPost.link = nil
	end

	newPost.tags = {}
	if post.tags == ngx.null  or not post.tags then
		yield_error('post needs tags!')
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
    if post.images then
      if #post.images > 1 then
        newPost.postType = 'self-image'
        tinsert(newPost.tags,'meta:self-image')
      else
        newPost.postType = 'self-image'
        tinsert(newPost.tags,'meta:self-image-album')
      end
    else
      newPost.postType = 'self'
      tinsert(newPost.tags,'meta:self')
    end
  end
	tinsert(newPost.tags, 'meta:all')
  tinsert(newPost.tags,'meta:createdBy:'..post.createdBy)
  if user.role == 'Admin' then
    tinsert(newPost.tags, 'meta:admin')
  end

  if newPost.bbID then
    print(ngx.var.host)
    newPost.link = ngx.var.scheme..'://'..ngx.var.host..'/image/'..newPost.id
  end

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

function api:GetUserPosts(userID, targetUserID, startAt, range)
  startAt = startAt or 0 -- 0 index for redis
  range = range or 20

  -- check if they allow it
  local targetUser = cache:GetUser(targetUserID)
  if not targetUser then
    return nil, 'could not find user by ID '..targetUserID
  end

  if targetUser.hidePosts then
    local user = cache:GetUser(userID)
    if not user.role == 'Admin' then
      return nil, 'user has disabled comment viewing'
    end
  end

  return cache:GetUserPosts(targetUserID, startAt, range)

end


function api:AddImage(postID, bbID)
  return self.redisWrite:AddImage(postID, bbID)
end

function api:CreatePost(userID, postInfo)

	local newPost = self:ConvertUserPostToPost(userID, postInfo)

  self:CreatePostTags(userID, newPost)

  --self.redisWrite:CreatePost(newPost)
  -- add the post to our local cache

  cache:UpdateKey('post', newPost)
  self:QueueUpdate('post:create', newPost)
  -- queue the post up for processing and adding to redis
  --self.redisWrite:QueueJob('CreatePost', info)
  return newPost

end


return api
