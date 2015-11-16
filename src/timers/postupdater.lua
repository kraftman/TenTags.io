
local CONFIG_CHECK_INTERVAL = 5

local config = {}
config.__index = config
config.http = require 'lib.http'
config.cjson = require 'cjson'
local redisRead = require 'api.redisread'
local redisWrite = require 'api.rediswrite'
local cache = require 'api.cache'
local tinsert = table.insert
local TAG_BOUNDARY = 0.15
to_json = (require 'lapis.util').to_json
from_json = (require 'lapis.util').from_json

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

  local postID = redisRead:GetOldestJob('UpdatePostFilters')
  if not postID then
    return
  end
  print(to_json(postID))



  ok, err = redisWrite:DeleteJob('UpdatePostFilters',postID)
  if not ok then
    ngx.log(ngx.ERR, 'error deleting job: ',err)
    return
  end

  local post = redisRead:GetPost(postID)
  if not post then
    return
  end

  self:UpdatePostFilters(post)

end

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

function config:GetValidFilters(filterID, post)

	local filter = cache:GetFilterByID(filterID)
	if not filter then
		ngx.log(ngx.ERR,'filter not found: ',filterID)
		return nil
	end

	--rather than just checking they exist, also need to get
	-- all intersecting tags, and calculate an average score

	filter.score = AverageTagScore(filter.requiredTags, post.tags)

	if (filter.bannedUsers[post.createdBy]) then
		ngx.log(ngx.ERR, 'ignoring filter: ',filter.id,' as user: ',post.createdBy, ' is banned')
		return nil
	elseif filter.bannedDomains[post.domain] then
		ngx.log(ngx.ERR, 'ignoring filter: ',filter.id,' as domain ',post.domain, ' is banned ' )
		return nil
	end
	return filter
end


function config:CalculatePostFilters(post)
	-- get all the filters that care about this posts' tags

	-- only include tags above threshold
	local validTags = {}
  print(to_json(post))
	for _, tag in pairs(post.tags) do
		if tag.score > TAG_BOUNDARY then
			tinsert(validTags, tag)
		end
	end
	print('valid tags: '..to_json(validTags))
	local filterIDs = cache:GetFilterIDsByTags(validTags)
	print('filters by tags: '..to_json(filterIDs))
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

function config:UpdatePostFilters(post)
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

	local ok, err = redisWrite:RemovePostFromFilters(post.id, purgeFilterIDs)
	if not ok then
		return ok, err
	end
	ok, err = redisWrite:AddPostToFilters(post, newFilters)
	if not ok then
		return ok, err
	end

	post.filters = newFilters
	return
end



return config
