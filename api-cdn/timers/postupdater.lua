
local CONFIG_CHECK_INTERVAL = 5

local config = {}
config.__index = config
config.http = require 'lib.http'
config.cjson = require 'cjson'

local redisRead = require 'api.redisread'
local redisWrite = require 'api.rediswrite'
local commentWrite = require 'api.commentwrite'
local cache = require 'api.cache'
local tinsert = table.insert
local TAG_BOUNDARY = 0.15
local to_json = (require 'lapis.util').to_json
local SEED = 1879873

local SPECIAL_TAGS = {
	nsfw = 'nsfw'
}

function config:New(util)
  local c = setmetatable({},self)
  c.util = util
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
  self:UpdatePostShortURL()
  self:AddCommentShortURL()
  self:UpdatePostFilters()
  self:CheckReposts()

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
  -- the post needs to have all of the tags that the filter has in order to be valid
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
		print(to_json(tag))
		if tag.score > TAG_BOUNDARY then
			tinsert(validTags, tag)
		end
	end

  --get all filters that match any of these tags
	local filterIDs = cache:GetFilterIDsByTags(validTags)
  -- cant flatten this table yet as it would remove duplicates

  local chosenFilterIDs = {}

  -- add all the filters that actually want these tags
  for _,v in pairs(filterIDs) do
    for filterID,filterType in pairs(v) do
      if filterType == 'required' then
        chosenFilterIDs[filterID] = filterID
      end
    end
  end

  local chosenFilters = {}
  -- if a filter doesnt want any of the tags, remove it
  -- else load it
	--print('this')
  for _,v in pairs(filterIDs) do
    for filterID,filterType in pairs(v) do
      if filterType ~= 'banned' then
        chosenFilters[filterID] = cache:GetFilterByID(filterID)
        if not chosenFilters[filterID] then
          ngx.log(ngx.ERR,'filter not found: ',filterID)
        end
      end
    end
  end

	--remove banned
	for _,v in pairs(filterIDs) do
    for filterID,filterType in pairs(v) do
      if filterType == 'banned' then
        chosenFilters[filterID] = nil
      end
    end
  end
  --print('potential filters: ',to_json(chosenFilters))

  --at this point we know that the filters want at least one tag
  --that the post has

  for filterID,filter in pairs(chosenFilters) do
    if self:TagsMatch(filter, post) then
		  chosenFilters[filterID] = self:GetValidFilters(filter, post)
    else
      chosenFilters[filterID] = nil
    end
  end

	-- dodgy: filter now contains the new score for the post

  return chosenFilters
end

function config:GetJob(jobName)
  local postID = redisRead:GetOldestJob(jobName)
  if not postID then
    return
  end

  local ok, err = redisWrite:DeleteJob(jobName,postID)

  if ok ~= 1 then
    if err then
      ngx.log(ngx.ERR, 'error deleting job: ',err)
    end
    return
  end

  local post = redisRead:GetPost(postID)
  if not post then
    return
  end
  return post
end

