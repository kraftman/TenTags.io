
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
local userFilterIDs = ngx.shared.userFilterIDs
local filterDict = ngx.shared.filters
--local frontpages = ngx.shared.frontpages
local userUpdateDict = ngx.shared.userupdates
local userSessionSeenDict = ngx.shared.usersessionseen
local searchResults = ngx.shared.searchresults
local postInfo = ngx.shared.postinfo
local to_json = (require 'lapis.util').to_json
local from_json = (require 'lapis.util').from_json
local redisread = require 'api.redisread'
local userRead = require 'api.userread'
local commentRead = require 'api.commentread'
local lru = require 'api.lrucache'

local elastic = require 'lib.elasticsearch'
local tinsert = table.insert
local userInfo = ngx.shared.userInfo
local commentInfo = ngx.shared.comments
local voteInfo = ngx.shared.userVotes
local PRECACHE_INVALID = true

local DEFAULT_CACHE_TIME = 30

local DISABLE_CACHE = os.getenv('DISABLE_CACHE')


function cache:GetThread(threadID)
  return redisread:GetThreadInfo(threadID)
end

function cache:GetThreads(userID)
  local threadIDs = redisread:GetUserThreads(userID)
  local threads = redisread:GetThreadInfos(threadIDs)

  return threads
end

function cache:GetUser(userID)
  local ok, err

  if not DISABLE_CACHE then
     ok, err = userInfo:get(userID)
    if ok then
      return from_json(ok)
    end
    if err then
      ngx.log(ngx.ERR, 'unable to get user info : ',err)
    end
  end

  local user, err = userRead:GetUser(userID)
  if not user then
    return user, err
  end

  ok, err = userInfo:set(userID, to_json(user), DEFAULT_CACHE_TIME)
  if not ok then
    ngx.log(ngx.ERR, 'unable to set user ifno:',err)
    return ok, err
  end
  return user

end

function cache:SearchPost(queryString)
  local results, ok, err
  if not DISABLE_CACHE then
    ok, err = searchResults:get()
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

function cache:PurgeKey(keyInfo)
  if keyInfo.keyType == 'account' then
    if PRECACHE_INVALID then
      userInfo:delete(keyInfo.id)
    else
      self:GetAccount(keyInfo.id)
    end
  elseif keyInfo.keyType == 'comment' then
    local postID, commentID = keyInfo.id:match('(%w+):(%w+)')
    commentInfo:delete(postID)
  end
end

function cache:GetCommentIDFromURL(commentURL)
  return commentRead:GetCommentIDFromURL(commentURL)
end

function cache:GetAccount(accountID)
  local account, ok, err
  if not DISABLE_CACHE then
    ok, err = userInfo:get(accountID)
    if err then
      ngx.log(ngx.ERR, 'unable to get account: ',err)
    end
    if ok then
      return from_json(ok)
    end
  end

  account, err = userRead:GetAccount(accountID, DEFAULT_CACHE_TIME)
  if err then
    return account, err
  end
  ok, err = userInfo:set(accountID, to_json(account))
  if not ok then
    ngx.log(ngx.ERR, 'unable to set account info: ',err)
  end

  return account
end

function cache:GetUserAlerts(userID)
  local user = self:GetUser(userID)
  if not user.alertCheck then
    user.alertCheck = 0
  end
  local alerts = userRead:GetUserAlerts(userID,user.alertCheck, ngx.time())
  --ngx.log(ngx.ERR, to_json(alerts))
  return alerts
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


function cache:AddPost(post)
  local result,err = postInfo:set(post.id,to_json(postInfo))
  return result, err
end

function cache:GetAllTags()
  local tags = lru:GetAllTags()
  if tags then
    return tags
  end

  local res = redisread:GetAllTags()
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

function cache:AddChildren(parentID,flat)
  local t = {}
  for _,v in pairs(flat[parentID]) do
    t[v.id] = self:AddChildren(v.id,flat)
  end

  return t
end

function cache:SearchTags(searchString)
  return redisread:SearchTags(searchString)
end

function cache:SearchFilters(searchString)
  local filterNames = redisread:SearchFilters(searchString)
  local filters = {}
  for _,filterName in pairs(filterNames) do
    tinsert(filters, self:GetFilterByName(filterName))
  end
  return filters
end

function cache:GetUsername(userID)

  local user = self:GetUser(userID)
  if user then
    return user.username
  end
end

