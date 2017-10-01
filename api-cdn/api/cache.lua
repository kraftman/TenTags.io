
local app_helpers = require("lapis.application")
local capture_errors, assert_error = app_helpers.capture_errors, app_helpers.assert_error

local cjson = require("cjson")
cjson.encode_sparse_array(true)

--[[
caching the most with the leas
LRU great for complex objects (tables) but expensive
as it uses X times the number of workers RAM

common to less common:
filters
tags
posts
comments
users

]]

local cache = {}
local filterDict = ngx.shared.filters
local userUpdateDict = ngx.shared.userupdates
local userSessionSeenPostDict = ngx.shared.usersessionseenpost
local viewFilterIDs = ngx.shared.viewFilterIDs
local searchResults = ngx.shared.searchresults
local postDict = ngx.shared.posts
local userAlertDict = ngx.shared.userAlerts
local userFrontPagePostDict = ngx.shared.userFrontPagePosts
local userDict = ngx.shared.users
local commentDict = ngx.shared.comments
local voteDict = ngx.shared.userVotes
local imageDict = ngx.shared.images

local app_helpers = require("lapis.application")
local assert_error = app_helpers.assert_error

local to_json = (require 'lapis.util').to_json
local from_json = (require 'lapis.util').from_json
local redisRead = (require 'redis.db').redisRead
local userRead = (require 'redis.db').userRead
local commentRead = (require 'redis.db').commentRead
local lru = require 'api.lrucache'


local elastic = require 'lib.elasticsearch'
local tinsert = table.insert
local PRECACHE_INVALID = true

local DEFAULT_CACHE_TIME = 30

local ENABLE_CACHE = os.getenv('ENABLE_CACHE')


function cache:GetThread(threadID)
  return redisRead:GetThreadInfo(threadID)
end

function cache:GetThreads(userID, startAt, range)
  local threadIDs = redisRead:GetUserThreads(userID, startAt, range)
  local threads = redisRead:GetThreadInfos(threadIDs)

  return threads
end

function cache:GetImage(imageID)

  local ok, err = redisRead:GetImage(imageID)

  if err then
    ngx.log(ngx.ERR, err)
    return nil, 'image not found'
  end

  return ok, err
end

function cache:GetImageData(imageID)
   local ok, err = imageDict:get(imageID)
  if err then
    print(err)
  end
  if ok then
    return from_json(ok), err
  end
end

function cache:SetImageData(imageID, imageData)
  local ok, err = imageDict:set(imageID, to_json(imageData))
  if not ok then
    print('error setting image: ', err)
  end
  return ok
end

function cache:SavedPostExists(userID, postID)
  if not userID then
    return false
  end
  return userRead:SavedPostExists(userID, postID)
end

function cache:GetUser(userID)
  local ok, err

  if ENABLE_CACHE then
     ok, err = userDict:get(userID)
    if ok then
      return from_json(ok)
    end
    if err then
      ngx.log(ngx.ERR, 'unable to get user info : ',err)
      return nil, 'couldnt get user ', err
    end
  end

  local user, err = userRead:GetUser(userID)
  if not user then
    return user, err
  end

  ok, err = userDict:set(userID, to_json(user), DEFAULT_CACHE_TIME)
  if not ok then
    ngx.log(ngx.ERR, 'unable to set user ifno:',err)
    return ok, err
  end
  return user

end

function cache:GetReports()
  local ok, err = redisRead:GetReports()
  if not ok then
    return ok, err
  end
  local post, postID, user, userID
  local reports = {}
  for _,v in pairs(ok) do
    postID, userID = v:match('(%w+):(%w+)')
    post = self:GetPost(postID)
    user = self:GetUser(userID)
    tinsert(reports, {user = user, post = post})
  end
  return reports
end

function cache:SearchURL(queryString)
  return elastic:SearchURL(queryString)
end

function cache:GetRelevantFilters(validTags)
  return redisRead:GetRelevantFilters(validTags)
end

