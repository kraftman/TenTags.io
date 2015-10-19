--[[
  access control
  rate limitting
  business logic
]]

local cache = require 'api.cache'
local api = {}
local uuid = require 'lib.uuid'
local worker = require 'api.worker'
local tinsert = table.insert
local trim = (require 'lapis.util').trim
local scrypt = require 'lib.scrypt'
local salt = 'poopants'

--self.session.current_user


function api:SanitiseHTML(str)
	local html = {
		["<"] = "&lt;",
		[">"] = "&gt;",
		["&"] = "&amp;",
	}
	return string.gsub(tostring(str), "[<>&]", function(char)
		return html[char] or char
	end)
end

function api:GetUserFilters(userID)
  if not userID then
    userID = 'default'
  end
  local filterIDs = cache:GetUserFilterIDs(userID)

  return cache:GetFilterInfo(filterIDs)
end

function api:GetPostComments(postID)
  return cache:GetPostComments(postID)
end

function api:GetComment(postID, commentID)
  return cache:GetComment(postID, commentID)
end

function api:GetThread(threadID)
  return cache:GetThread(threadID)
end

function api:UserHasAlerts(userID)
  local alerts = cache:GetUserAlerts(userID)
  --ngx.log(ngx.ERR, #alerts)
  return #alerts > 0
end


function api:GetUserAlerts(userID)
  local alerts = cache:GetUserAlerts(userID)
  -- need to also update the users lastcheckedAt
  -- both in redis and the cache (when it caches)

  return alerts
end

function api:UpdateLastUserAlertCheck(userID)
  return worker:UpdateLastUserAlertCheck(userID)
end

function api:CreateMessageReply(messageInfo)
  -- TODO: validate message info
  messageInfo.id = uuid.generate_random()
  messageInfo.createdAt = ngx.time()
  worker:CreateMessage(messageInfo)

  local thread = cache:GetThread(messageInfo.threadID)
  for _,userID in pairs(thread.viewers) do
    if userID ~= messageInfo.createdBy then
      ngx.log(ngx.ERR,'adding alert for user: ',userID)
      worker:AddUserAlert(userID, 'thread:'..thread.id..':'..messageInfo.id)
    end
  end

end

function api:CreateThread(messageInfo)
  local recipientID = cache:GetUserID(messageInfo.recipient)
  ngx.log(ngx.ERR,'recipientID ',recipientID)

  local thread = {
    id = uuid.generate_random(),
    createdBy = messageInfo.createdBy,
    createdAt = ngx.time(),
    title = messageInfo.title,
    viewers = {messageInfo.createdBy,recipientID},
    lastUpdated = ngx.time()

  }

  local msg = {
    id = uuid.generate_random(),
    createdBy = messageInfo.createdBy,
    body = messageInfo.body,
    createdAt = ngx.time(),
    threadID = thread.id
  }

  worker:CreateThread(thread)
  worker:CreateMessage(msg)
  worker:AddUserAlert(recipientID, 'thread:'..thread.id..':'..msg.id)

end

function api:GetThreads(userID)
  return cache:GetThreads(userID)
end

function api:SubscribeComment(userID, postID, commentID)
  local comment = cache:GetComment(postID, commentID)
  -- check they dont exist
  for k, v in pairs(comment.viewers) do
    if v == userID then
      return
    end
  end
  tinsert(comment.viewers, userID)
  worker:ent(comment)
end


function api:GetUserComments(username)

  local userID = cache:GetUserID(username)
  if not userID then
    ngx.log(ngx.ERR, 'couldnt find user!')
    return {}
  end

  ngx.log(ngx.ERR, 'userID:',to_json(userID))
  local comments = cache:GetUserComments(userID)
  return comments
end

function api:CreateComment(commentInfo)

  commentInfo.id = uuid.generate_random()
  commentInfo.createdAt = ngx.time()
  commentInfo.up = 1
  commentInfo.down = 0
  commentInfo.score = 0
  commentInfo.viewers = {commentInfo.createdBy}
  commentInfo.text = self:SanitiseHTML(commentInfo.text)

  local filters = {}
  local postFilters = self:GetPost(commentInfo.postID).filters
  ngx.log(ngx.ERR, to_json(postFilters))
  local userFilters = self:GetUserFilters(commentInfo.createdBy)

  for _,userFilter in pairs(userFilters) do
    for _,postFilterID in pairs(postFilters) do
      print(to_json(userFilter.id), to_json(postFilterID))
      if userFilter.id == postFilterID then
        print('test', to_json(userFilter))
        tinsert(filters, userFilter)
      end
    end
  end
  commentInfo.filters = filters

   worker:CreateComment(commentInfo)
  -- need to add alert to all parent comment viewers
  if commentInfo.parentID == commentInfo.postID then
    -- whole other kettle of fish
  else
    local parentComment = self:GetComment(commentInfo.postID, commentInfo.parentID)
    for _,userID in pairs(parentComment.viewers) do
      worker:AddUserAlert(userID, 'postComment:'..commentInfo.postID..':'..commentInfo.id)
    end
  end


 --need to add comment to comments, commentid to user

 -- also increment post comment count
end

function api:GetPost(postID)
  return cache:GetPost(postID)
end

function api:GetDefaultFrontPage(range,filter)
  range = range or 0
  filter = filter or 'fresh'
  return cache:GetDefaultFrontPage(range,filter)
end

function api:GetFilterPosts(filterName,username,offset,sort)

  -- get large list of posts that match the user filter
  -- load the


  offset = offset or 0
  --sort = sort or 'fresh'
  if not sort or filterName then
    print('no sort')
  end

  --local filterPosts = cache:GetFilterPosts(filterName,username,offset,sort)



  local userSeenPosts = cache:GetUserSeenPosts(username) or {}
  local userFilters = cache:GetIndexedUserFilterIDs(username)

  local finalPosts = {}
  local unfilteredPosts
  local unfilteredOffset = 0

  local postID, filterID
  local postInfo

  local finalPostIDs = {}

  while #finalPostIDs < offset + 10 do
    unfilteredPosts = cache:GetMorePosts(unfilteredOffset,unfilteredOffset+1000)

    for _,v in pairs(unfilteredPosts) do
      filterID,postID = v:match('(%w+):(%w+)')
      if userFilters[filterID] then
        postInfo = cache:GetPost(postID)
        if not userSeenPosts[postInfo.nodeID] then
          tinsert(finalPosts, postInfo)
          userSeenPosts[postInfo.nodeID] = true
        end
      end
    end
  end

  if username ~= 'default' then
    cache:UpdateUserSeenPosts(username,userSeenPosts)
    worker:UpdateUserSeenPosts(username,userSeenPosts)
  end

  return finalPosts

end

function api:SubscribeToFilter(userID,filterID)

  local filterIDs = cache:GetUserFilterIDs(userID)

  for _, v in pairs(filterIDs) do
    if v == filterID then
      -- they are already subbed
      return
    end
  end

  worker:SubscribeToFilter(userID,filterID)

end

function api:GetUserInfo(userID)
  return cache:GetUserInfo(userID)
end

function api:ValidateMaster(userCredentials)
  local masterInfo = cache:GetMasterUserByEmail(userCredentials.email)

  if not masterInfo then
    return
  end

  if masterInfo.active == 0 then
    return nil,true
  end

  local valid = scrypt.check(userCredentials.password,masterInfo.passwordHash)
  if valid then
    masterInfo.passwordHash = nil
    return masterInfo
  end

end

function api:CreateActivationKey(masterInfo)
  local key = ngx.md5(masterInfo.id..masterInfo.email..salt)
  return key:match('.+(........)$')
end

function api:ActivateAccount(email, key)
  email = email and email:lower() or ''
  if email == '' then
    return nil, 'email is blank!'
  end

  local userInfo = cache:GetMasterUserByEmail(email)
  if not userInfo then
    return nil, 'could not find account with this email'
  end

  local realKey = self:CreateActivationKey(userInfo)
  if key == realKey then
    --cache:UpdateUserInfo(userInfo)
    worker:ActivateAccount(userInfo.id)
    return true
  else
    return nil, 'activation key incorrect'
  end
end

function api:GetUserFrontPage(userID,filter,range)
  return cache:GetUserFrontPage(userID,filter,range)
end

function api:FlushAllPosts()
  return worker:FlushAllPosts()
end


function api:CreateSubUser(masterID, username)

  local subUser = {
    id = uuid.generate(),
    username = username,
    filters = cache:GetUserFilterIDs('default'),
    parentID = masterID
  }
  local master = cache:GetMasterUserInfo(masterID)
  tinsert(master.users,subUser.id)

  worker:CreateMasterUser(master)

  return worker:CreateSubUser(subUser)


  -- need to update master info with list of sub users

end

function api:GetMasterUsers(masterID)
  local master = cache:GetMasterUserInfo(masterID)
  local users = {}
  local user
  for _, userID in pairs(master.users) do
      user = cache:GetUserInfo(userID)
      if user then
        tinsert(users, user)
      end
  end
  return users
end


function api:CreateMasterUser(confirmURL, userInfo)
  userInfo.username = userInfo.username and userInfo.username:lower() or ''
  userInfo.password = userInfo.password and userInfo.password:lower() or ''
  userInfo.email = userInfo.email and userInfo.email:lower() or ''

  if trim(userInfo.username) == '' then
    return nil, 'no username provided!'
  elseif trim(userInfo.email) == '' then
    return nil, 'no email provided!'
  elseif trim(userInfo.password) == '' then
    return nil, 'no password provided!'
  end

  local masterInfo = {
    email = userInfo.email,
    passwordHash = scrypt.crypt(userInfo.password),
    id = uuid.generate_random(),
    active = 0,
    userCount = 1,
    users = {}
  }

  local firstUser = {
    id = uuid.generate_random(),
    username = userInfo.username,
    filters = cache:GetUserFilterIDs('default'),
    parentID = masterInfo.id
  }

  tinsert(masterInfo.users,firstUser.id)
  masterInfo.currentUserID = firstUser.id

  local activateKey = self:CreateActivationKey(masterInfo)
  local url = confirmURL..'?email='..userInfo.email..'&activateKey='..activateKey
  worker:SendActivationEmail(url, userInfo.email)
  worker:CreateMasterUser(masterInfo)
  worker:CreateSubUser(firstUser)
  return true

end

function api:UnsubscribeFromFilter(username,filterID)
  local filterIDs = cache:GetUserFilterIDs(username)
  local found = false
  for _,v in pairs(filterIDs) do
    if v == filterID then
      found = true
    end
  end
  if not found then
    -- no need to unsubscribe
    return
  end

  worker:UnsubscribeFromFilter(username,filterID)

end

function api:CreateTag(tagName,createdBy)
  --check if the tag already exists
  -- create it
  if tagName:gsub(' ','') == '' then
    return nil
  end

  local tag = cache:GetTag(tagName)
  if tag then
    return tag
  end

  local tagInfo = {
    id = uuid.generate_random(),
    createdAt = ngx.time(),
    createdBy = createdBy,
    name = tagName
  }

  worker:CreateTag(tagInfo)
  return tagInfo
end

function api:PostIsValid(postInfo)

  return postInfo
end

function api:CreatePost(postInfo)
  -- rate limit
  -- basic sanity check
  -- send to worker
  if not api:PostIsValid(postInfo) then
    return false
  end

  postInfo.id = uuid.generate()
  postInfo.parentID = postInfo.id
  postInfo.createdBy = postInfo.createdBy or 'default'
  postInfo.commentCount = 0
  postInfo.score = 0

  if not postInfo or trim(postInfo.link) == '' then
    tinsert(postInfo.tags,'self')
  end

  for k,v in pairs(postInfo.tags) do

    v = trim(v:lower())
    postInfo.tags[k] = self:CreateTag(v,postInfo.createdBy)

    if postInfo.tags[k] then
      postInfo.tags[k].up = 1
      postInfo.tags[k].down = 0
      postInfo.tags[k].score = 0
      postInfo.tags[k].active = true
    end
  end

  local filterIDs = cache:GetFilterIDsByTags(postInfo.tags)
  local chosenFilterIDs = {}
  -- add all the filters that want these tags
  for _,v in pairs(filterIDs) do
    for filterID,filterType in pairs(v) do
      if filterType == 'required' then
        chosenFilterIDs[filterID] = true
      end
    end
  end
  -- remove all the filters that dont want one of the tags
  for _,v in pairs(filterIDs) do
    for filterID,filterType in pairs(v) do
      if filterType == 'banned' then
        chosenFilterIDs[filterID] = nil
      end
    end
  end

  for k,_ in pairs(chosenFilterIDs) do
    chosenFilterIDs[k] = k
  end
  postInfo.filters = chosenFilterIDs
  --get the info from the filters to find out which tags they want
  local filtersWithInfo = cache:GetFilterInfo(chosenFilterIDs)
  local finalFilters = {}
  for _,filter in pairs(filtersWithInfo) do
    if self:TagsMatch(filter.requiredTags, postInfo.tags) then
      tinsert(finalFilters,filter)
    end
  end

  worker:AddPostToFilters(finalFilters,postInfo)
  worker:CreatePost(postInfo)
  return true
end

function api:TagsMatch(filterTags,postTags)
  local found
  for _,filterTagID in pairs(filterTags) do
    found = false
    for _,postTag in pairs(postTags) do
      if filterTagID == postTag.id then
        found = true
      end
    end
    if not found then
      return false
    end
  end
  return true
end

function api:FilterIsValid(filterInfo)
  return filterInfo
  -- lower case it
  -- check for invalid chars
  -- check it doesnt already exist
end

function api:GetFilterPosts(filter)
  return cache:GetFilterPosts(filter)
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

function api:CreateFilter(filterInfo)

  if not api:FilterIsValid(filterInfo) then
    return false
  end

  filterInfo.id = uuid.generate_random()
  filterInfo.name = filterInfo.name:lower()
  filterInfo.subs = 1

  local tags = {}

  for k,tagName in pairs(filterInfo.requiredTags) do
    local tag = self:CreateTag(tagName, filterInfo.createdBy)
    if tag then
      tag.filterID = filterInfo.id
      tag.filterType = 'required'
      tag.createdBy = filterInfo.createdBy
      tag.createdAt = filterInfo.createdAt
      tinsert(tags,tag)
      filterInfo.requiredTags[k] = tag
    else
      filterInfo.requiredTags[k] = nil
    end
  end

  for k,tagName in pairs(filterInfo.bannedTags) do
    local tag = self:CreateTag(tagName, filterInfo.createdBy)
    if tag then
      tag.filterID = filterInfo.id
      tag.filterType = 'banned'
      tag.createdBy = filterInfo.createdBy
      tag.createdAt = filterInfo.createdAt
      tinsert(tags,tag)
      filterInfo.bannedTags[k] = tag
    else
      --if its blank
      filterInfo.bannedTags[k] = nil
    end
  end
  filterInfo.tags = tags

  worker:CreateFilter(filterInfo)
  worker:SubscribeToFilter(filterInfo.createdBy, filterInfo.id)

  return true
end

function api.GetAllTags()
  return cache:GetAllTags()
end


return api