function cache:GetPostComments(postID)

  local ok, err,flatComments

  if not DISABLE_CACHE then
    ok, err = commentInfo:get(postID)
    if err then
      ngx.log(ngx.ERR, 'could not get post comments: ',err)
    end

    if ok then
      return from_json(ok)
    end
  end

  flatComments, err = commentRead:GetPostComments(postID)

  if err then
    return flatComments, err
  end

  for k,v in pairs(flatComments) do
    flatComments[k] = from_json(v)
  end

  ok, err = commentInfo:set(postID, to_json(flatComments),DEFAULT_CACHE_TIME)
  if err then
    ngx.log(ngx.ERR, 'error setting postcomments: ', err)
    return ok,err
  end


  return flatComments

end

function cache:ConvertShortURL(shortURL)
  return redisread:ConvertShortURL(shortURL)
end

function cache:GetSortedComments(userID, postID,sortBy)

  local flatComments,err = self:GetPostComments(postID)
  if err then
    return flatComments, err
  end

  local indexedComments = {}
  -- format flatcomments

  local userVotedComments

  if userID then
    userVotedComments = self:GetUserCommentVotes(userID)
  end

  for _,v in pairs(flatComments) do

    v.username = self:GetUsername(v.createdBy)

    if userID and userVotedComments[v.id] then
      v.userHasVoted = true
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

function cache:GetPost(postID)
  local ok, err,result

  if #postID < 10 then
    postID = self:ConvertShortURL(postID)
  end

  if not DISABLE_CACHE then
    ok, err = postInfo:get(postID)
    if err then
      ngx.log(ngx.ERR, 'unable to load post info: ', err)
    end
    if ok then
      return from_json(ok)
    end
  end

  result, err = redisread:GetPost(postID)

  if err then
    return result, err
  end

  ok, err = postInfo:set(postID,to_json(result))
  if not ok then
    ngx.log(ngx.ERR, 'unable to set postInfo: ',err)
  end
  return result

end

function cache:GetFilterPosts(userID, filter, sortBy)

  local filterIDs = redisread:GetFilterPosts(filter, sortBy)
  local posts = {}
  local post
  for _,v in pairs(filterIDs) do
    post = self:GetPost(v)
    post.filters = self:GetFilterInfo(post.filters) or {}
    table.sort(post.filters, function(a,b) return a.subs > b.subs end)
    tinsert(posts, post)
  end

  return posts
end



function cache:GetFilterID(filterName)
  --cache later
  return redisread:GetFilterID(filterName)
end

function cache:GetFilterByName(filterName)
  local filterID = self:GetFilterID(filterName)
  if not filterID then
    return nil
  end
  return self:GetFilterByID(filterID) or {}
end

function cache:GetFilterByID(filterID)
  local ok, err, result

  if not DISABLE_CACHE then
    ok, err = filterDict:get(filterID)

    if err then
      ngx.log(ngx.ERR, 'unable to get filter info from shdict: ',err)
    end

    if ok then
      return from_json(ok)
    end
  end


  result,err = redisread:GetFilter(filterID)
  if err then
    return result, err
  end

  ok, err = filterDict:set(filterID,to_json(result))
  if not ok then
    ngx.log('unablet to set filterdict: ',err)
  end

  return result

end

function cache:GetFilterIDsByTags(tags)

  -- return all filters that are interested in these tags

  return redisread:GetFilterIDsByTags(tags)

end



function cache:GetFilterInfo(filterIDs)
  local filterInfo = {}
  for k,v in pairs(filterIDs) do
    filterInfo[k] = self:GetFilterByID(v)
  end
  return filterInfo
end

function cache:GetFiltersBySubs(startAt,endAt)

  local filterIDs = redisread:GetFiltersBySubs(startAt, endAt)
  if not filterIDs then
    print('none found')
    return {}
  end
  print(to_json(filterIDs))
  return self:GetFilterInfo(filterIDs)
end

function cache:GetIndexedUserFilterIDs(userID)
  local indexed = {}
  for _,v in pairs(self:GetUserFilterIDs(userID)) do
    indexed[v] = true
  end
  return indexed
end

function cache:GetUserSessionSeenPosts(userID)
  local result = userSessionSeenDict:get(userID)
  if not result then
    return {}
  end

  local indexedSeen = {}
  for _,v in pairs(from_json(result)) do
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
  local ok,err,forced = userSessionSeenDict:set(userID,to_json(flatSeen))
  if not ok then
    ngx.log(ngx.ERR, 'unable to write user seen:',err)
  end
  if forced then
    ngx.log(ngx.ERR, 'forced write to user seen posts, increase dict size!')
  end

  ok, err = userUpdateDict:set(userID,1)
  return ok, err
end

