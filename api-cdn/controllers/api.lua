

local m = {}


local respond_to = (require 'lapis.application').respond_to
local filterAPI = require 'api.filters'
local userAPI = require 'api.users'
local imageAPI = require 'api.images'
local tinsert = table.insert
local postAPI = require 'api.posts'
local commentAPI = require 'api.comments'


function m:Register(app)
  app:match('apisubscribefilter', '/api/filter/:filterID/sub', self.SubscribeFilter)
  app:match('filtersearch', '/api/filter/search/:searchString', self.SearchFilter)
  app:match('userfilters', '/api/user/filters', self.GetUserFilters)
  app:match('userseenposts', '/api/user/seenposts', self.GetUserRecentSeen)
  app:match('/api/post/:postID/upvote', self.UpvotePost)
  app:match('/api/comment/upvote/:postID/:commentID/:commentHash', m.UpvoteComment)
  app:match('/api/comment/downvote/:postID/:commentID/:commentHash', m.DownVoteComment)
  app:match('/api/post/:postID/downvote', self.DownvotePost)
  app:match('/api/user/:userID/settings', self.GetUserSettings)
  app:match('/api/frontpage', self.GetFrontPage)
  app:match('/api/f/:filterName/posts', self.GetFilterPosts)
  app:match('/api/filters/create', self.CreateFilter)
  app:match('/api/tags/:searchString', self.SearchTags)
  app:post('/api/i/', self.UploadImage)
end


function m.HashIsValid(request)
  local realHash = ngx.md5(request.params.commentID..request.session.userID)
  if realHash ~= request.params.commentHash then
    ngx.log(ngx.ERR, 'hashes dont match!')
    return false
  end
  return true
end



function m.UpvoteComment(request)
  if not request.session.userID then
    return {json = {error = 'you must be logged in!', data = {}}}
  end
  if not m.HashIsValid(request) then
    return 'hashes dont match'
  end
  local ok, err = commentAPI:VoteComment(request.session.userID, request.params.postID, request.params.commentID,'up')
  if ok then
    return {json = {error = false, data = {true}} }
  else
    return {json = {error = {err}, data = {}}}
  end
end

function m.DownVoteComment(request)
  if not request.session.userID then
    return {json = {error = 'you must be logged in!', data = {}}}
  end
  if not m.HashIsValid(request) then
    return 'hashes dont match'
  end

  local ok, err = commentAPI:VoteComment(request.session.userID, request.params.postID, request.params.commentID,'down')
  if ok then
    return {json = {error = false, data = {true}} }
  else
    return {json = {error = {err}, data = {}}}
  end
end

function m.SubscribeFilter(request)
  local userID = request.session.userID
  local filterID = request.params.filterID
  if not userID then
    return {json = {error = 'you must be logged in!', data = {}}}
  end
  local ok, err = userAPI:ToggleFilterSubscription(userID, userID, filterID)

  if ok then
    return {json = {error = false, data = ok} }
  else
    return {json = {error = {err}, data = {}}}
  end

end

function m.SearchFilter(request)

  if not request.session.userID then
    return {json = {error = 'you must be logged in!', data = {}}}
  end
  if not request.params.searchString then
    return {json = {error = 'no searchString provided', data = {}}}
  end
  if not request.session.userID then
    return {json = {error = 'you must be logged in!', data = {}}}
  end

  local ok, err = filterAPI:SearchFilters(request.session.userID, request.params.searchString)

  if ok then
    return {json ={error = false, data = ok} }
  else
    return {json = {error = {err}, data = {}}}
  end
end
--
function m.GetUserFilters(request)

  if not request.session.userID then
    return {json = {error = 'you must be logged in!', data = {}}}
  end
  local ok, err = userAPI:GetUserFilters(request.session.userID)
  if ok then
    return {json ={error = false, data = ok} }
  else
    return {json = {error = {err}, data = {}}}
  end
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
  if not request.session.userID then
    return {json = {status = 'error', data = {'you must be logged in to vote'}}}
  end
  if not HashIsValid(request) then
    return 'invalid hash'
  end
  local ok, err = postAPI:VotePost(request.session.userID, request.params.postID, 'up')
  if ok then
    return { json = {status = 'success', data = {}} }
  else
    return { json = {status = "error" }}
  end
end

function m.DownvotePost(request)
  if not request.session.userID then
    return {json = {status = 'error', data = {'you must be logged in to vote'}}}
  end
  if not HashIsValid(request) then
    return 'invalid hash'
  end
  local ok, err = postAPI:VotePost(request.session.userID, request.params.postID, 'down')
  if ok then
    return { json = {status = 'success', data = {}} }
  else
    return { json = {status = "error" }}
  end
end

function m.GetUserSettings(request)
  if not request.session.userID then
    return {json = {status = 'error', data = {'you must be logged in to vote'}}}
  end
  local ok, err = userAPI:GetUserSettings(request.session.userID)
  if ok then
    return {json = {status = 'success', data = ok}}
  else
    return {json = {status = 'error', message = err}}
  end
end

function m.GetFrontPage(request)
  local startAt = request.params.startAt or 1
  local range = request.params.range or 100
  local sortBy = request.params.sortby or 'fresh'
  local userID = request.session.userID or 'default'

  range = tonumber(range)

  local ok,err = userAPI:GetUserFrontPage(userID, nil, sortBy, startAt, range)
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

function m.UploadImage(request)
  -- if true then
  --   return {status = 400}
  -- end

  if not request.session.userID then
    return {json = {status = 'error', data = {'you must be logged in to upload'}}}
  end

  local fileData = request.params.file
  ngx.log(ngx.ERR, request.params.name, fileData.filename)
  if not request.params.file and (fileData.content == '') then
    return {json = {status = 'error', message = 'no file data'}, statu = 400}
  end

  local ok, err = imageAPI:CreateImage(request.session.userID, fileData)
-- return error code if needed
  if not ok then
    print(err)
    return {json = {status = 'error'}, status = 500}
  end

  return {json = {status = 'success', data = ok.id or {}}}

end


function m.CreateFilter(request)

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

  local ok, err = filterAPI:CreateFilter(request.session.userID, info)
  if ok then
    return { json = {status = 'success', data = ok }}
  else
    ngx.log(ngx.ERR, 'error creating filter: ',err)
    return {json = {status = 'error', error = err}}
  end
end

function m.SearchTags(request)
  local searchString = request.params.searchString
  if not searchString or type(searchString) ~= 'string' or searchString:gsub(' ','') == '' then
    return {json = {status = 'error', error = 'empty or bad string'}}
  end
  local ok, err = tagAPI:SearchTags(searchString)
  print('tt',to_json(ok))
  if ok then
    return {json = {status = 'success', data = ok}}
  else
    return {json = {status = 'error', data = err}}
  end
end


return m
