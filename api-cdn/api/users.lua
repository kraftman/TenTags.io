
local cache = require 'api.cache'
local uuid = require 'lib.uuid'
local base = require 'api.base'
local api = setmetatable({}, base)
local tinsert = table.insert
local userlib = require 'lib.userlib'
local trim = (require 'lapis.util').trim

function api:UserCanVoteTag(userID, postID, tagName)
	if self:UserHasVotedTag(userID, postID, tagName) then
		local user = cache:GetUser(userID)
		if user.role ~= 'admin' then
			return false
		end
	end
	return true
end

function api:GetUserFrontPage(userID,filter,startAt, endAt)

  return cache:GetUserFrontPage(userID,filter,startAt, endAt)
end


function api:LabelUser(userID, targetUserID, label)

	local ok, err = self:RateLimit('UpdateUser:',userID, 1, 60)
	if not ok then
		return ok, err
	end

	ok, err = self.userWrite:LabelUser(userID, targetUserID, label)
	return ok, err

end


function api:UserHasVotedPost(userID, postID)
	-- can only see own
	local userPostVotes = cache:GetUserPostVotes(userID)
	return userPostVotes[postID]

end

function api:UserHasVotedTag(userID, postID, tagName)
	-- can only see own
	local userTagVotes = cache:GetUserTagVotes(userID)
	return userTagVotes[postID..':'..tagName]

end


function api:UnsubscribeFromFilter(userID, subscriberID,filterID)

	local ok, err = self:RateLimit('subscribefilter:',userID, 1, 60)
	if not ok then
		return ok, err
	end

	if userID ~= subscriberID then
		local user = cache:GetUser(userID)
		if user.role ~= 'Admin' then
			return nil, 'you must be admin to change another users subscriptions'
		end
	end

  local filterIDs = cache:GetUserFilterIDs(userID)
  local found = nil
  for _,v in pairs(filterIDs) do
    if v == filterID then
      found = true
    end
  end
  if not found then
    return
  end

	ok, err = self.redisWrite:IncrementFilterSubs(filterID, -1)
	if not ok then
		ngx.log(ngx.ERR, 'error incr filter subs: ', err)
	end

	ok, err = self.redisWrite:UnsubscribeFromFilter(userID,filterID)
	if not ok then
		ngx.log(ngx.ERR, 'error unsubbing user: ', err)
		return nil, 'error unsubbing'
	end

	return true

end




function api:SubscribeToFilter(userID, userToSubID, filterID)


	local ok, err = self:RateLimit('UpdateUser:',userID, 1, 60)
	if not ok then
		return ok, err
	end

  local filterIDs = cache:GetUserFilterIDs(userID)

	if userID ~= userToSubID then
		local user = cache:GetUser(userID)
		if user.role ~= 'Admin' then
			return nil, 'you must be admin to do that'
		end
	end


  for _, v in pairs(filterIDs) do
    if v == filterID then
      -- they are already subbed
      return nil, userToSubID..' is already subbed!'
    end
  end

  self.redisWrite:SubscribeToFilter(userToSubID,filterID)

end




function api:GetUser(userID)
	-- can only get own for now
	if not userID or userID == '' then
		return nil
	end

	local userInfo  = cache:GetUser(userID)

	return userInfo
end


function api:CreateSubUser(accountID, username)
	username = trim(username)
  local subUser = {
    id = uuid.generate(),
    username = self:SanitiseHTML(username,20),
    filters = cache:GetUserFilterIDs('default'),
    parentID = accountID,
    enablePM = 1
  }
	subUser.lowerUsername = subUser.username:lower()

	if #subUser.username < 3 then
		return nil, 'username too short'
	end

	local existingUserID = cache:GetUserID(subUser.username)
	if existingUserID then
		return nil, 'username is taken'
	end

	if userlib:IsReserved(subUser.lowerUsername) then
		return nil, 'username is taken'
	end

	--TODO limit number of subusers allowed

	local account = cache:GetAccount(accountID)
	tinsert(account.users, subUser.id)
	account.userCount = account.userCount + 1
	account.currentUsername = subUser.username
	account.currentUserID = subUser.id
	local ok, err = self.userWrite:CreateAccount(account)
	if not ok then
		return ok, err
	end

	ok, err = self.redisWrite:IncrementSiteStat('SubUsersCreated', 1)
	if not ok then
		ngx.log(ngx.ERR, 'couldnt set stat: ', err)
	end

	ok, err = self.userWrite:CreateSubUser(subUser)
	if ok then
		return subUser
	else
		return ok, err
	end
