
local cache = require 'api.cache'
local util = require 'util'
local api = {}
local tinsert = table.insert




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

	local filter, err = self:UserCanEditFilter(userID, filterID)
	if not filter then
		return filter, err
	end

	banInfo.bannedAt = ngx.time()
	return worker:FilterBanUser(filterID, banInfo)
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

	local newTag = self:CreateTag(userID, tagName)
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

	ok, err = worker:QueueJob('UpdatePostFilters', post.name)
	if not ok then
		return ok, err
	end

	ok, err = worker:UpdatePostTags(post)
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

	local newTag = self:CreateTag(userID, tagName)

	for _,postTag in pairs(post.tags) do
		if postTag.name == newTag.name then
			return nil, 'tag already exists'
		end
	end

	newTag.up = 100
	newTag.down = 0
	newTag.score = self:GetScore(newTag.up, newTag.down)
	newTag.active = true
	newTag.createdBy = userID

	tinsert(post.tags, newTag)

	ok, err = worker:QueueJob('UpdatePostFilters', post.id)
	if not ok then
		return ok, err
	end

	ok, err = worker:UpdatePostTags(post)
	return ok, err
end



function api:FilterUnbanUser(filterID, userID)
	local ok, err = self:UserCanEditFilter(userID, filterID)
	if not ok then
		return ok, err
	end

	return worker:FilterUnbanUser(filterID, userID)
end

function api:FilterBanDomain(userID, filterID, banInfo)
	local ok, err = self:UserCanEditFilter(userID, filterID)
	if not ok then
		return ok, err
	end

	banInfo.bannedAt = ngx.time()
	banInfo.domainName = self:GetDomain(banInfo.domainName) or banInfo.domainName
	return worker:FilterBanDomain(filterID, banInfo)
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
	local filter, err = self:UserCanEditFilter(userID,filterID)
	if not filter then
		return filter, err
	end


	--generate actual tags
	local newrequiredTagNames, newbannedTagNames = {}, {}
	for k,v in pairs(requiredTagNames) do
		if v:gsub(' ', '') ~= '' then
			newrequiredTagNames[k] = self:CreateTag(userID, v).name
		end
	end
	for k,v in pairs(bannedTagNames) do
		if v ~= '' then
			newbannedTagNames[k] = self:CreateTag(userID, v).name
		end
	end


	print(to_json(newrequiredTagNames))
	local ok, err = worker:UpdateFilterTags(filter, newrequiredTagNames, newbannedTagNames)
	if not ok then
		return ok, err
	end

	ok, err = worker:LogChange(filter.id..'log', ngx.time(), {changedBy = userID, change= 'UpdateFilterTag'})
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

	domainName = self:GetDomain(domainName) or domainName
	return worker:FilterUnbanDomain(filterID, domainName)
end




return api
