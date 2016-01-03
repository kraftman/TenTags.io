
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
local to_json = (require 'lapis.util').to_json
local SEED = 1

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
  self:UpdatePostShortURL()
  self:UpdatePostFilters()

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
  --print(to_json(post))
	for _, tag in pairs(post.tags) do
		if tag.score > TAG_BOUNDARY then
			tinsert(validTags, tag)
		end
	end

	local filterIDs = cache:GetFilterIDsByTags(validTags)

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

function config:GetJob(jobName)
  local postID = redisRead:GetOldestJob(jobName)
  if not postID then
    return
  end

  local ok, err = redisWrite:DeleteJob(jobName,postID)
  print(to_json(ok))
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

function config:CreateShortURL()
  local urlChars = 'abcdefghjkmnopqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789'
  SEED = SEED + 1
  math.randomseed(ngx.time()+ngx.worker.pid()+SEED)
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
    shortURL = self:CreateShortURL()
    ok, err = redisWrite:SetNX('pURL:'..shortURL, postID)
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

  ngx.log(ngx.ERR, 'successfully added shortURL for postID ', postID,' shortURL: ',shortURL)

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
	local purgeFilterIDs = {}

  print(to_json(post.filters))
	for _,filterID in pairs(post.filters) do
		if not newFilters[filterID] then
			purgeFilterIDs[filterID] = filterID
		end
	end

  print('removing from: '..to_json(purgeFilterIDs))
  print('adding to: '..to_json(newFilters))

	local ok, err = redisWrite:RemovePostFromFilters(post.id, purgeFilterIDs)
	if not ok then
		return ok, err
	end
	ok, err = redisWrite:AddPostToFilters(post, newFilters)
	if not ok then
		return ok, err
	end

	post.filters = newFilters
  post.filters = {}
  for _,filter in pairs(newFilters) do
    tinsert(post.filters,filter.id)
  end

  redisWrite:CreatePost(post)
	return
end



return config
