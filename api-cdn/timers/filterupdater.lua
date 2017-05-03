
local CONFIG_CHECK_INTERVAL = 5

local config = {}
config.__index = config
config.http = require 'lib.http'
config.cjson = require 'cjson'

local cache = require 'api.cache'
local TAG_BOUNDARY = 0.15
local to_json = (require 'lapis.util').to_json



local common = require 'timers.common'
setmetatable(config, common)


function config:New(util)
  local c = setmetatable({},self)
  c.util = util

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
	self:ProcessJob('UpdateFilterPosts', 'UpdateFilterPosts')

end

--DRY, needs combining with api:AverageTagScore
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

function config:GetUpdatedFilterPosts(filter, requiredTagNames, bannedTagNames)
	print(to_json(filter))
  local newPostsKey = filter.id..':tempPosts'
	local oldPostsKey = 'filterposts:'..filter.id

  local ok, err = self.redisWrite:CreateTempFilterPosts(newPostsKey, requiredTagNames, bannedTagNames)
  if not ok then
    return ok, err
  end

  local oldPostIDs = self.redisWrite:GetSetDiff(oldPostsKey, newPostsKey)
  --print('old posts:'..to_json(oldPostIDs))
  local newPostIDs = self.redisWrite:GetSetDiff(newPostsKey, oldPostsKey)
  --print('new posts:'..to_json(newPostIDs))

  local newPosts = cache:GetPosts(newPostIDs)
  self.redisWrite:DeleteKey(newPostsKey)
  return newPosts, oldPostIDs

end


function config:GetRelatedFilters(filter)

	-- for each tag, get filters that also have that tag
	local tagNames = {}
	for _,tagName in pairs(filter.requiredTagNames) do
		table.insert(tagNames, {name = tagName})
	end

	local filterIDs = cache:GetFilterIDsByTags(tagNames)
	local filters = {}
	for _,v in pairs(filterIDs) do
		for filterID,_ in pairs(v) do
			if filterID ~= filter.id then
				table.insert(filters, cache:GetFilterByID(filterID))
			end
		end
	end

--	print('this: ',to_json(filters))
	for _,relatedFilter in pairs(filters) do
		local count = 0
		for _,relatedTagName in pairs(relatedFilter.requiredTagNames) do
			for _, filterTagName in pairs(filterIDs) do
				if relatedTagName == filterTagName then
					count = count + 1
				end
			end
		end
		relatedFilter.relatedTagsCount = count
	end

	table.sort(filters, function(a,b) return a.relatedTagsCount > b.relatedTagsCount end)

	local finalFilters = {}
	for i = 1, math.min(5, #filters) do
		table.insert(finalFilters, filters[i].id)
	end

	return finalFilters

end


function config:UpdateFilterPosts(data)

	local filter = self.redisRead:GetFilterByID(data.id)
	if not filter then
		ngx.log(ngx.ERR, 'couldnt load filter id: ', data.id)
		return true
	end


	local ok, err
	local requiredTagNames = filter.requiredTagNames

	local bannedTagNames = filter.bannedTagNames

	local newPosts, oldPostIDs = self:GetUpdatedFilterPosts(filter, requiredTagNames, bannedTagNames)

	--get new post scores
	for _, newPost in pairs(newPosts) do
		newPost.score = AverageTagScore(requiredTagNames, newPost.tags)
	end

	--update all the affected posts so they remove/add themselves to filters
	for _,post in pairs(newPosts) do
		ok, err = self.redisWrite:QueueJob('UpdatePostFilters', {id = post.id})
		if not ok then
			return ok, err
		end
	end
	for _,postID in pairs(oldPostIDs) do
		ok, err = self.redisWrite:QueueJob('UpdatePostFilters', {id = postID})
		if not ok then
			return ok, err
		end
	end

	ok , err = self.redisWrite:AddPostsToFilter(filter, newPosts)
	if not ok then
		print('error adding posts to filter: ',err)
		return ok, err
	end

	ok, err = self.redisWrite:RemovePostsFromFilter(filter.id, oldPostIDs)
	if not ok then
		print(ok, err)
		return ok, err
	end

	local relatedFilters = self:GetRelatedFilters(filter)
	ok, err = self.redisWrite:UpdateRelatedFilters(filter, relatedFilters)

	return ok, err

end




return config
