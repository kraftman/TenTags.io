
local cache = require 'api.cache'
local util = require 'api.util'
local worker = require 'api.worker'
local uuid = require 'lib.uuid'
local tinsert = table.insert
local tagAPI = require 'api.tags'
local redisWrite = require 'api.rediswrite'
local userWrite = require 'api.userWrite'
local POST_TITLE_LENGTH = 100


local api = {}

local MAX_MOD_COUNT = 10


function api:GetFilters(filterIDs)
	local filters = {}
	for k,v in pairs(filterIDs) do
		table.insert(filters, cache:GetFilterByID(v))
	end
	return filters
end


function api:GetFilterInfo(filterIDs)
	return cache:GetFilterInfo(filterIDs)
end




function api:CreateFilter(userID, filterInfo)

	--[[
	MIN
	- RateLimit
	- check they are allowed to create more filters
	-

	]]

	local newFilter, err, ok

	ok, err = util.RateLimit('CreateFilter:', userID, 1, 600)
	if not ok then
		return ok, err
	end

	local user = cache:GetUser(userID)
	local account = cache:GetAccount(user.parentID)

	if (account.modCount >= MAX_MOD_COUNT) and (account.role ~= 'admin') then
		--return nil, 'you cant mod any more subs!'
	end

	account.modCount = account.modCount + 1
	userWrite:UpdateAccount(account)


	newFilter, err = self:ConvertUserFilterToFilter(userID, filterInfo)
	print(to_json(newFilter))
	if not newFilter then
		return newFilter, err
	end

	if type(filterInfo.requiredTagNames) ~= 'table' then
		return nil, 'required tags not provided'
	end

  for _,tagName in pairs(filterInfo.requiredTagNames) do
		tagName = util:SanitiseUserInput(tagName, 100)
    local tag = tagAPI:CreateTag(newFilter.createdBy,tagName)
		if tag then
			tinsert(newFilter.requiredTagNames, tag.name)
		end
  end

	if type(filterInfo.bannedTagNames) ~= 'table' then
		filterInfo.bannedTagNames = {}
	end

	table.insert(filterInfo.bannedTagNames, 'meta:filterban:'..newFilter.id)

  for _,tagName in pairs(filterInfo.bannedTagNames) do
    local tag = tagAPI:CreateTag(newFilter.createdBy,tagName)
		if tag then
    	tinsert(newFilter.bannedTagNames, tag.name)
		end
  end

	ok, err = redisWrite:CreateFilter(filterInfo)


	if not ok then
		return ok, err
	end

	-- auto add the owner to filter subscribers
	redisWrite:IncrementFilterSubs(filterInfo.id, 1)
  userWrite:SubscribeToFilter(userID, filterInfo.id)

	-- cant combine, due to other uses of function
	 ok, err = redisWrite:UpdateFilterTags(newFilter, newFilter.requiredTagNames, newFilter.bannedTagNames)
  if not ok then
    return ok, err
  end

  -- filter HAS to be updated firstUser
  -- or the job wont use the new tags

  ok,err = redisWrite:QueueJob('UpdateFilterTags',newFilter.id)
	if not ok then
		return ok,err
	end
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


	local newFilter = {
		id = uuid.generate_random(),
		name = util:SanitiseUserInput(userFilter.name, 30),
		description = util:SanitiseUserInput(userFilter.name, 2000),
		title = util:SanitiseUserInput(userFilter.name, 200),
		subs = 0,
		mods = {},
		requiredTagNames = {},
		bannedTagNames = {},
		ownerID = util:SanitiseUserInput(userFilter.ownerID,50),
		createdBy = util:SanitiseUserInput(userFilter.createdBy, 50),
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
	if not newModID then
		return nil, 'could not find user with that name'
	end

	-- check they arent there already
	-- check they can be made mod of this sub
	local newMod = cache:GetUser(newModID)
	local account = cache:GetAccount(newMod.parentID)
	print (account.modCount, account.role)
	if account.modCount >= MAX_MOD_COUNT and account.role ~= 'admin' then
		return nil, 'mod of too many filters'
	end

	account.modCount = account.modCount + 1
	userWrite:UpdateAccount(account)

	local modInfo = {
		id = newModID,
		createdAt = ngx.time(),
		createdBy = userID,
		up = 10,
		down = 0,
	}
	return redisWrite:AddMod(filterID, modInfo)

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
	userWrite:UpdateAccount(account)
	return redisWrite:DelMod(filterID, modID)

end


function api:UpdateFilterTitle(userID, filterID, newTitle)
	local ok, err = util.RateLimit('EditFilterTitle:', userID, 4, 120)
	if not ok then
		return ok, err
	end

	local filter = cache:GetFilterByID(filterID)
	if not filter then
		return nil, 'could not find filter'
	end

	if userID ~= filter.ownerID then
		local user = cache:GetUser(userID)
		if user.role ~= 'Admin' then
			return nil, 'you must be admin or filter owner to do that'
		end
	end

	filter.title = self:SanitiseUserInput(newTitle, POST_TITLE_LENGTH)

	return redisWrite:UpdateFilterTitle(filter)

end



function api:UpdateFilterDescription(userID, filterID, newDescription)
	local ok, err = util.RateLimit('EditFilter:', userID, 4, 120)
	if not ok then
		return ok, err
	end

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

	return redisWrite:UpdateFilterDescription(filter)

end


function api:SearchFilters(userID, searchString)
	local ok, err = util.RateLimit('SearchFilters:',userID, 20, 10)
	if not ok then
		return ok, err
	end
	searchString = self:SanitiseUserInput(searchString, 100)
	searchString = searchString:lower()
	if searchString:len() < 2 then
		return nil, 'string too short'
	end
	local ok, err = cache:SearchFilters(searchString)
	return ok,err
end


function api:FilterBanUser(userID, filterID, banInfo)

	local ok, err = util.RateLimit('FilterBanUser:',userID, 5, 10)
	if not ok then
		return ok, err
	end

	local filter, err = self:UserCanEditFilter(userID, filterID)
	if not filter then
		return filter, err
	end

	banInfo.bannedAt = ngx.time()
	return redisWrite:FilterBanUser(filterID, banInfo)
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

	ok, err = redisWrite:QueueJob('UpdatePostFilters', post.name)
	if not ok then
		return ok, err
	end

	ok, err = rediswrite:UpdatePostTags(post)
	return ok, err

end

function api:FilterBanPost(userID, filterID, postID)

	local ok, err = self:UserCanEditFilter(userID, filterID)
	if not ok then
		return ok, err
	end

	local tagName = 'meta:filterban:'..filterID
	local post = cache:GetPost(postID)
	if not post then
		return nil, 'post not found'
	end

	local newTag = tagAPI:CreateTag(userID, tagName)

	for _,postTag in pairs(post.tags) do
		if postTag.name == newTag.name then
			return nil, 'tag already exists'
		end
	end

	newTag.up = 1000
	newTag.down = 0
	newTag.score = util:GetScore(newTag.up, newTag.down)
	newTag.active = true
	newTag.createdBy = userID

	tinsert(post.tags, newTag)

	ok, err = redisWrite:QueueJob('UpdatePostFilters', post.id)
	if not ok then
		return ok, err
	end

	ok, err = redisWrite:UpdatePostTags(post)
	return ok, err
end



function api:FilterUnbanUser(filterID, userID)
	local ok, err = self:UserCanEditFilter(userID, filterID)
	if not ok then
		return ok, err
	end

	return redisWrite:FilterUnbanUser(filterID, userID)
end

function api:FilterBanDomain(userID, filterID, banInfo)
	local ok, err = self:UserCanEditFilter(userID, filterID)
	if not ok then
		return ok, err
	end

	banInfo.bannedAt = ngx.time()
	banInfo.domainName = util:GetDomain(banInfo.domainName) or banInfo.domainName
	return redisWrite:FilterBanDomain(filterID, banInfo)
end


function api:GetFilterPosts(userID, filter, sortBy)
  return cache:GetFilterPosts(userID, filter, sortBy)
end

function api:GetFilterByName(filterName)
  return cache:GetFilterByName(filterName)
end

function api:GetFiltersBySubs(offset,count)
  offset = offset or 0
  count = count or 10
  local filters = cache:GetFiltersBySubs(offset,count)
  return filters
end


function api:UpdateFilterTags(userID, filterID, requiredTagNames, bannedTagNames)
	--print('updating filter tags')
	--print(to_json(requiredTagNames))

	if not filterID then
		return nil, 'no filter id!'
	end
	local filter, ok, err
	filter, err = self:UserCanEditFilter(userID,filterID)
	if not filter then
		return filter, err
	end


	--generate actual tags
	local newrequiredTagNames, newbannedTagNames = {}, {}
	for k,v in pairs(requiredTagNames) do
		if v:gsub(' ', '') ~= '' then
			newrequiredTagNames[k] = tagAPI:CreateTag(userID, v).name
		end
	end
	for k,v in pairs(bannedTagNames) do
		if v ~= '' then
			newbannedTagNames[k] = tagAPI:CreateTag(userID, v).name
		end
	end



	ok, err = redisWrite:UpdateFilterTags(filter, newrequiredTagNames, newbannedTagNames)
	if not ok then
		return ok, err
	end

	ok, err = redisWrite:LogChange(filter.id..'log', ngx.time(), {changedBy = userID, change= 'UpdateFilterTag'})
	if not ok then
		return ok,err
	end

	return true

end

function api:FilterUnbanDomain(userID, filterID, domainName)
	local ok, err = self:UserCanEditFilter(userID, filterID)
	if not ok then
		return ok, err
	end

	domainName = util:GetDomain(domainName) or domainName
	return redisWrite:FilterUnbanDomain(filterID, domainName)
end




return api
