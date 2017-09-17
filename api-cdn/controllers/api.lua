
local respond_to = (require 'lapis.application').respond_to
local filterAPI = require 'api.filters'
local userAPI = require 'api.users'
local imageAPI = require 'api.images'
local tinsert = table.insert
local postAPI = require 'api.posts'
local commentAPI = require 'api.comments'


local app = require 'app'
local app_helpers = require("lapis.application")
local capture_errors, assert_error = app_helpers.capture_errors_json, app_helpers.assert_error




local function HashIsValid(request)
  local realHash = ngx.md5(request.params.commentID..request.session.userID)
  if realHash ~= request.params.commentHash then
    ngx.log(ngx.ERR, 'hashes dont match!')
    return false
  end
  return true
end

app:match('apisubscribefilter', '/api/filter/:filterID/sub', capture_errors(function(request)
  local userID = request.session.userID
  local filterID = request.params.filterID
  if not userID then
    return {json = {error = 'you must be logged in!', data = {}}}
  end
  local ok = assert_error(userAPI:ToggleFilterSubscription(userID, userID, filterID))

  return {json = {error = false, data = ok} }

end))

app:match('filtersearch', '/api/filter/search/:searchString', capture_errors(function(request)

  if not request.session.userID then
    return {json = {error = 'you must be logged in!', data = {}}}
  end
  if not request.params.searchString then
    return {json = {error = 'no searchString provided', data = {}}}
  end
  if not request.session.userID then
    return {json = {error = 'you must be logged in!', data = {}}}
  end

  local ok = assert_error(filterAPI:SearchFilters(request.session.userID, request.params.searchString))

  return {json ={error = false, data = ok} }
end))

app:match('userfilters', '/api/user/filters', capture_errors(function(request)

  if not request.session.userID then
    return {json = {error = 'you must be logged in!', data = {}}}
  end
  local ok = userAPI:GetUserFilters(request.session.userID)

  return {json ={error = false, data = ok} }
end))

--app:match('userseenposts', '/api/user/seenposts', self.GetUserRecentSeen)
app:match('/api/post/:postID/upvote', capture_errors(function(request)
  if not request.session.userID then
    return {json = {status = 'error', data = {'you must be logged in to vote'}}}
  end
  if not HashIsValid(request) then
    return 'invalid hash'
  end
  local ok = assert_error(postAPI:VotePost(request.session.userID, request.params.postID, 'up'))

  return { json = {status = 'success', data = {}} }
end))

app:match('/api/comment/upvote/:postID/:commentID/:commentHash', capture_errors(function(request)
  if not request.session.userID then
    return {json = {error = 'you must be logged in!', data = {}}}
  end
  if not HashIsValid(request) then
    return 'hashes dont match'
  end
  assert_error(commentAPI:VoteComment(request.session.userID, request.params.postID, request.params.commentID,'up'))

  return {json = {error = false, data = {true}} }
end))

app:match('/api/comment/downvote/:postID/:commentID/:commentHash', capture_errors(function(request)
  if not request.session.userID then
    return {json = {error = 'you must be logged in!', data = {}}}
  end
  if not HashIsValid(request) then
    return 'hashes dont match'
  end

  assert_error(commentAPI:VoteComment(request.session.userID, request.params.postID, request.params.commentID,'down'))

  return {json = {error = false, data = {true}} }
end))

app:match('/api/post/:postID/downvote', capture_errors(function(request)
  if not request.session.userID then
    return {json = {status = 'error', data = {'you must be logged in to vote'}}}
  end
  if not HashIsValid(request) then
    return 'invalid hash'
  end
  assert_error(postAPI:VotePost(request.session.userID, request.params.postID, 'down'))

  return { json = {status = 'success', data = {}} }
end))

app:match('/api/user/:userID/settings', capture_errors(function(request)
  if not request.session.userID then
    return {json = {status = 'error', data = {'you must be logged in to vote'}}}
  end
  local ok = assert_error(userAPI:GetUserSettings(request.session.userID))

  return {json = {status = 'success', data = ok}}
end))

app:match('/api/frontpage', capture_errors(function(request)
  local startAt = request.params.startAt or 1
  local range = request.params.range or 100
  local sortBy = request.params.sortby or 'fresh'
  local userID = request.session.userID or 'default'

  range = tonumber(range)

  local ok = assert_error(userAPI:GetUserFrontPage(userID, nil, sortBy, startAt, range))

  return {json = {status = 'success', data = ok or {}}}
end))

app:match('/api/f/:filterName/posts', self.GetFilterPosts)
app:match('/api/filters/create', capture_errors(function(request)

  if not request.session.userID then
    return {json = {status = 'error', data = {'you must be logged in to vote'}}}
  end

  local requiredTagNames = from_json(request.params.requiredTagNames)
  local bannedTagNames = from_json(request.params.bannedTagNames)

  local info ={
    title = request.params.title,
    name= request.params.name:gsub(' ','') ,
    description = request.params.description,
    createdAt = ngx.time(),
    createdBy = request.session.userID,
    ownerID = request.session.userID
  }

  info.bannedTagNames = bannedTagNames
  info.requiredTagNames = requiredTagNames

  local ok = assert_error(filterAPI:CreateFilter(request.session.userID, info))

  return { json = {status = 'success', data = ok }}
end))

app:match('/api/tags/:searchString', capture_errors(function(request)
  local searchString = request.params.searchString
  if not searchString or type(searchString) ~= 'string' or searchString:gsub(' ','') == '' then
    return {json = {status = 'error', error = 'empty or bad string'}}
  end
  local ok = assert_error(tagAPI:SearchTags(searchString))

  return {json = {status = 'success', data = ok}}
end))

app:post('/api/i/', capture_errors(function(request)

    if not request.session.userID then
      return {json = {status = 'error', data = {'you must be logged in to upload'}}}
    end

    local fileData = request.params.file
    ngx.log(ngx.ERR, request.params.name, fileData.filename)
    if not request.params.file and (fileData.content == '') then
      return {json = {status = 'error', message = 'no file data'}, statu = 400}
    end

    local ok = assert_error(imageAPI:CreateImage(request.session.userID, fileData))

    return {json = {status = 'success', data = ok.id or {}}}

end))



app:post('taguser', '/user/tag/:userID', capture_errors(function(request)
  if not request.session.userID then
    return {render = 'pleaselogin'}
  end

  local userTag = request.params.tagUser

  assert_error(userAPI:LabelUser(request.session.userID, request.params.userID, userTag))

  return {json = {error = {err}, data = {}}}
end))



local function HashIsValid(request)
  --print(request.params.postID, request.session.userID)
  local realHash = ngx.md5(request.params.postID..request.session.userID)
  if realHash ~= request.params.hash then
    ngx.log(ngx.ERR, 'hashes dont match!')
    return false
  end
  return true
end



function m.GetFilterPosts(request)

  local startAt = request.params.startAt or 1
  local endAt = request.params.endAt or 100
  local sortBy = request.params.sortby or 'fresh'
  
end