function cache:SearchPost(queryString)
  local results, ok, err
  if ENABLE_CACHE then
    ok, err = searchResults:get(queryString)
    if err then
      ngx.log(ngx.ERR, 'unable to check searchResults shdict ', err)
      return nil, err
    end
    if ok then
      return from_json(ok)
    end
  end
  results, err = elastic:SearchWholePostFuzzy(queryString)
  if not results then
    return nil, err
  end
  ok, err = searchResults:set(queryString, results)
  if not ok then
    ngx.log(ngx.ERR, 'unable to store search results: ', err)
  end

  return from_json(results)

end

function cache:UpdateKey(key, object)
  if key == 'post' then
    self:WritePost(object)
  end
end

function cache:PurgeKey(keyInfo)
  --print('purging: ', to_json(keyInfo))
  if keyInfo.keyType == 'account' then
    if PRECACHE_INVALID then
      userDict:delete(keyInfo.id)
      self:GetAccount(keyInfo.id)
    else
      userDict:delete(keyInfo.id)
    end
  elseif keyInfo.keyType == 'comment' then
    local postID, _ = keyInfo.id:match('(%w+):(%w+)') -- postID, commentIDs
    commentDict:delete(postID)
  elseif keyInfo.keyType == 'user' then
    userDict:delete(keyInfo.id)
    if PRECACHE_INVALID then
      self:GetUser(keyInfo.id)
    end
  elseif keyInfo.keyType == 'useralert' then
    userAlertDict:delete(keyInfo.id)
  elseif keyInfo.keyType == 'post' then
    --print('purging post: ',keyInfo.id)
    postDict:delete(keyInfo.id)
    if PRECACHE_INVALID then
      self:GetPost(keyInfo.id)
    end
  elseif keyInfo.keyType == 'filter' then
    filterDict:delete(keyInfo.id)
    if PRECACHE_INVALID then
      self:GetFilterByID(keyInfo.id)
    end
  elseif keyInfo.keyType == 'postvote' then
    voteDict:delete('postVotes:'..keyInfo.id)
  elseif keyInfo.keyType == 'view' then
    viewFilterIDs:delete(keyInfo.id)
  elseif keyInfo.keyType == 'frontpage' then

  elseif keyInfo.keyType == 'image' then
    imageDict:delete(keyInfo.id)
  end
end

function cache:GetCommentIDFromURL(commentURL)
  return commentRead:GetCommentIDFromURL(commentURL)
end

function cache:GetAccount(accountID)
  local account, ok, err
  if ENABLE_CACHE then
    ok, err = userDict:get(accountID)
    if err then
      return nil, 'couldnt load account from shdict'
    end
    if ok then
      return from_json(ok)
    end
  end

  account, err = userRead:GetAccount(accountID)

  if err then
    return account, err
  end
  ok, err = userDict:set(accountID, to_json(account))
  if not ok then
    ngx.log(ngx.ERR, 'unable to set account info: ',err)
  end

  return account
end

function cache:GetUserAlerts(userID)
  local user = self:GetUser(userID)
  if not user then
    return nil, 'no user found'
  end

  if not user.alertCheck then
    user.alertCheck = 0
  end
  local ok, err, alerts

  if ENABLE_CACHE then
    ok, err = userAlertDict:get(userID)
    if err then
      return nil, 'couldnt load alerts from shdict'
    end
    --print(ok)
    if ok then
      alerts = from_json(ok)
    end
  end

  if not alerts then

    alerts = userRead:GetUserAlerts(userID,user.alertCheck, ngx.time())

    if err then
      return alerts, err
    end
    ok, err = userAlertDict:set(userID, to_json(alerts),30)
    if not ok then
      ngx.log(ngx.ERR, 'unable to set alert info: ',err)
    end

  end


  return alerts, err
end


function cache:GetUserTagVotes(userID)
  if not userID then
    return {}
  end
  local indexed = userRead:GetUserTagVotes(userID)
  local keyed = {}
  for _,v in pairs(indexed) do
    keyed[v] = true
  end

  return keyed

end

function cache:GetRecentPostVotes(userID,direction)
  return userRead:GetRecentPostVotes(userID,direction)
end


function cache:AddPost(post)
  local result,err = postDict:set(post.id,to_json(postDict))
  return result, err
