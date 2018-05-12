
local app_helpers = require("lapis.application")
local capture_errors, assert_error = app_helpers.capture_errors, app_helpers.assert_error


local cache = require 'api.cache'
local uuid = require 'lib.uuid'
local base = require 'api.base'
local api = setmetatable({}, base)
local tinsert = table.insert
local userlib = require 'lib.userlib'
local trim = (require 'lapis.util').trim
local MAX_USER_VIEWS = 20

function api:UserCanVoteTag(userID, postID, tagName)
	if self:UserHasVotedTag(userID, postID, tagName) then
		local user = cache:GetUser(userID)
		if user.role ~= 'admin' then
			return false
		end
	end
	return true
end

function api:GetUserFrontPage(userID, viewID, sortBy, startAt, range)

	if sortBy == 'seen' then
		return cache:GetUserSeenPosts(userID, startAt, range)
	end

	local user = cache:GetUser(userID)

  return cache:GetUserFrontPage(userID, viewID, sortBy, startAt, range)

end


function api:GetRecentPostVotes(userID, targetUserID, direction)

	local user = cache:GetUser(userID)
	local targetUser = cache:GetUser(targetUserID)
	if not user or  not targetUser then
		return nil, 'user not found'
	end
	if  userID ~= targetUserID and user.role ~= 'Admin' then
		return nil, 'you cant view other users voted posts'
	end

	cache:GetRecentPostVotes(targetUserID,direction)
	cache:GetPosts(ok)
	return ok, err
end

function api:LabelUser(userID, targetUserID, label)

	return self.userWrite:LabelUser(userID, targetUserID, label)

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

function api:BlockUser(userID, userToBlockID)
	print(userID,' == ', userToBlockID)


	local user = cache:GetUser(userID)
	local found
	for i,v in ipairs(user.blockedUsers) do
		if v == userToBlockID then
			found = true
			table.remove(user.blockedUsers,i)
		end
	end
	if not found then
		table.insert(user.blockedUsers, userToBlockID)
	end

	self.userWrite:UpdateBlockedUsers(user)

	return self:InvalidateKey('user', userID)

end

function api:ToggleCommentSubscription(userID, userToSubToID)

	local user = cache:GetUser(userID)
	local userToSubTo = cache:GetUser(userToSubToID)
	if not userToSubTo then
		return nil, 'user not found'
	end

	if not userToSubTo.allowSubs then
		return nil, 'user does not allow subscriptions'
	end

	if userToSubTo.commentSubscribers[userID] then
		userToSubTo.commentSubscribers[userID] = nil
	else
		userToSubTo.commentSubscribers[userID] = userID
	end

	user.commentSubscriptions[userToSubToID] = userToSubTo.commentSubscribers[userID]

	self.userWrite:UpdateUserField(user.id, 'commentSubscriptions:', to_json(user.commentSubscriptions))
	self.userWrite:UpdateUserField(userToSubToID, 'commentSubscribers:', to_json(userToSubTo.commentSubscribers))
	self:InvalidateKey('user', userToSubToID)
	return self:InvalidateKey('user', userID)
end

function api:TogglePostSubscription(userID, userToSubToID)

	local user = cache:GetUser(userID)
	local userToSubTo = cache:GetUser(userToSubToID)
	if not userToSubTo then
		return nil, 'user not found'
	end

	if not userToSubTo.allowSubs then
		return nil, 'user does not allow subscriptions'
	end

	if userToSubTo.postSubscribers[userID] then
		userToSubTo.postSubscribers[userID] = nil
	else
		userToSubTo.postSubscribers[userID] = userID
	end

	user.postSubscriptions[userToSubToID] = userToSubTo.postSubscribers[userID]

	self.userWrite:UpdateUserField(user.id, 'postSubscriptions:', to_json(user.commentSubscriptions))
	self.userWrite:UpdateUserField(userToSubToID, 'postSubscribers:', to_json(userToSubTo.commentSubscribers))
	self:InvalidateKey('user', userToSubToID)
	return self:InvalidateKey('user', userID)

end

