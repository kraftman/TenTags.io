--[[
  access control
  rate limitting
  business logic
]]
local cache = require 'api.cache'
local api = {}
local to_json = (require 'lapis.util').to_json
local from_json = (require 'lapis.util').from_json
local uuid = require 'lib.uuid'
local worker = require 'api.worker'
local tinsert = table.insert
local trim = (require 'lapis.util').trim
local scrypt = require 'lib.scrypt'
local salt = 'poopants'

--self.session.current_user


function api:GetUserFilters(userID)
  if not userID then
    userID = 'default'
  end
  local filterIDs = cache:GetUserFilterIDs(userID)

  return cache:GetFilterInfo(filterIDs)
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
  sort = sort or 'fresh'

  local filterPosts = cache:GetFilterPosts(filterName,username,offset,sort)

  -- function used to get new postIDs
  local getMorePosts
  if sort == 'new' then

  elseif sort == 'best' then

  else

  end

  local userSeenPosts = cache:GetUserSeenPosts(username) or {}
  local userFilters = cache:GetIndexedUserFilterIDs(username)

  local finalPosts = {}
  local unfilteredPosts
  local unfilteredOffset = 0

  local postID, filterID
  local postInfo

  while #finalPostIDs < offset + 10 do
    unfilteredPosts = GetMorePosts(unfilteredOffset,unfilteredOffset+1000)

    for k,v in pairs(unfilteredPosts) do
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
    rediswrite:UpdateUserSeenPosts(username,userSeenPosts)
  end

  return finalPosts

end

function api:SubscribeToFilter(userID,filterID)

  local filterIDs = cache:GetUserFilterIDs(userID)

  for k, v in pairs(filterIDs) do
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

  if masterInfo.kv.active == 0 then
    return nil,true
  end

  local valid = scrypt.check(userCredentials.password,masterInfo.kv.passwordHash)
  if valid then
    masterInfo.kv.passwordHash = nil
    return masterInfo
  end

end

function api:CreateActivationKey(masterInfo)
  local key = ngx.md5(masterInfo.kv.id..masterInfo.kv.email..salt)
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
    worker:ActivateAccount(userInfo.kv.id)
    return true
  else
    return nil, 'activation key incorrect'
  end
end

function api:GetUserFrontPage(userID)
  return cache:GetUserFrontPage(userID)
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

  local masterInfo = {}
  masterInfo.kv = {}
  masterInfo.kv.email = userInfo.email
  masterInfo.kv.passwordHash = scrypt.crypt(userInfo.password)
  masterInfo.kv.id = uuid.generate_random()
  masterInfo.kv.active = 0
  masterInfo.kv.users = 1


  masterInfo.users = {}
  local firstUser = {}
  firstUser.kv = {}
  firstUser.kv.id = uuid.generate_random()
  firstUser.kv.username = userInfo.username
  firstUser.filters = cache:GetUserFilterIDs('default')
  ngx.log(ngx.ERR, to_json(firstUser.filters))
  firstUser.kv.parentID = masterInfo.kv.id

  tinsert(masterInfo.users,firstUser.kv.id)
  masterInfo.kv.currentUserID = firstUser.kv.id

  local activateKey = self:CreateActivationKey(masterInfo)
  local url = confirmURL..'?email='..userInfo.email..'&activateKey='..activateKey
  worker:SendActivationEmail(url, userInfo.email)
  worker:CreateMasterUser(masterInfo)
  worker:CreateUser(firstUser)
  return true

end

function api:UnsubscribeFromFilter(username,filterID)
  local filterIDs = cache:GetUserFilterIDs(username)
  local found = false
  for k,v in pairs(filterIDs) do
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

  return true
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

  for k,v in pairs(chosenFilterIDs) do
    chosenFilterIDs[k] = k
  end
  postInfo.filters = chosenFilterIDs
  --get the info from the filters to find out which tags they want
  local filtersWithInfo = cache:GetFilterInfo(chosenFilterIDs)
  local finalFilters = {}
  for k,filter in pairs(filtersWithInfo) do
    if self:TagsMatch(filter.requiredTags, postInfo.tags) then
      tinsert(finalFilters,filter)
    end
  end
  worker:AddPostToFilters(finalFilters,postInfo)
  worker:CreatePost(postInfo)
  return true
end

function api:TagsMatch(filterTags,postTags)
  local found = false
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
  return true
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

  for k,v in pairs(filterInfo.requiredTags) do
    local tag = self:CreateTag(v, filterInfo.createdBy)
    if tag then
      tag.filterID = filterInfo.id
      tag.filterType = 'required'
      tag.createdBy = filterInfo.createdBy
      tag.createdAt = filterInfo.createdAt
      tinsert(tags,tag)
      filterInfo.requiredTags[k] = tag
    end
  end

  for k,v in pairs(filterInfo.bannedTags) do
    local tag = self:CreateTag(v, filterInfo.createdBy)
    if tag then
      tag.filterID = filterInfo.id
      tag.filterType = 'banned'
      tag.createdBy = filterInfo.createdBy
      tag.createdAt = filterInfo.createdAt
      tinsert(tags,tag)
      filterInfo.bannedTags[k] = tag
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