end

function cache:GetAllTags()
  local tags = lru:GetAllTags()
  if tags then
    return tags
  end

  local res = redisRead:GetAllTags()
  if res then
    lru:SetAllTags(res)
    return res
  else
    ngx.log(ngx.ERR, 'error requesting from api')
    return {}
  end
end

function cache:GetUserID(username)
  return userRead:GetUserID(username)
end

function cache:GetUserByName(username)
  local userID = self:GetUserID(username)
  if not userID then
    return nil
  end
  return self:GetUser(userID)
end

function cache:GetComment(postID, commentID)
  return commentRead:GetComment(postID,commentID)
end

function cache:GetUserComments(userID, sortBy, startAt, range)
  -- why is this split in two parts?
  -- why not just get all with hgetall
  local postIDcommentIDs = userRead:GetUserComments(userID, sortBy, startAt, range)
  if not postIDcommentIDs then
    return {}
  end
  local comments = commentRead:GetUserComments(postIDcommentIDs)
  for k,v in pairs(comments) do
    comments[k] = from_json(v)
  end
  return comments
end

function cache:GetUserPosts(userID, startAt, range)
  local postIDs = userRead:GetUserPosts(userID, startAt, range)
  return self:GetPosts(postIDs)
end

function cache:AddChildren(parentID,flat)
  local t = {}
  for _,v in pairs(flat[parentID]) do
    t[v.id] = self:AddChildren(v.id,flat)
  end

  return t
end

function cache:SearchTags(searchString)
  return redisRead:SearchTags(searchString)
end

function cache:SearchFilters(searchString)
  local filterNames = redisRead:SearchFilters(searchString)
  local filters = {}
  for _,filterName in pairs(filterNames) do
    tinsert(filters, self:GetFilterByName(filterName))
  end
  return filters
end

function cache:GetUsername(userID)

  local user = self:GetUser(userID)
  --print(to_json(user))
  if user then
    return user.username
  end
end

function cache:WritePostComments(postID, postComments)
  assert_error(commentDict:set(postID, to_json(postComments),DEFAULT_CACHE_TIME))
end

function cache:GetPostComments(postID)

  local ok, err, flatComments

  if ENABLE_CACHE then
    ok = commentDict:get(postID)

    if ok then
      return from_json(ok)
    end
  end

  flatComments = commentRead:GetPostComments(postID)


  for k,v in pairs(flatComments) do
    flatComments[k] = from_json(v)
  end
  self:WritePostComments(postID, flatComments)

  return flatComments

end

function cache:GetNewUsers()
  local ok, err =  userRead:GetNewUsers()
  print(to_json(ok))
  for k,v in pairs(ok )do

  end

  if ok == 0 then
    print('none')
    return {}
  end

  return ok,err
end


function cache:ConvertShortURL(shortURL)
  return redisRead:ConvertShortURL(shortURL)
end

function cache:FiltersOverlap(postFilters, commentFilters)

  for _,postFilterID in pairs(postFilters) do
    for _,commentFilterID in pairs(commentFilters) do
      if postFilterID == commentFilterID then
        return true
      end
    end
  end
  return false
end

function cache:GetSortedComments(userID, postID,sortBy)

  local flatComments = assert_error(self:GetPostComments(postID))
  local indexedComments = {}
  -- format flatcomments

  local userVotedComments

  if userID ~= 'default' then
    userVotedComments = self:GetUserCommentVotes(userID)
  end
  local post = cache:GetPost(postID)
  local user = cache:GetUser(userID)
  local filtersOverlap

  for _,v in pairs(flatComments) do
    v.username = self:GetUsername(v.createdBy) or 'unknown'

    filtersOverlap = self:FiltersOverlap(post.filters or {}, v.filters or {})
    v.filters = self:GetFilterInfo(v.filters or {})


    if user and userVotedComments[v.id] then
      v.userHasVoted = true
    end

    if user and user.hideUnsubbedComments and not filtersOverlap then
      v.hidden = true
    end

    if user then
      for _,blockedUserID in pairs(user.blockedUsers) do
        if v.createdBy == blockedUserID then
          v.hidden = true
          v.username = 'blocked'
          break
        end
      end
    end


    tinsert(indexedComments, v)

  end

  if sortBy == 'top' then
    table.sort(indexedComments, function(a,b) return a.up-a.down > b.up -b.down end)
  elseif sortBy == 'new' then
    table.sort(indexedComments, function(a,b) return a.createdAt > b.createdAt end)
  else
    table.sort(indexedComments, function(a,b) return a.score > b.score end)
  end

  local keyedComments = {}

  for _,v in pairs(indexedComments) do
    keyedComments[v.id] = v
    v.children = {}
  end

  keyedComments[postID] = {children = {}}

  for _,comment in pairs(indexedComments) do
    tinsert(keyedComments[comment.parentID].children,comment)
  end
  return keyedComments