function api:DeleteUser(userID, username)

	local userToDeleteID = cache:GetUserID(username)

	if userID == userToDeleteID then
		return nil, 'cannot delete the current user, switch to delete'
	end

	local user = cache:GetUser(userID)

	local account = cache:GetAccount(user.parentID)

	-- check they can
	if user.role ~= 'Admin' then
		local found = false
		for _,id in pairs(account.users) do
			if id == userToDeleteID then
				found = true
				break
			end
		end
		if not found then
			return nil, 'must be admin to do that'
		end
	end

	for i = 1, #account.users do
		if account.users[i] == userToDeleteID then
			table.remove(account.users, i)
		end
	end
	account.userCount = account.userCount - 1
	self.userWrite:CreateAccount(account)

	self:InvalidateKey('account', account.id)


	local userToDelete = cache:GetUser(userToDeleteID)
	if not userToDelete then
		return nil, 'couldnt find user to delete'
	end
	return self.userWrite:DeleteUser(userToDeleteID, userToDelete.username)

end

function api:ToggleSavePost(userID,postID)

	local user = cache:GetUser(userID)

	local post = cache:GetPost(postID)

	local ok = self.userRead:SavedPostExists(userID, post.id)


	if tonumber(ok) == 1 then
		self.userWrite:RemoveSavedPost(userID, post.id)
	else
		self.userWrite:AddSavedPost(userID, post.id)
	end
	return self:InvalidateKey('user', userID)

end

function api:ToggleFilterSubscription(userID, userToUpdateID, filterID)

	local user = cache:GetUser(userID)
	if userID ~= userToUpdateID then
		if user.role ~= 'Admin' then
			print('not admin')
			return nil, 'no auth'
		end
	end

	-- if the view were updating is default
	if userToUpdateID == 'default' then
		if user.role ~= 'Admin' then
			return nil, 'no auth'
		end

		local view = cache:GetView('default')
		if not view then
			self:CreateDefaultView(userID)
			view = cache:GetView('default')
		end

		return self:ToggleViewFilter(view, filterID)
	end

	local view

	-- create a view if they have default
	if user.currentView == 'default' then
		local defaultView = cache:GetView('default')

		local ok = self:CreateView(userID, defaultView.filters)
			-- we're done, they have a new view, no need to toggle it
		return ok

	end


	view = cache:GetView(user.currentView)

	self:ToggleViewFilter(view, filterID)

	return self:InvalidateKey('userfilter', userToUpdateID)

end