end

function api:GetAccount(userAccountID, targetAccountID)
	if userAccountID ~= targetAccountID then
		return nil, 'not available yet'
	end

	if not targetAccountID then
		return nil, 'no target accountID'
	end

	local account,err = cache:GetAccount(targetAccountID)
	return account, err

end

function api:GetAccountUsers(userAccountID, accountID)
	local userAccount = cache:GetAccount(userAccountID)

	if userAccount.role ~= 'Admin' and userAccountID ~= accountID then
		return nil, 'must be admin to view other users'
	end

	local queryAccount = cache:GetAccount(accountID)
	if not queryAccount then
		return nil, 'account not found'
	end

	local users = {}
	local subUser
  for _, subUserID in pairs(queryAccount.users) do
    subUser = cache:GetUser(subUserID)
    if subUser then
      tinsert(users, subUser)
    end
  end
  return users
end



function api:GetUserAlerts(userID)
	local ok, err = self:RateLimit('GetUserAlerts:',userID, 5, 10)
	if not ok then
		return ok, err
	end
	-- can only get their own
  local alerts = cache:GetUserAlerts(userID)

  return alerts
end

function api:UpdateLastUserAlertCheck(userID)
	local ok, err = self:RateLimit('UpdateUserAlertCheck:',userID, 5, 10)
	if not ok then
		return ok, err
	end
	-- can only edit their own
  return self.userWrite:UpdateLastUserAlertCheck(userID, ngx.time())
end



function api:SwitchUser(accountID, userID)
	local account = cache:GetAccount(accountID)
	local user = cache:GetUser(userID)

	if user.parentID ~= accountID and account.role ~= 'admin' then
		return nil, 'noooope'
	end

	account.currentUserID = user.id
	account.currentUsername = user.username

	local ok, err = self.userWrite:CreateAccount(account)
	if not ok then
		return ok, err
	end

	return user
end



function api:GetUserID(username)
	return cache:GetUserID(username)
end


function api:UpdateUser(userID, userToUpdate)
	local ok, err = self:RateLimit('UpdateUser:',userID, 3, 30)
	if not ok then
		return ok, err
	end

	if userID ~= userToUpdate.id then
		local user = cache:GetUser(userID)
		if user.role ~= 'Admin' then
			return nil, 'you must be admin to edit a users details'
		end
	end
	local userInfo = {
		id = userToUpdate.id,
		enablePM = userToUpdate.enablePM and 1 or 0,
		hideSeenPosts = tonumber(userToUpdate.hideSeenPosts) == 0 and 0 or 1,
		hideVotedPosts = tonumber(userToUpdate.hideVotedPosts) == 0 and 0 or 1,
		hideClickedPosts = tonumber(userToUpdate.hideClickedPosts) == 0 and 0 or 1,
		showNSFW = tonumber(userToUpdate.showNSFW) == 0 and 0 or 1,
		username = userToUpdate.username,
		bio = self:SanitiseUserInput(userToUpdate.bio, 1000)
	}

	for k,v in pairs(userToUpdate) do
		if k:find('^filterStyle:') then
			k = k:sub(1,100)
			userInfo[k] = v:sub(1,100)
		end
	end
	if (userID == userToUpdate) then
		self.userWrite:IncrementUserStat(userID, 'SettingsChanged',1)
	end

	return self.userWrite:CreateSubUser(userInfo)
end


function api:GetUserFilters(userID)
	-- can only get your own filters
  if not userID then
    userID = 'default'
  end
  local filterIDs = cache:GetUserFilterIDs(userID)
	--print(to_json(filterIDs))
	local filters = cache:GetFilterInfo(filterIDs)
	--print(to_json(filters))
	return filters
end


function api:GetUserSettings(userID)
	local ok, user, err

	ok, err = self:RateLimit('GetUserSettings', 5, 1)
	if not ok then
		return nil, err
	end
	if not userID or userID:gsub(' ', '') == '' then
		return nil, 'no userID given'
	end

	user, err = cache:GetUser(userID)
	return user, err

end


function api:UserHasAlerts(userID)
	--can only get your own alerts
  local alerts = cache:GetUserAlerts(userID)
  return #alerts > 0
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

return api
