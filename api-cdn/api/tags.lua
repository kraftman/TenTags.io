

local app_helpers = require("lapis.application")
local capture_errors, assert_error = app_helpers.capture_errors, app_helpers.assert_error


local cache = require 'api.cache'
local to_json = (require 'lapis.util').to_json
local base = require 'api.base'
local api = setmetatable({}, base)
local tinsert = table.insert
local SOURCE_POST_THRESHOLD = 0.75
local userAPI = require 'api.users'


function api:SearchTags(searchString)
	searchString = self:SanitiseUserInput(searchString, 100)
	return cache:SearchTags(searchString)
end

function api:GetAllTags()
  return cache:GetAllTags()
end


function api:FindPostTag(post, tagName)
	for _, tag in pairs(post.tags) do
		if tag.name == tagName then
			return tag
		end
	end
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
			self.redisWrite:UpdatePostParentID(post)
		end
	end
end


function api:CreateTag(userID, tagName)


	tagName = tagName:gsub(' ','')

  if tagName == '' then
    return nil
  end

	tagName = self:SanitiseUserInput(tagName, 100)

  local tag = cache:GetTag(tagName)
  if tag then
    return tag
  end

  local tagInfo = {
    createdAt = ngx.time(),
    createdBy = userID,
    name = tagName
  }

  return tagInfo
end




function api:VoteTag(userID, postID, tagName, direction)

	if not userAPI:UserCanVoteTag(userID, postID, tagName) then
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
	self.userWrite:AddUserTagVotes(userID, postID, {tagName})


	-- increment how many tags the user has voted on
	print('voting on tag made by ', cache:GetUsername(thisTag.createdBy))
	if direction == 'up' then
		self.userWrite:IncrementUserStat(thisTag.createdBy, 'stat:tagvoteup',1)
	else
		self.userWrite:IncrementUserStat(thisTag.createdBy, 'stat:tagvotedown',1)
	end

	-- Is this a meaningful stat?
	for _,tag in pairs(post.tags) do
		if tag.name:find('meta:self') then
			if direction == 'up' then
				self.userWrite:IncrementUserStat(thisTag.createdBy, 'stat:selftagvoteup',1)
			else
				self.userWrite:IncrementUserStat(thisTag.createdBy, 'stat:selftagvotedown',1)
			end
			break -- stop as soon as we know what kind of post it is
		elseif tag.name:find('meta:link') then
			if direction == 'up' then
				self.userWrite:IncrementUserStat(thisTag.createdBy, 'stat:linktagvoteup',1)
			else
				self.userWrite:IncrementUserStat(thisTag.createdBy, 'stat:linktagvotedown',1)
			end
			break
		end
	end


	self.redisWrite:QueueJob('UpdatePostFilters', {id = post.id})

	return self.redisWrite:UpdatePostTags(post)

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