function api:ToggleViewFilter(view, filterID)

	local subscribe = true
  for k, v in pairs(view.filters) do
    if v == filterID then
      -- they are already subbed
      subscribe = false
			view.filters [k] = nil
			break
    end
  end

	if subscribe then
		view.filters[#view.filters+1] = filterID
	end

	self.redisWrite:IncrementFilterSubs(filterID, subscribe and 1 or -1)
	self.redisWrite:CreateView(view)
	-- need to remove the view from the cache
	local ok, err = self:InvalidateKey('view', view.id)
  --ok, err = self.userWrite:ToggleFilterSubscription(userToSubID, filterID, subscribe)

	return ok, err
end




function api:GetUser(userID)
	-- can only get own for now
	if not userID or userID == '' then
		return nil
	end

	return cache:GetUser(userID)

end

--[[


need to have user -> view link


view:
- list of filters
- creation time
- createdBy
- name
- public?
- follower count


can we merge views?
admins  an edit views (default view)
can share view by making it public

user starts with default view
if they edit the view, they get their own
can they combine others views with their own? - no, but can save other peoples views
can views be named and shared? /v/kraftman/tech

list of views includes users + following
cant edit following
follows default

frontpages are calculated per view not per user


]]


function api:CreateView(userID, filters)

  -- check they arent at the limit
  local user = cache:GetUser(userID)
  if user.viewCount and user.viewCount > MAX_USER_VIEWS  then
    return nil, 'you have too many views, please unfollow one'
  end

  local newView = {

    id = uuid.generate(),
    createdBy = userID,
    createdAt = ngx.time(),
    filters = filters or {},
    public = false,
  }

  user.viewCount = user.viewCount + 1
  user.views[#user.views+1] = newView.id
	user.currentView = newView.id

  self.redisWrite:CreateView(newView)

  self.userWrite:CreateSubUser(user)
	return self:InvalidateKey('user', userID)

end

function api:CreateDefaultView(userID)
	local user = cache:GetUser(userID)
	if user.role ~= 'Admin' then
		return nil, 'must be admin'
	end

	local newView = {
		id = 'default',
		createdBy = userID,
		createdAt = ngx.time(),
		filters = {},
		public = true
	}

	return self.redisWrite:CreateView(newView)

end

function api:ToggleViewSubscription(userID, viewID)
	local user = self.cache:GetUser(userID)
	local view = self.cache:GetView(viewID)

	local found
	for k, v in pairs(user.views) do
		if v == viewID then
			found = true
			user.views[k] = nil

			break
		end
	end

	if found then
		view.subCount = view.subCount - 1
	else
		view.subCount = view.subCount + 1
		user.views[#user.views+1]= viewID
	end

	self.userWrite:CreateSubUser(user)


	return self.redisWrite:CreateView(view)


end



function api:CreateSubUser(accountID, username)
	username = trim(username)
  local subUser = {
    id = uuid.generate(),
    username = self:SanitiseHTML(username,20),
		views = {'default'},
		currentView = 'default',
    parentID = accountID,
    enablePM = 1,
		nsfwLevel = 0
  }
	subUser.lowerUsername = subUser.username:lower()


	if #subUser.username < 3 then
		return nil, 'username too short'
	end

	-- for k,v in pairs(subUser.filters) do
	-- 	self.userWrite:ToggleFilterSubscription(subUser.id,v,true)
	-- end

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
	self.userWrite:CreateAccount(account)


	self:InvalidateKey('account', account.id)
	if account.role == 'Admin' then
		subUser.role = 'Admin'
	end

	self.redisWrite:IncrementSiteStat('SubUsersCreated', 1)

	self.userWrite:CreateSubUser(subUser)

	return subUser

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
	local alerts

  alerts = cache:GetUserAlerts(userID)

	if alerts then
		self.userWrite:UpdateUserField(userID, 'alertCheck', ngx.time())
		self:InvalidateKey('user', userID)
	  self:InvalidateKey('useralert', userID)
	end

  return alerts
end

function api:SwitchUser(accountID, userID)
	local account = cache:GetAccount(accountID)
	local user = cache:GetUser(userID)

	if user.parentID ~= accountID and account.role ~= 'Admin' then
		return nil, 'noooope'
	end

	account.currentUserID = user.id
	account.currentUsername = user.username

	self.userWrite:CreateAccount(account)

	return self:InvalidateKey('account', account.id)

end



function api:GetUserID(username)
	return cache:GetUserID(username)
end


function api:UpdateUser(userID, userToUpdate)


	local user = cache:GetUser(userID)

	if user.role == 'Admin' then

	else
		userToUpdate.fakeNames = nil
		if userID ~= userToUpdate.id then
			return nil, 'you must be admin to edit a users details'
		end
	end


	local userInfo = {
		id = userToUpdate.id,
		enablePM = userToUpdate.enablePM and 1 or 0,
		allowSubs = userToUpdate.allowSubs and 1 or 0,
		hideSeenPosts = userToUpdate.hideSeenPosts and 1 or 0,
		hideUnsubbedComments = userToUpdate.hideUnsubbedComments and 1 or 0,
		hideVotedPosts = userToUpdate.hideVotedPosts and 1 or 0,
		hideClickedPosts = userToUpdate.hideClickedPosts and 1 or 0,
		nsfwLevel = userToUpdate.nsfwLevel,
		showNSFL = userToUpdate.showNSFL and 1 or 0,
		username = userToUpdate.username,
		bio = self:SanitiseUserInput(userToUpdate.bio, 1000),
		fakeNames = userToUpdate.fakeNames and 1 or 0
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

	self.userWrite:CreateSubUser(userInfo)
	return self:InvalidateKey('user', userID)

end


function api:GetUserFilters(userID)
	-- can only get your own filters
  if not userID then
    userID = 'default'
  end

	local user = cache:GetUser(userID)
	local viewID = user and user.currentView or 'default'

  local filterIDs = cache:GetViewFilterIDs(viewID)


	local filters = cache:GetFilterInfo(filterIDs)
	--print(to_json(filters))
	return filters
end

function api:GetIndexedViewFilterIDs(userID)
	print(userID)
	if userID == 'default' then
		return cache:GetIndexedViewFilterIDs('default')
	end

	local user, err = cache:GetUser(userID)
	if not user then
		print(userID)
		print('cant get users, ',err)
	end

	return cache:GetIndexedViewFilterIDs(user.currentView) or {}

end


function api:GetUserSettings(userID)

	if not userID or userID:gsub(' ', '') == '' then
		return nil, 'no userID given'
	end

  return cache:GetUser(userID)

end


function api:UserHasAlerts(userID)
	--can only get your own alerts
  local alerts = cache:GetUserAlerts(userID)
	if not alerts then
		return false
	end
  return #alerts > 0
end




return api