function config:CreateShortURL(postID)
  local urlChars = 'abcdefghjkmnopqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789'
  SEED = SEED + 1

  local newURL = ''
  for _ = 1, 7 do
    local v = math.random(#urlChars)
    newURL = newURL..urlChars:sub(v,v)
  end

  --check if its taken
  return newURL
end

function config:UpdatePostShortURL()

  local postID = redisRead:GetOldestJob('AddPostShortURL')
  if not postID then
    return
  end

  local ok, err = redisWrite:GetLock('UpdatePostShortURL:'..postID,10)
  if ok == ngx.null then
    return
  end

  local shortURL
  for i = 1, 5 do
    shortURL = self:CreateShortURL(postID)
    ok, err = redisWrite:SetNX('shortURL:'..shortURL, postID)
    if err then
      ngx.log(ngx.ERR, 'unable to set shorturl: ',shortURL, ' postID: ', postID)
      return
    end

    if ok ~= ngx.null then
      break
    end

    if (i == 5) then
      ngx.log(ngx.ERR, 'unable to generate short url for post ID: ', postID)
      return
    end
  end

  -- add short url to hash
  -- deleted job
  ok, err = redisWrite:UpdatePostField(postID, 'shortURL', shortURL)
  if not ok then
    print('error updating post field: ',err)
    return
  end

  ok, err = redisWrite:DeleteJob('AddPostShortURL',postID)

  --ngx.log(ngx.ERR, 'successfully added shortURL for postID ', postID,' shortURL: ',shortURL)

end

function config:AddCommentShortURL()

  local commentPostPair = redisRead:GetOldestJob('AddCommentShortURL')
  if not commentPostPair then
    return
  end

  local ok, err = redisWrite:GetLock('AddCommentShortURL:'..commentPostPair,10)
  if ok == ngx.null then
    return
  end

  local shortURL
  for i = 1, 5 do
    shortURL = self:CreateShortURL()
    ok, err = redisWrite:SetNX('shortURL:'..shortURL, commentPostPair)
    if err then
      ngx.log(ngx.ERR, 'unable to set shorturl: ',shortURL, ' commentPostPair: ', commentPostPair)
      return
    end

    if ok ~= ngx.null then
      break
    end

    if (i == 5) then
      ngx.log(ngx.ERR, 'unable to generate short url for post ID: ', commentPostPair)
      return
    end
  end

  local postID, commentID = commentPostPair:match('(%w+):(%w+)')

  ok, err = commentWrite:UpdateCommentField(postID, commentID, 'shortURL', shortURL)
  if not ok then
    print('error updating post field: ',err)
    return
  end

  ok, err = redisWrite:DeleteJob('AddCommentShortURL',commentPostPair)

  ngx.log(ngx.ERR, 'successfully added shortURL for commentID ', commentPostPair,' shortURL: ',shortURL)

end


function config:UpdatePostFilters()
	--[[
		since addfilters and updatefilters are the same, we can just add
		all of the newfilters, even if they already exist
	]]

  local post = self:GetJob('UpdatePostFilters')
  if not post then
    return
  end

	local newFilters = self:CalculatePostFilters(post)
	--print(to_json(newFilters))
	local purgeFilterIDs = {}

	for _,filterID in pairs(post.filters) do
		if not newFilters[filterID] then
			purgeFilterIDs[filterID] = filterID
		end
	end

  local specialTagFound = {}

  for _,tag in pairs(post.tags) do
		--print(tag.name)
    if SPECIAL_TAGS[tag.name] then
      specialTagFound[SPECIAL_TAGS[tag.name]] = true
    end
  end

  for k,v in pairs(SPECIAL_TAGS) do
    if specialTagFound[k] then
			print('found special tag: ',v)
      post['specialTag:'..v] = 'true'
    else
      post['specialTag:'..v] = 'false'
    end
  end

  --print('removing from: '..to_json(purgeFilterIDs))
  --print('adding to: '..to_json(newFilters))

	local ok, err = redisWrite:RemovePostFromFilters(post.id, purgeFilterIDs)
	if not ok then
		print('couldnt remove post from filters: ',err)
		return ok, err
	end
--	print(to_json(post))
	--print(to_json(newFilters))
	ok, err = redisWrite:AddPostToFilters(post, newFilters)
	if not ok then
		print('couldnt add post to filters',ok, '|',err)
		return ok, err
	end

	post.filters = newFilters
  post.filters = {}
  for _,filter in pairs(newFilters) do
    tinsert(post.filters,filter.id)
  end

  ok, err = redisWrite:CreatePost(post)
	if not ok then
		print(err)
	end
	return
end

function config:CheckReposts()

  --[[]]

  local postID = redisRead:GetOldestJob('CheckReposts')
  if not postID then
    return
  end

  local ok, err = redisWrite:GetLock('CheckReposts:'..postID,10)
  if ok == ngx.null then
    return
  end

  local post = redisRead:GetPost(postID)

  local postLink = post.link
  if not postLink then
    return
  end

  local linkTag
  for _,tag in pairs(post.tags) do
    if tag.name == 'meta:link:'..postLink:lower() then
      linkTag = tag
      break
    end
  end
  if not linkTag then
    print('cant find link tag')
    return
  end

  local posts, err = redisRead:GetTagPosts(linkTag.name)
  if not posts then
    print(err)
  end
  if not next(posts) then
    print('no posts found')
    return
  end


  for k,postID in pairs(posts) do
    posts[k] = redisRead:GetPost(postID)
  end


	table.sort(posts, function(a,b) return a.createdAt < b.createdAt end)

  local parentPost = posts[1]
  post.parentID = parentPost.id
  --updating parent ID
  redisWrite:UpdatePostParentID(post)

  ok, err = redisWrite:DeleteJob('CheckReposts',postID)

end



return config