end


function cache:GetPosts(postIDs)
  local posts = {}
  for _,v in pairs(postIDs) do
    tinsert(posts, self:GetPost(v))
  end
  return posts

end

function cache:WritePost(post)

  if not post then
    postDict:delete(post.id)
    return
  end

  local ok, err = postDict:set(post.id, cjson.encode(post))
  if not ok then
    ngx.log(ngx.ERR, 'unable to set postDict: ',err)
  end

  return ok
end

function cache:GetPost(postID)
  local ok, err, post

  if #postID < 10 then
    postID = self:ConvertShortURL(postID)
    if not postID then
      return nil, 'no post found'
    end
  end

  if ENABLE_CACHE then

    ok, err = postDict:get(postID)
    if err then
      ngx.log(ngx.ERR, 'unable to load post info: ', err)
    end
    if ok then
      post = from_json(ok)
    end
  end

  if not post then

    post, err = redisRead:GetPost(postID)

    if not post then
      return post, err
    end

    post.creatorName = self:GetUsername(post.createdBy) or 'unknown'

    self:WritePost(post)
  end
  return post

end

function cache:GetUnseenPosts(userID, postIDs)
  local sessionSeenPosts = self:GetUserSessionSeenPosts(userID)
  local postParents = redisRead:GetParentIDs(postIDs) -- postID, parentID
  local unSeenParentIDs = userRead:GetUnseenParentIDs(userID,postParents)
  local unSeenPosts = {}

  for _,v in pairs(postParents) do
    if unSeenParentIDs[v.parentID] and not sessionSeenPosts[v.parentID] then
      tinsert(unSeenPosts,v.postID)
    end
  end

  return unSeenPosts

end

function cache:GetFilterPosts(userID, filter, sortBy,startAt, range)

  local unSeenPostIDs = {}
  local postIDs = redisRead:GetFilterPosts(filter, sortBy,startAt, range)

  if userID == 'default' then
    unSeenPostIDs = postIDs
  else
    unSeenPostIDs = self:GetUnseenPosts(userID, postIDs)
  end

  local posts = {}
  local post
  for _,v in pairs(unSeenPostIDs) do
    post = self:GetPost(v)
    post.filters = self:GetFilterInfo(post.filters) or {}
    if self:SavedPostExists(userID, post.id) then
      print('user has saved the post')
      post.userSaved = true
    end
    if userID and userID ~= 'default' then
      local userVotedPosts = self:GetUserPostVotes(userID)
      if userVotedPosts[post.id] then
        post.userHasVoted = true
      end
    end
    table.sort(post.filters, function(a,b) return a.subs > b.subs end)
    tinsert(posts, post)
  end

  --TODO   check this hides userseen

  return posts
end


function cache:GetUserSeenPosts(userID, startAt, range)
  local postIDs = userRead:GetAllUserSeenPosts(userID, startAt, range-1)

  local posts = {}
  for _,v in pairs(postIDs) do
    table.insert(posts, self:GetPost(v))
  end
  return posts
end


function cache:GetView(viewID)
  -- TODO cache
  return redisRead:GetView(viewID)
end


function cache:GetFilterID(filterName)
  --cache later
  return redisRead:GetFilterID(filterName)
end

