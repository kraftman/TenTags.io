
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





local function HashIsValid(values)
  local realHash = ngx.md5(request.params.commentID..request.session.userID)
  if realHash ~= request.params.commentHash then
    ngx.log(ngx.ERR, 'hashes dont match!')
    return false
  end
  return true
end

app:match('api-subscribefilter', '/api/filter/:filterID/sub', capture_errors(function(request)
  local userID = request.session.userID
  local filterID = request.params.filterID

  local ok = userAPI:ToggleFilterSubscription(userID, userID, filterID)

  return {json = {error = false, data = ok} }

end))

app:match('api-filtersearch', '/api/filter/search/:searchString', capture_errors(function(request)

  if not request.params.searchString then
    return {json = {error = 'no searchString provided', data = {}}}
  end

  local ok = filterAPI:SearchFilters(request.session.userID, request.params.searchString)

  return {json ={error = false, data = ok} }
end))

app:match('api-userfilters', '/api/user/filters', capture_errors(function(request)

  local ok = userAPI:GetUserFilters(request.session.userID)

  return {json ={error = false, data = ok} }
end))

--app:match('userseenposts', '/api/user/seenposts', self.GetUserRecentSeen)
app:match('api-upvotepost', '/api/post/:postID/upvote', capture_errors(function(request)

  local hash = request.params.hash
  local postID = request.params.postID
  local userID = request.params.userID
  if not hash or not postID or not userID then
    return {json = {error = 'invalid data!', data = {}}}
  end
  if not hash == ngx.md5(postID..userID) then
    return {json = {error = 'invalid hash!', data = {}}}
  end
  postAPI:VotePost(request.session.userID, request.params.postID, 'up')

  return { json = {status = 'success', data = {}} }
end))

app:match('api-upvotecomment', '/api/comment/upvote/:postID/:commentID/:commentHash', capture_errors(function(request)

  if not HashIsValid(request) then
    return 'hashes dont match'
  end
  commentAPI:VoteComment(request.session.userID, request.params.postID, request.params.commentID,'up')

  return {json = {error = false, data = {true}} }
end))

app:match('api-downvotecomment', '/api/comment/downvote/:postID/:commentID/:commentHash', capture_errors(function(request)
  if not request.session.userID then
    return {json = {error = 'you must be logged in!', data = {}}}
  end
  if not HashIsValid(request) then
    return 'hashes dont match'
  end

  commentAPI:VoteComment(request.session.userID, request.params.postID, request.params.commentID,'down')

  return {json = {error = false, data = {true}} }
end))

app:match('api-downvotepost', '/api/post/:postID/downvote', capture_errors(function(request)
  if not request.session.userID then
    return {json = {status = 'error', data = {'you must be logged in to vote'}}}
  end
  if not HashIsValid(request) then
    return 'invalid hash'
  end
  postAPI:VotePost(request.session.userID, request.params.postID, 'down')

  return { json = {status = 'success', data = {}} }
end))

app:match('api-settings', '/api/user/:userID/settings', capture_errors(function(request)

  local ok = userAPI:GetUserSettings(request.session.userID)

  return {json = {status = 'success', data = ok}}
end))

app:match('api-frontpage', '/api/frontpage', capture_errors(function(request)
  local startAt = request.params.startAt or 1
  local range = request.params.range or 100
  local sortBy = request.params.sortby or 'fresh'
  local userID = request.session.userID or 'default'

  range = tonumber(range)

  local ok = userAPI:GetUserFrontPage(userID, nil, sortBy, startAt, range)
  return {json = {status = 'success', data = ok or {}}}
end))

--app:match('api-filterposts', '/api/f/:filterName/posts', GetFilterPosts)
app:match('api-createfilter', '/api/filters/create', capture_errors(function(request)

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

  local ok = filterAPI:CreateFilter(request.session.userID, info)

  return { json = {status = 'success', data = ok }}
end))

app:match('api-searchtags', '/api/tags/:searchString', capture_errors(function(request)
  local searchString = request.params.searchString
  if not searchString or type(searchString) ~= 'string' or searchString:gsub(' ','') == '' then
    return {json = {status = 'error', error = 'empty or bad string'}}
  end
  local ok = tagAPI:SearchTags(searchString)

  return {json = {status = 'success', data = ok}}
end))

app:post('api-uploadfile', '/api/i/', capture_errors(function(request)

    if not request.session.userID then
      return {json = {status = 'error', data = {'you must be logged in to upload'}}}
    end

    local fileData = request.params.file
    ngx.log(ngx.ERR, request.params.name, fileData.filename)
    if not request.params.file and (fileData.content == '') then
      return {json = {status = 'error', message = 'no file data'}, statu = 400}
    end

    local ok = imageAPI:CreateImage(request.session.userID, fileData)

    return {json = {status = 'success', data = ok and ok.id or {}}}

end))

app:post('api-taguser', '/user/tag/:userID', capture_errors(function(request)
  if not request.session.userID then
    return {render = 'pleaselogin'}
  end

  local userTag = request.params.tagUser

  userAPI:LabelUser(request.session.userID, request.params.userID, userTag)

  return {json = {error = {err}, data = {}}}
end))
