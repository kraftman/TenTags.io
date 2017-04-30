
local cache = require 'api.cache'
local util = require 'api.util'
local uuid = require 'lib.uuid'
local worker = require 'api.worker'
local redisWrite = require 'api.rediswrite'
local userWrite  = require 'api.userwrite'
local api = {}



function api:SearchTags(searchString)
	searchString = util:SanitiseUserInput(searchString, 100)
	return cache:SearchTags(searchString)
end



function api:GetAllTags()
  return cache:GetAllTags()
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

  local existingTag, err = rediswrite:CreateTag(tagInfo)
	-- tag might exist but not be in cache
	if existingTag and existingTag ~= true then
		print('tag exists')
		return existingTag
	end
	print(to_json(tagInfo))
  return tagInfo
end




function api:VoteTag(userID, postID, tagName, direction)

	if not util.RateLimit('VoteTag:', userID, 5, 30) then
		return nil, 'rate limited'
	end

	if not self:UserCanVoteTag(userID, postID, tagName) then
		return nil, 'cannot vote again!'
	end

	local post = cache:GetPost(postID)

	local thisTag = self:FindPostTag(post, tagName)
	if not thisTag then
		return nil, 'unable to find tag'
	end

	self:AddVoteToTag(thisTag, direction)

	--needs renaming, finds the parent of the post from source tag
	CheckPostParent(post)

	-- mark tag as voted on by user
	local ok, err = userWrite:AddUserTagVotes(userID, postID, {tagName})
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

	ok, err = redisWrite:QueueJob('UpdatePostFilters', post.id)
	if not ok then
		return ok, err
	end
	ok, err = worker:UpdatePostTags(post)
	return ok, err

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
				for _,tagName in pairs(matchedFilter.requiredTagNames) do
					--print('adding tag: ',tagName)
					-- prevent duplicates
					matchingTags[tagName] = tagName
				end
			end
		end
	end
	return matchingTags
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


function api:GetUnvotedTags(user,postID, tagNames)
	if user.role == 'Admin' then
		return tagNames
	end

	local keyedVotedTags = cache:GetUserTagVotes(user.id)

	local unvotedTags = {}
	for _, v in pairs(tagNames) do
		if not keyedVotedTags[postID..':'..v] then
			tinsert(unvotedTags, v)
		end
	end
	return unvotedTags

end


return api