function cache:GetFilterByName(filterName)
  local filterID = self:GetFilterID(filterName)
  if not filterID then
    return nil
  end
  return self:GetFilterByID(filterID) or {}
end

function cache:GetFilterByID(filterID)
  --print(to_json(filterID))
  local ok, err, result

  if ENABLE_CACHE then
    ok, err = filterDict:get(filterID)

    if err then
      ngx.log(ngx.ERR, 'unable to get filter info from shdict: ',err)
    end

    if ok then
      return from_json(ok)
    end
  end


  result,err = redisRead:GetFilter(filterID)
  if err then
    return result, err
  end

  ok, err = filterDict:set(filterID,to_json(result))
  if not ok then
    ngx.log('unable to set filterdict: ',err)
  end

  return result

end

function cache:GetFilterIDsByTags(tags)

  -- return all filters that are interested in these tags

  return redisRead:GetFilterIDsByTags(tags)

end



function cache:GetFilterInfo(filterIDs)
  local filterInfo = {}
  for k,v in pairs(filterIDs) do
    filterInfo[k] = self:GetFilterByID(v)
  end
  return filterInfo
end

function cache:GetFiltersBySubs(startAt,endAt)

  local filterIDs = redisRead:GetFiltersBySubs(startAt, endAt)
  if not filterIDs then
    return {}
  end

  return self:GetFilterInfo(filterIDs)
end

function cache:GetIndexedViewFilterIDs(viewID)
  local indexed = {}
  for _,v in pairs(self:GetViewFilterIDs(viewID)) do
    indexed[v] = true
  end
  return indexed
end

function cache:GetUserSessionSeenPosts(userID)
  local result = userSessionSeenPostDict:get(userID)
  if not result then
    return {}
  end

  local indexedSeen = {}
  for _,v in ipairs(from_json(result)) do
    indexedSeen[v] = true
  end

  return indexedSeen
end

function cache:AddSeenPost(userID, postID)
  if postID:len() < 10 then
    postID = self:ConvertShortURL(postID)
  end
  local seenPosts = self:GetUserSessionSeenPosts(userID)
  seenPosts[postID] = postID
  self:UpdateUserSessionSeenPosts(userID, seenPosts)
end

function cache:UpdateUserSessionSeenPosts(userID,indexedSeenPosts)
  local flatSeen = {}
  for k,_ in pairs(indexedSeenPosts) do
    tinsert(flatSeen,k)
  end
  local ok,err,forced = userSessionSeenPostDict:set(userID,to_json(flatSeen))
  if not ok then
    ngx.log(ngx.ERR, 'unable to write user seen:',err)
  end
  if forced then
    ngx.log(ngx.ERR, 'forced write to user seen posts, increase dict size!')
  end

  ok, err = userUpdateDict:set(userID,1)
  return ok, err
end


function cache:GetFreshUserPosts(userID, viewID, sortBy, startAt, range)

  local freshPosts = {}
  local count = 0
  local user = self:GetUser(userID)
  local view

  if viewID then
    view = self:GetView(viewID)
  else
    view = self:GetView(user and user.currentView or 'default')
  end



  while #freshPosts < range do
    count = count + 1

    local userPostIDs, err = redisRead:GetFrontPage(userID, sortBy, view.filters, startAt, range)
    if err then
      return nil, err
    end

    local unSeenPosts = self:GetUnseenPosts(userID, userPostIDs)
    for _,v in pairs(unSeenPosts) do
      tinsert(freshPosts, v)
    end

    if #userPostIDs < range then
      -- we've got as many as we'll get
      break
    end
    if count > 10 then
      break
    end
    startAt = startAt + range
  end

  return freshPosts
end


function cache:GetUserCommentVotes(userID)
  if not userID then
    return {}
  end

  local ok, err, commentVotes

  if ENABLE_CACHE then

    ok, err = voteDict:get('commentVotes:'..userID)

    if err then
      ngx.log(ngx.ERR, 'unable to get commentvotes: ',err)
    end
    if ok then
      commentVotes = from_json(ok)
    end
  end

  if not commentVotes then
    ok, err = userRead:GetUserCommentVotes(userID)
    if not err then
      voteDict:set('commentVotes:'..userID, to_json(ok), DEFAULT_CACHE_TIME)
      commentVotes = ok
    end
  end

  local keyed = {}
  for _,v in pairs(commentVotes) do
    keyed[v] = true
  end
  return keyed
