

local app_helpers = require("lapis.application")
local capture_errors, assert_error = app_helpers.capture_errors, app_helpers.assert_error


local cache = require 'api.cache'
local uuid = require 'lib.uuid'
local tinsert = table.insert
local tagAPI = require 'api.tags'
local userAPI = require 'api.users'
local POST_TITLE_LENGTH = 100


local base = require 'api.base'
local api = setmetatable({}, base)

local MAX_MOD_COUNT = 10


function api:GetFilters(filterIDs)
	local filters = {}
	for _,v in pairs(filterIDs) do
		table.insert(filters, cache:GetFilterByID(v))
	end
	return filters
end


function api:GetFilterInfo(filterIDs)
	return cache:GetFilterInfo(filterIDs)
end

function api:CreateFilter(userID, filterInfo)

	local newFilter, err, ok


	local user = cache:GetUser(userID)
	local account = cache:GetAccount(user.parentID)

	if (account.modCount >= MAX_MOD_COUNT) and (account.role ~= 'Admin') then
		return nil, 'you cant mod any more subs!'
	end

	account.modCount = account.modCount + 1
	assert_error(self:InvalidateKey('account', account.id))

	assert_error(self.userWrite:CreateAccount(account))


	newFilter = assert_error(self:ConvertUserFilterToFilter(userID, filterInfo))



	if type(filterInfo.requiredTagNames) ~= 'table' then
		return nil, 'required tags not provided'
	end


  for _,tagName in pairs(filterInfo.requiredTagNames) do
		tagName = self:SanitiseUserInput(tagName, 100)
    local tag = assert(tagAPI:CreateTag(newFilter.createdBy,tagName))
		if tag then
			tinsert(newFilter.requiredTagNames, tag.name)
		end
  end
	if #newFilter.requiredTagNames < 1 then
		print('not enough tags')
		return nil, 'not enough tags'
	end

	if type(filterInfo.bannedTagNames) ~= 'table' then
		filterInfo.bannedTagNames = {}
	end
	table.insert(filterInfo.bannedTagNames, 'meta:filterban:'..newFilter.id)

  for _,tagName in pairs(filterInfo.bannedTagNames) do
    local tag = assert_error(tagAPI:CreateTag(newFilter.createdBy,tagName))
		if tag then
    	tinsert(newFilter.bannedTagNames, tag.name)
		end
  end

	ok, err = assert_error(self.redisWrite:CreateFilter(newFilter))

	if not ok then
		return ok, err
	end

	-- auto add the owner to filter subscribers
	assert_error(self.redisWrite:IncrementFilterSubs(newFilter.id, 1))
  assert_error(self.userWrite:ToggleFilterSubscription(userID, newFilter.id,true))

	assert_error(self.userWrite:IncrementUserStat(userID, 'FiltersCreated', 1))
	assert_error(self.redisWrite:IncrementSiteStat(userID, 'FiltersCreated', 1))
	assert_error(self:InvalidateKey('userfilter', userID))

	-- cant combine, due to other uses of function
	 assert_error(self.redisWrite:UpdateFilterTags(newFilter, newFilter.requiredTagNames, newFilter.bannedTagNames))


  -- filter HAS to be updated first
  -- or the job wont use the new tags

  assert_error(self.redisWrite:QueueJob('UpdateFilterPosts',{id = newFilter.id}))

  return newFilter
end