function cache:GetFreshUserPosts(userID,filter) -- needs caching
  -- the results of this need to be cached for a shorter duration than the
  -- frequency that session seen posts are flushed to user seen
  -- so that we can ignore session seen posts here

  local startRange,endRange = 0,1000
  local freshPosts,filteredPosts = {},{}
  local postID,filterID
  local userFilterIDs = self:GetIndexedUserFilterIDs(userID)

  local filterFunction
  if filter == 'new' then
    filterFunction = 'GetAllNewPosts'
  elseif filter == 'best' then
    filterFunction = 'GetAllBestPosts'
  elseif filter == 'seen' then
    filterFunction = 'GetAllUserSeenPosts'
  else
    filterFunction = 'GetAllFreshPosts'
  end

  while #freshPosts < 100 do

    local allPostIDs

    -- grab 1000 post IDs
    if filter == 'seen' then
      allPostIDs = userRead[filterFunction](userRead,userID,startRange,endRange)
    else
      allPostIDs = redisread[filterFunction](redisread,startRange,endRange)
    end

    -- if weve hit the end then return regardless
    if #allPostIDs == 0 then
      break
    end

    startRange = startRange+1000
    endRange = endRange+1000

    if filter == 'seen' then
      for _,v in pairs(allPostIDs) do
        tinsert(freshPosts,v)
      end
    else

      for _, v in pairs(allPostIDs) do
        filterID,postID = v:match('(%w+):(%w+)')
        if userFilterIDs[filterID] then
          tinsert(filteredPosts,postID)
        end
      end

      -- check the user hasnt seen the posts
      local newUnseen
      if userID == 'default' then
        newUnseen = filteredPosts
      else
        newUnseen = userRead:GetUnseenPosts(userID,filteredPosts)
      end

      for _,v in pairs(newUnseen) do
        tinsert(freshPosts,v)
      end

    end
  end

  return freshPosts
end

function cache:GetUserCommentVotes(userID)
  if not userID then
    return {}
  end

  local ok, err, commentVotes

  if not DISABLE_CACHE then

    ok, err = voteInfo:get('commentVotes:'..userID)

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
      voteInfo:set('commentVotes:'..userID, to_json(ok), DEFAULT_CACHE_TIME)
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
  local indexed = userRead:GetUserPostVotes(userID)
  local keyed = {}
  for _,v in pairs(indexed) do
    keyed[v] = true
  end
  return keyed

end

function cache:CheckUnseenParent(newPosts, sessionSeenPosts, userID, postID)
  --check if its seen this session, add it
  if sessionSeenPosts[postID] then
    return
  end
  sessionSeenPosts[postID] = true

  --
  local post = self:GetPost(postID)
  if post.id ~= post.parentID then
    if sessionSeenPosts[post.parentID] then
      return
    end
    local parentID = post.parentID
    if parentID:len() < 10 then
      parentID = self:ConvertShortURL(parentID)
    end
    local unseenPosts = userRead:GetUnseenPosts(userID,{parentID})
    if not next(unseenPosts) then
      return
    end
  end

  tinsert(newPosts, post)
end

function cache:GetUserFrontPage(userID,sortBy,startAt, endAt)

  local user = self:GetUser(userID)

  local sessionSeenPosts = cache:GetUserSessionSeenPosts(userID)

  -- this will be cached for say 5 minutes
  local freshPosts = cache:GetFreshUserPosts(userID,sortBy)

  local newPosts = {}

  if sortBy ~= 'seen' and userID ~= 'default' then
    for _,postID in pairs(freshPosts) do
      self:CheckUnseenParent(newPosts, sessionSeenPosts, userID, postID)

      -- stop when we have a page worth
      if #newPosts > (endAt - startAt) then
        break
      end
    end
    if user.hideSeenPosts == '1' then
      self:UpdateUserSessionSeenPosts(userID,sessionSeenPosts)
    end
  else
    for i = startAt, endAt do
      if freshPosts[i] then
        tinsert(newPosts,self:GetPost(freshPosts[i]))
      end
    end
  end

  local userVotedPosts = self:GetUserPostVotes(userID)

  for _,post in pairs(newPosts) do
      post.filters = self:GetFilterInfo(post.filters) or {}
      table.sort(post.filters, function(a,b) return a.subs > b.subs end)
    if userVotedPosts[post.id] then
      post.userHasVoted = true
    end
  end

  return newPosts
end


function cache:GetTag(tagName)
  local tag = redisread:GetTag(tagName)
  return tag
end



function cache:GetUserFilterIDs(userID)
  local ok, err, res

  if not DISABLE_CACHE then
    ok, err = userFilterIDs:get(userID)
    if err then
      ngx.log(ngx.ERR, 'unable to get from shdict filterlist: ',err)
    end

    if ok then
      return from_json(ok)
    end
  end

  res, err = userRead:GetUserFilterIDs(userID)
  if not res then
    return res, err
  end


  ok, err = userFilterIDs:set(userID,to_json(res),DEFAULT_CACHE_TIME)

  if not ok then
    ngx.log(ngx.ERR, 'unable to set user filter: ',err)
  end

  return res

end


return cache
