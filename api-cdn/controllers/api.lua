

local m = {}


local respond_to = (require 'lapis.application').respond_to
local api = require 'api.api'
local tinsert = table.insert

function m.SearchFilter(request)
  if not request.params.searchString then
    return {json = {error = 'no searchString provided', data = {}}}
  end
  if not request.session.userID then
    return {json = {error = 'you must be logged in!', data = {}}}
  end
  local ok, err = api:SearchFilters(request.session.userID, request.params.searchString)
  print(to_json(ok))
  if ok then
    return {json ={error = {}, data = ok} }
  else
    return {json = {error = {err}, data = {}}}
  end
end

function m.GetUserFilters(request)
  local ok, err = api:GetUserFilters(request.session.userID)
  return {json = {error = {err}, data = ok or {}}}
end

local function GetUserRecentSeen()

end

local function HashIsValid(request)
  --print(request.params.postID, request.session.userID)
  local realHash = ngx.md5(request.params.postID..request.session.userID)
  if realHash ~= request.params.hash then
    ngx.log(ngx.ERR, 'hashes dont match!')
    return false
  end
  return true
end


function m.UpvotePost(request)
  if not HashIsValid(request) then
    return 'invalid hash'
  end
  local ok, err = api:VotePost(request.session.userID, request.params.postID, 'up')
  if ok then
    return { json = {status = 'success', data = {}} }
  else
    return { json = {status = "error" }}
  end
end

function m.DownvotePost(request)
  if not HashIsValid(request) then
    return 'invalid hash'
  end
  local ok, err = api:VotePost(request.session.userID, request.params.postID, 'down')
  if ok then
    return { json = {status = 'success', data = {}} }
  else
    return { json = {status = "error" }}
  end
end

function m.GetUserSettings(request)
  local ok, err = api:GetUserSettings(request.session.userID)
  if ok then
    return {json = {status = 'success', data = ok}}
  else
    return {json = {status = 'error', message = err}}
  end
end

function m.GetFrontPage(request)
  local startAt = request.params.startAt or 1
  local endAt = request.params.endAt or 100
  local sortBy = request.params.sortby or 'fresh'
  local userID = request.session.userID or 'default'

  local ok,err = api:GetUserFrontPage(userID, sortBy, startAt, endAt)
  if ok then
    return {json = {status = 'success', data = ok or {}}}
  else
    return {json = {status = 'error', message = err}}
  end
end

function m.GetFilterPosts(request)

  local startAt = request.params.startAt or 1
  local endAt = request.params.endAt or 100
  local sortBy = request.params.sortby or 'fresh'
  --local ok, err = api:GetFilterPosts(userID, self.params.filterName, )
end


function m.CreateFilter(request)

  if request.params.setdefault or request.params.subscribe then
    return ToggleDefault(request)
  end

  local requiredTagIDs = from_json(request.params.requiredTagIDs)
  local bannedTagIDs = from_json(request.params.bannedTagIDs)

  local info ={
    title = request.params.title,
    name= request.params.label:gsub(' ','') ,
    description = request.params.description,
    createdAt = ngx.time(),
    createdBy = request.session.userID,
    ownerID = request.session.userID
  }

  info.bannedTagIDs = bannedTagIDs
  info.requiredTagIDs = requiredTagIDs

  local ok, err = api:CreateFilter(request.session.userID, info)
  if ok then
    return { json = {status = 'success', data = ok }}
  else
    ngx.log(ngx.ERR, 'error creating filter: ',err)
    return {json = {status = 'error', error = err}}
  end
end

function m:Register(app)
  app:match('filtersearch', '/api/filter/search/:searchString', self.SearchFilter)
  app:match('userfilters', '/api/user/filters', self.GetUserFilters)
  app:match('userseenposts', '/api/user/seenposts', self.GetUserRecentSeen)
  app:match('/api/post/:postID/upvote', self.UpvotePost)
  app:match('/api/post/:postID/downvote', self.DownvotePost)
  app:match('/api/user/:userID/settings', self.GetUserSettings)
  app:match('/api/frontpage', self.GetFrontPage)
  app:match('/api/f/:filterName/posts', self.GetFilterPosts)
  app:match('/api/filters/create', self.CreateFilter)
end

return m
