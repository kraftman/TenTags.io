

local m = {}


local respond_to = (require 'lapis.application').respond_to
local api = require 'api.api'
local tinsert = table.insert

local function SearchFilter(self)
  if not self.params.searchString then
    return {json = {error = 'no searchString provided', data = {}}}
  end
  if not self.session.userID then
    return {json = {error = 'you must be logged in!', data = {}}}
  end
  local ok, err = api:SearchFilters(self.session.userID, self.params.searchString)
  print(to_json(ok))
  if ok then
    return {json ={error = {}, data = ok} }
  else
    return {json = {error = {err}, data = {}}}
  end
end

local function GetUserFilters(self)
  local ok, err = api:GetUserFilters(self.session.userID)
  return {json = {error = {err}, data = ok or {}}}
end

local function GetUserRecentSeen()

end

local function HashIsValid(self)
  --print(self.params.postID, self.session.userID)
  local realHash = ngx.md5(self.params.postID..self.session.userID)
  if realHash ~= self.params.hash then
    ngx.log(ngx.ERR, 'hashes dont match!')
    return false
  end
  return true
end


local function UpvotePost(self)
  if not HashIsValid(self) then
    return 'invalid hash'
  end
  local ok, err = api:VotePost(self.session.userID, self.params.postID, 'up')
  if ok then
    return { json = {status = 'success', data = {}} }
  else
    return { json = {status = "error" }}
  end
end

local function DownvotePost(self)
  if not HashIsValid(self) then
    return 'invalid hash'
  end
  local ok, err = api:VotePost(self.session.userID, self.params.postID, 'down')
  if ok then
    return { json = {status = 'success', data = {}} }
  else
    return { json = {status = "error" }}
  end
end

local function GetUserSettings(self)
  local ok, err = api:GetUserSettings(self.session.userID)
  if ok then
    return {json = {status = 'success', data = ok}}
  else
    return {json = {status = 'error', message = err}}
  end
end

local function GetUserFrontPage(self)
  local startAt = self.params.startAt or 1
  local endAt = self.params.endAt or 100
  local sortBy = self.params.sortby or 'fresh'

  local ok,err = api:GetUserFrontPage(self.session.userID or 'default',sortBy, startAt, endAt)
  if ok then
    return {json = {status = 'success', data = ok}}
  else
    return {json = {status = 'error', message = err}}
  end

end

function m:Register(app)
  --app:match('apilogin','/api/login',respond_to({POST = UserLogin}))
  app:match('filtersearch', '/api/filter/search/:searchString', SearchFilter)
  app:match('userfilters', '/api/user/filters', GetUserFilters)
  app:match('userseenposts', '/api/user/seenposts', GetUserRecentSeen)
  app:match('/api/post/:postID/upvote', UpvotePost)
  app:match('/api/post/:postID/downvote', DownvotePost)
  app:match('/api/user/:userID/settings', GetUserSettings)
  app:match('/api/user/:userID/frontpage', GetUserFrontPage)
end

return m