end

function cache:GetUserPostVotes(userID)
  local ok, err,postVotes
  if ENABLE_CACHE then
    ok, err = voteDict:get('postVotes:'..userID)

    if err then
      ngx.log(ngx.ERR, 'unable to get commentvotes: ',err)
    end
    if ok then
      postVotes = from_json(ok)
    end
  end

  if not postVotes then

    ok, err = userRead:GetUserPostVotes(userID)
    if not ok then
      return nil, err
    end
    local keyed = {}
    for _,v in pairs(ok) do
      keyed[v] = true
    end
    if not err then
      voteDict:set('postVotes:'..userID, to_json(keyed))
      postVotes = keyed
    end
  end

  return postVotes

end

function cache:GetCachedUserFrontPage(userID, viewID, sortBy, startAt, range)
  local ok, err, userFrontPagePosts
  if ENABLE_CACHE then
    ok, err = userFrontPagePostDict:get(userID..':'..(viewID or '')..':'..sortBy..':'..startAt..':'..range)
    if err then
      ngx.log(ngx.ERR, 'unable to get commentvotes: ',err)
    end
    if ok then
      userFrontPagePosts = from_json(ok)
    end

  end

  if not userFrontPagePosts then
    userFrontPagePosts,err = self:GetFreshUserPosts(userID, viewID, sortBy, startAt, range)
    if not userFrontPagePosts then
      print(err)
    end

    userFrontPagePostDict:set(userID..':'..(viewID or '')..':'..sortBy..':'..range, to_json(userFrontPagePosts),60)
  end

  return userFrontPagePosts

end


function cache:GetUserFrontPage(userID, viewID, sortBy,startAt, range)

  local user = self:GetUser(userID)

  sortBy = sortBy or 'fresh'

  local sessionSeenPosts = cache:GetUserSessionSeenPosts(userID)

  -- this will be cached for say 5 minutes
  local freshPosts = cache:GetCachedUserFrontPage(userID, viewID, sortBy, startAt, range)

  local newPosts = {}
  local post

  for _,postID in ipairs(freshPosts) do

    post = self:GetPost(postID)
    if sortBy ~= 'seen' and userID ~= 'default' and user.hideSeenPosts then
      sessionSeenPosts[post.parentID] = true
      self:UpdateUserSessionSeenPosts(userID,sessionSeenPosts)
    end
    if self:SavedPostExists(userID, post.id) then
      post.userSaved = true
    end

    tinsert(newPosts, post)

  end

  local userVotedPosts = self:GetUserPostVotes(userID)

  for _,post in pairs(newPosts) do
      post.filters = self:GetFilterInfo(post.filters) or {}
      table.sort(post.filters, function(a,b) return a.subs > b.subs end)
    if userVotedPosts[post.id] then
      post.userHasVoted = true
    end
  end

  local distinctPosts = {}
  local hash = {}
  for _,v in ipairs(newPosts) do
    if (not hash[v.id]) then
      distinctPosts[#distinctPosts+1] = v -- you could print here instead of saving to result table if you wanted
      hash[v.id] = true
    end
  end

  return distinctPosts
end

function cache:GetTag(tagName)
  local tag = redisRead:GetTag(tagName)
  return tag
end

function cache:GetViewFilterIDs(viewID)
  local ok, err, res

  if ENABLE_CACHE then
    ok, err = viewFilterIDs:get(viewID)
    if err then
      ngx.log(ngx.ERR, 'unable to get from shdict filterlist: ',err)
    end

    if ok then
      --print(ok)
      return from_json(ok)
    end
  end

  res, err = self:GetView(viewID).filters
  if not res then
    return res, err
  end

  ok, err = viewFilterIDs:set(viewID,to_json(res))

  if not ok then
    ngx.log(ngx.ERR, 'unable to set user filter: ',err)
  end
  return res

end


return cache
