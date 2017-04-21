

local api = require 'api.api'
local to_json = (require 'lapis.util').to_json

local respond_to = (require 'lapis.application').respond_to

local m = {}


function m.ViewComment(request)
  request.commentInfo = api:GetComment(request.params.postID,request.params.commentID)

  request.commentInfo.username = api:GetUser(request.commentInfo.createdBy).username
  ngx.log(ngx.ERR, to_json(request.commentInfo))
  return {render = 'viewcomment'}

end

function m.ViewShortURLComment(request)
  request.commentInfo = api:GetComment(request.params.commentShortURL)
  request.commentInfo.username = api:GetUser(request.commentInfo.createdBy).username
  ngx.log(ngx.ERR, to_json(request.commentInfo))
  return {render = 'viewcomment'}

end

-- needs moving to comments controller
function m.CreateComment(request)


  local commentInfo = {
    parentID = request.params.parentID,
    postID = request.params.postID,
    createdBy = request.session.userID,
    text = request.params.commentText,
  }
  --ngx.log(ngx.ERR, to_json(request.params))
  local ok = api:CreateComment(request.session.userID, commentInfo)
  if ok then
    print('created')
    return 'created!'
  else
    print('failed')
    return 'failed!'
  end

end

function m.EditComment(request)
  local commentInfo = {
    postID = request.params.postID,
    text = request.params.commentText,
    id = request.params.commentID
  }

  local ok,err = api:EditComment(request.session.userID, commentInfo)
  if ok then
    return 'created!'
  else
    return 'failed: '..err
  end
end

function m.SubscribeComment(request)
  api:SubscribeComment(request.session.userID,request.params.postID, request.params.commentID)

  return { redirect_to = request:url_for("viewpost",{postID = request.params.postID}) }

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
  if not HashIsValid(request) then
    return 'hashes dont match'
  end
  local ok, err = api:VoteComment(request.session.userID, request.params.postID, request.params.commentID,'up')
  if ok then
    return 'success!'
  else
    return 'fail: ', err
  end
end

function m.DownVoteComment(request)
  if not HashIsValid(request) then
    return 'hashes dont match'
  end

  local ok, err = api:VoteComment(request.session.userID, request.params.postID, request.params.commentID,'down')
  if ok then
    return 'success'
  else
    return 'fail: ',err
  end
end

function m.DeleteComment(request)
  local postID = request.params.postID
  local userID = request.session.userID
  local commentID = request.params.commentID

  local ok, err = api:DeleteComment(userID, postID, commentID)
  if ok then
    return 'deleted!'
  else
    return 'failed'..err
  end
end

function m:Register(app)
  app:match('deletecomment','/comment/delete/:postID/:commentID',respond_to({
    GET = m.DeleteComment,
    POST = m.DeleteComment
  }))
  app:get('viewcomment','/comment/:postID/:commentID',m.ViewComment)

  app:get('viewcommentshort','/c/:commentShortURL', m.ViewShortURLComment)
  app:get('subscribecomment','/comment/subscribe/:postID/:commentID', m.SubscribeComment)
  app:get('upvotecomment','/comment/upvote/:postID/:commentID/:commentHash', m.UpvoteComment)
  app:get('downvotecomment','/comment/downvote/:postID/:commentID/:commentHash', m.DownVoteComment)
  app:post('newcomment','/comment/', m.CreateComment)

  app:match('viewcomment','/comment/:postID/:commentID', respond_to({
    GET = m.ViewComment,
    POST = m.EditComment
  }))
end

return m
