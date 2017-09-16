
local commentAPI = require 'api.comments'

local postAPI = require 'api.posts'
local userAPI = require 'api.users'
local to_json = (require 'lapis.util').to_json

local respond_to = (require 'lapis.application').respond_to

local app_helpers = require("lapis.application")
local capture_errors, assert_error = app_helpers.capture_errors, app_helpers.assert_error
local app = require 'app'


app:match('deletecomment','/comment/delete/:postID/:commentID',respond_to({
  GET = m.DeleteComment,
  POST = m.DeleteComment
}))
app:get('viewcomment','/comment/:postID/:commentID',capture_errors(function(request)
  request.commentInfo = commentAPI:GetComment(request.params.postID,request.params.commentID)

  request.commentInfo.username = userAPI:GetUser(request.commentInfo.createdBy).username
  if request.commentInfo.shortURL then
    return { redirect_to = request:url_for("viewcommentshort",{commentShortURL = request.commentInfo.shortURL}) }
  end
  return {render = 'viewcomment'}
end))

app:get('viewcommentshort','/c/:commentShortURL', capture_errors(function(request)
  request.commentInfo = commentAPI:GetComment(request.params.commentShortURL)
  request.commentInfo.username = userAPI:GetUser(request.commentInfo.createdBy).username
  ngx.log(ngx.ERR, to_json(request.commentInfo))
  return {render = 'viewcomment'}
end))
app:get('subscribecomment','/comment/subscribe/:postID/:commentID', capture_errors(function(request)
  if not request.session.userID then
    return {render = 'pleaselogin'}
  end
  commentAPI:SubscribeComment(request.session.userID,request.params.postID, request.params.commentID)

  return { redirect_to = request:url_for("viewpost",{postID = request.params.postID}) }
end))

app:get('upvotecomment','/comment/upvote/:postID/:commentID/:commentHash', capture_errors(function(request)
  if not request.session.userID then
    return {render = 'pleaselogin'}
  end
  if not m.HashIsValid(request) then
    return 'hashes dont match'
  end
  local ok, err = commentAPI:VoteComment(request.session.userID, request.params.postID, request.params.commentID,'up')
  if ok then
    return 'success!'
  else
    return 'fail: ', err
  end
end))

app:get('downvotecomment','/comment/downvote/:postID/:commentID/:commentHash', capture_errors(function(request)
  if not request.session.userID then
    return {render = 'pleaselogin'}
  end
  if not m.HashIsValid(request) then
    return 'hashes dont match'
  end

  local ok, err = commentAPI:VoteComment(request.session.userID, request.params.postID, request.params.commentID,'down')
  if ok then
    return 'success'
  else
    return 'fail: ',err
  end
end))

app:post('newcomment','/comment/', capture_errors(function(request)

  if not request.session.userID then
    return {render = 'pleaselogin'}
  end

  local commentInfo = {
    parentID = request.params.parentID,
    postID = request.params.postID,
    createdBy = request.session.userID,
    text = request.params.commentText,
  }
  --ngx.log(ngx.ERR, to_json(request.params))
  local ok,err = commentAPI:CreateComment(request.session.userID, commentInfo)
  if ok then
    return { redirect_to = request:url_for("viewpost",{postID = request.params.postID}) }
  else

    return 'failed!'..(err or '')
  end

end))

app:match('viewcomment','/comment/:postID/:commentID', respond_to({
  GET = m.ViewComment,
  POST = capture_errors(function(request)
    if not request.session.userID then
      return {render = 'pleaselogin'}
    end

    local commentInfo = {
      postID = request.params.postID,
      text = request.params.commentText,
      id = request.params.commentID
    }

    local ok,err = commentAPI:EditComment(request.session.userID, commentInfo)
    if ok then
      return 'created!'
    else
      return 'failed: '..err
    end
  end)
}))



function m.HashIsValid(request)
  local realHash = ngx.md5(request.params.commentID..request.session.userID)
  if realHash ~= request.params.commentHash then
    ngx.log(ngx.ERR, 'hashes dont match!')
    return false
  end
  return true
end


function m.UpvoteComment(request)

end

function m.DownVoteComment(request)

end

function m.DeleteComment(request)

  if not request.session.userID then
    return {render = 'pleaselogin'}
  end
  local postID = request.params.postID
  local userID = request.session.userID
  local commentID = request.params.commentID

  local ok, err = commentAPI:DeleteComment(userID, postID, commentID)
  if ok then
    return 'deleted!'
  else
    return 'failed'..err
  end
end

return m
