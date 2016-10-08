
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
local SEED = 1
local worker = require 'api.worker'

local SPECIAL_TAGS = {
	nsfw = 'nsfw'
}

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

  self:UpdateFilterPosts()

end


function config:GetJob(jobName)
  local filterID = redisRead:GetOldestJob(jobName)
  if not filterID then
    return
  end

  local ok, err = redisWrite:DeleteJob(jobName,filterID)

  if ok ~= 1 then
    if err then
      ngx.log(ngx.ERR, 'error deleting job: ',err)
    end
    return
  end

  local filter = redisRead:GetFilter(filterID)
  if not filter then
		print('couldnt load filter: ',filterID)
    return
  end
  return filter
end

--DRY, needs combining with api:AverageTagScore
local function AverageTagScore(filterRequiredTagIDs,postTags)

	local score = 0
	local count = 0

  for _,filterTagID in pairs(filterRequiredTagIDs) do
    for _,postTag in pairs(postTags) do
      if filterTagID == postTag.id then
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

function config:GetUpdatedFilterPosts(filter, requiredTagIDs, bannedTagIDs)

  local newPostsKey = filter.id..':tempPosts'
	local oldPostsKey = 'filterposts:'..filter.id

  local ok, err = redisWrite:CreateTempFilterPosts(newPostsKey, requiredTagIDs, bannedTagIDs)
  if not ok then
    return ok, err
  end

  local oldPostIDs = redisWrite:GetSetDiff(oldPostsKey, newPostsKey)
  --print('old posts:'..to_json(oldPostIDs))
  local newPostIDs = redisWrite:GetSetDiff(newPostsKey, oldPostsKey)
  --print('new posts:'..to_json(newPostIDs))

  local newPosts = cache:GetPosts(newPostIDs)
  redisWrite:DeleteKey(newPostsKey)
  return newPosts, oldPostIDs

end


function config:GetRelatedFilters(filter)

	-- for each tag, get filters that also have that tag
	local tagIDs = {}
	for _,tagID in pairs(filter.requiredTagIDs) do
		table.insert(tagIDs, {id = tagID})
	end

	--print(to_json(tagIDs))
	local filterIDs = cache:GetFilterIDsByTags(tagIDs)
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
		for _,relatedTagID in pairs(relatedFilter.requiredTagIDs) do
			for _, filterTagID in pairs(filterIDs) do
				if relatedTagID == filterTagID then
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


function config:UpdateFilterPosts()

  local filter = self:GetJob('UpdateFilterTags')

  if not filter then
    return
  end
	print('got job ',filter.id)


	local ok, err
	local requiredTagIDs = filter.requiredTagIDs
	print(to_json(requiredTagIDs))
	local bannedTagIDs = filter.bannedTagIDs

	local newPosts, oldPostIDs = self:GetUpdatedFilterPosts(filter, requiredTagIDs, bannedTagIDs)

	--get new post scores
	for _, newPost in pairs(newPosts) do
		newPost.score = AverageTagScore(requiredTagIDs, newPost.tags)
	end

	--update all the affected posts so they remove/add themselves to filters
	for _,v in pairs(newPosts) do
		ok, err = worker:QueueJob('UpdatePostFilters', v.id)
		if not ok then
			return ok, err
		end
	end
	for _,v in pairs(oldPostIDs) do
		ok, err = worker:QueueJob('UpdatePostFilters', v)
		if not ok then
			return ok, err
		end
	end

	ok , err = redisWrite:AddPostsToFilter(filter, newPosts)
	if not ok then
		print('error adding posts to filter: ',err)
		return ok, err
	end

	ok, err = redisWrite:RemovePostsFromFilter(filter.id, oldPostIDs)
	if not ok then
		print(ok, err)
		return ok, err
	end

	local relatedFilters = self:GetRelatedFilters(filter)
	ok, err = redisWrite:UpdateRelatedFilters(filter, relatedFilters)
	if not ok then
		print(ok, err)
	end


end




return config