function api:ConvertUserFilterToFilter(userID, userFilter)
	userFilter.createdBy = userFilter.createdBy or userID
	if userID ~= userFilter.createdBy then
		local user = cache:GetUser(userID)
		if user.role ~= 'Admin' then
			userFilter.createdBy = userID
		end
	end

	userFilter.name = userFilter.name:gsub(' ','')
	userFilter.name = userFilter.name:gsub('%W','')
	if userFilter.name == '' then
		return nil, 'filter name cannot be blank or special characters'
	end

	userFilter.name = userFilter.name:lower()
	if(#userFilter.name < 2 ) then
		return nil, 'filter name is too short'
	end
	if(#userFilter.name > 30 ) then
		return nil, 'filter name is too long'
	end

	local newFilter = {
		id = uuid.generate_random(),
		name = self:SanitiseUserInput(userFilter.name, 30),
		description = self:SanitiseUserInput(userFilter.name, 2000),
		title = self:SanitiseUserInput(userFilter.name, 200),
		subs = 0,
		mods = {},
		requiredTagNames = {},
		bannedTagNames = {},
		ownerID = self:SanitiseUserInput(userFilter.ownerID or userFilter.createdBy,50),
		createdBy = self:SanitiseUserInput(userFilter.createdBy, 50),
		createdAt = ngx.time()
	}

	local existingFilter = cache:GetFilterByName(newFilter.name)
	if existingFilter then
		return nil, 'filter name is taken'
	end

	return newFilter
end


function api:AddMod(userID, filterID, newModName)
	local filter = cache:GetFilterByID(filterID)

	if userID ~= filter.ownerID then
		local user = cache:GetUser(userID)
		if user.role ~= 'Admin' then
			return nil, 'you must be admin or filter owner to add mods'
		end
	end


	local newModID = cache:GetUserID(newModName)

	-- check they arent there already
	-- check they can be made mod of this sub
	local newMod = cache:GetUser(newModID)
	local account = cache:GetAccount(newMod.parentID)

	if account.modCount >= MAX_MOD_COUNT and account.role ~= 'admin' then
		return nil, 'mod of too many filters'
	end

	account.modCount = account.modCount + 1

	assert_error(self:InvalidateKey('account', account.id))
	assert_error(self:InvalidateKey('filter', filter.id))
	assert_error(self.userWrite:CreateAccount(account))

	local modInfo = {
		id = newModID,
		createdAt = ngx.time(),
		createdBy = userID,
		up = 10,
		down = 0,
	}
	return assert_error(self.redisWrite:AddMod(filterID, modInfo))

end

function api:DelMod(userID, filterID, modID)

	local filter = cache:GetFilterByID(filterID)
	if not filter.ownerID == userID then
		local user = cache:GetUser(userID)
		if not user.role ~= 'Admin' then
			return nil, 'you must be admin or filter owner to remove mods'
		end
	end

	local found
	for _,mod in pairs(filter.mods) do
		if mod.id == userID then
			found = true
			break
		end
	end

	if not found then
		return nil, 'user is not a mod of this filter'
	end
	local user = cache:GetUser(modID)
	local account = cache:GetAccount(user.parentID)
	account.modCount = account.modCount - 1

	self:InvalidateKey('account', account.id)
	self:InvalidateKey('filter', filter.id)
	assert_error(self.userWrite:CreateAccount(account))
	return assert_error(self.redisWrite:DelMod(filterID, modID))

end


function api:UpdateFilterTitle(userID, filterID, newTitle)
	local filter = cache:GetFilterByID(filterID)
	if userID ~= filter.ownerID then
		local user = cache:GetUser(userID)
		if user.role ~= 'Admin' then
			return nil, 'you must be admin or filter owner to do that'
		end
	end

	filter.title = self:SanitiseUserInput(newTitle, POST_TITLE_LENGTH)

	self.redisWrite:UpdateFilterTitle(filter)
	return self:InvalidateKey('filter', filter.id)

end



function api:UpdateFilterDescription(userID, filterID, newDescription)

	local filter = cache:GetFilterByID(filterID)
	if not filter then
		return nil, 'could not find filter'
	end

	if userID ~= filter.ownerID then
		local user = cache:GetUser(userID)
		if user.role ~= 'Admin' then
			return nil, 'you must be admin or filter owner to add mods'
		end
	end

	filter.description = self:SanitiseUserInput(newDescription, 2000)

	ok, err =  self.redisWrite:UpdateFilterDescription(filter)
	if not ok then
		return ok, err
	end
	ok,err = self:InvalidateKey('filter', filter.id)
	return ok, err
end


function api:SearchFilters(userID, searchString)

	searchString = self:SanitiseUserInput(searchString, 100)
	searchString = searchString:lower()
	if searchString:len() < 2 then
		return nil, 'string too short'
	end
	ok, err = cache:SearchFilters(searchString)
	if not ok then
		ngx.log(ngx.ERR, 'error loading filters: ', err)
		return nil, 'search failed'
	end
	return ok
end

function api:UserCanEditFilter(userID, filterID)
	local user = cache:GetUser(userID)

	if not user then
		return nil, 'userID not found'
	end

	local filter = cache:GetFilterByID(filterID)
	if user.role == 'Admin' then
		return filter
	end

	if filter.ownerID == userID then
		return filter
	end

	for _,mod in pairs(filter.mods) do
		if mod.id == userID then
			return filter
		end
	end

	return nil, 'you must be admin or mod to edit filters'
end

function api:FilterBanUser(userID, filterID, banInfo)
	local ok, err, filter


	filter, err = self:UserCanEditFilter(userID, filterID)
	if not filter then
		return filter, err
	end

	banInfo.bannedAt = ngx.time()
	ok, err = self.redisWrite:FilterBanUser(filterID, banInfo)
	if not ok then
		return ok, err
	end
	ok, err = self:InvalidateKey('filter', filter.id)
	return ok, err
end

function api:FilterUnbanPost(userID, filterID, postID)
	local ok, err = self:UserCanEditFilter(userID, filterID)
	if not ok then
		return ok, err
	end


	local tagName = 'meta:filterban:'..filterID
	local post = cache:GetPost(postID)
	if not post then
		return nil, 'post doesnt exist'
	end

	local newTag = tagAPI:CreateTag(userID, tagName)
	local found = false
	for _,postTag in pairs(post.tags) do
		if postTag.name == newTag.name then
			found = true
			break
		end
	end
	if not found then
		return nil, 'not banned'
	end


	newTag.up = 0
	newTag.down = -100
	newTag.score = self:GetScore(newTag.up, newTag.down)
	newTag.active = true

	assert_error(self.redisWrite:QueueJob('UpdatePostFilters', {id = postID}))

	return assert_error(self.redisWrite:UpdatePostTags(post))

end

function api:FilterBanPost(userID, filterID, postID)

	local ok, err = self:UserCanEditFilter(userID, filterID)

	local tagName = 'meta:filterban:'..filterID
	local post = cache:GetPost(postID)

	local newTag = tagAPI:CreateTag(userID, tagName)

	for _,postTag in pairs(post.tags) do
		if postTag.name == newTag.name then
			return nil, 'tag already exists'
		end
	end

	newTag.up = 1000
	newTag.down = 0
	newTag.score = self:GetScore(newTag.up, newTag.down)
	newTag.active = true
	newTag.createdBy = userID

	tinsert(post.tags, newTag)

	assert_error(self.redisWrite:QueueJob('UpdatePostFilters', {id = post.id}))
	return assert_error(self.redisWrite:UpdatePostTags(post))

end



function api:FilterUnbanUser(filterID, userID)
	assert_error(self:UserCanEditFilter(userID, filterID))
	assert_error(self.redisWrite:FilterUnbanUser(filterID, userID))
	assert_error(self:InvalidateKey('filter', filterID))
end

function api:FilterBanDomain(userID, filterID, banInfo)
	assert_error(self:UserCanEditFilter(userID, filterID))


	banInfo.bannedAt = ngx.time()
	banInfo.domainName = self:GetDomain(banInfo.domainName) or banInfo.domainName
	assert_error(self:InvalidateKey('filter', filterID))
	return assert_error(self.redisWrite:FilterBanDomain(filterID, banInfo))
end


function api:GetFilterPosts(userID, filter, sortBy, startAt, range)
	startAt = startAt or 0
	range = range or 10
  return cache:GetFilterPosts(userID, filter, sortBy, startAt, range)
end

function api:GetFilterByName(filterName)
  return cache:GetFilterByName(filterName)
end

function api:GetFiltersBySubs(offset,count)
  offset = offset or 0
  count = count or 10
  local filters = assert_error(cache:GetFiltersBySubs(offset,count))
  return filters
end


function api:UpdateFilterTags(userID, filterID, requiredTagNames, bannedTagNames)

	if not filterID then
		return nil, 'no filter id!'
	end
	local filter, ok, err
	filter, err = assert_error(self:UserCanEditFilter(userID,filterID))

	--generate actual tags
	local newrequiredTagNames, newbannedTagNames = {}, {}
	if type(requiredTagNames) == 'table' then
		for k,v in pairs(requiredTagNames) do
			if v:gsub(' ', '') ~= '' then
				newrequiredTagNames[k] = tagAPI:CreateTag(userID, v).name
			end
		end
	else
		table.insert(newrequiredTagNames, tagAPI:CreateTag(userID, requiredTagNames).name)
	end

	if type(bannedTagNames) == 'table' then
		for k,v in pairs(bannedTagNames) do
			if v ~= '' then
				newbannedTagNames[k] = tagAPI:CreateTag(userID, v).name
			end
		end
	else
		table.insert(newbannedTagNames, tagAPI:CreateTag(userID, bannedTagNames).name)
	end

	assert_error(self.redisWrite:UpdateFilterTags(filter, newrequiredTagNames, newbannedTagNames))
	assert_error(self.redisWrite:QueueJob('UpdateFilterPosts',{id = filter.id}))
	assert_error(self:InvalidateKey('filter', filterID))

	return assert_error(self.redisWrite:LogChange(filter.id..'log', ngx.time(), {changedBy = userID, change= 'UpdateFilterTag'}))
end

function api:FilterUnbanDomain(userID, filterID, domainName)
	assert_error(self:UserCanEditFilter(userID, filterID))

	domainName = self:GetDomain(domainName) or domainName
	return assert_error(self.redisWrite:FilterUnbanDomain(filterID, domainName))
end




return api
