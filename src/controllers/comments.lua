

local api = require 'api.api'
local to_json = (require 'lapis.util').to_json

local respond_to = (require 'lapis.application').respond_to

local m = {}


local function ViewComment(self)
  self.commentInfo = api:GetComment(self.params.postID,self.params.commentID)

  self.commentInfo.username = api:GetUserInfo(self.commentInfo.createdBy).username
  ngx.log(ngx.ERR, to_json(self.commentInfo))
  return {render = 'viewcomment'}

end

local function ViewShortURLComment(self)
  self.commentInfo = api:GetComment(self.params.commentShortURL)
  self.commentInfo.username = api:GetUserInfo(self.commentInfo.createdBy).username
  ngx.log(ngx.ERR, to_json(self.commentInfo))
  return {render = 'viewcomment'}

end

-- needs moving to comments controller
local function CreateComment(self)


  local commentInfo = {
    parentID = self.params.parentID,
    postID = self.params.postID,
    createdBy = self.session.userID,
    text = self.params.commentText,
  }
  ngx.log(ngx.ERR, to_json(self.params))
  local ok = api:CreateComment(self.session.userID, commentInfo)
  if ok then
    return 'created!'
  else
    return 'failed!'
  end

end

local function EditComment(self)
  local commentInfo = {
    postID = self.params.postID,
    text = self.params.commentText,
    id = self.params.commentID
  }

  local ok,err = api:EditComment(self.session.userID, commentInfo)
  if ok then
    return 'created!'
  else
    return 'failed: '..err
  end
end

local function SubscribeComment(self)
  api:SubscribeComment(self.session.userID,self.params.postID, self.params.commentID)

  return { redirect_to = self:url_for("viewpost",{postID = self.params.postID}) }

end

local function HashIsValid(self)
  local realHash = ngx.md5(self.params.commentID..self.session.userID)
  if realHash ~= self.params.commentHash then
    ngx.log(ngx.ERR, 'hashes dont match!')
    return false
  end
  return true
end

local function UpvoteComment(self)
  if not HashIsValid(self) then
    return 'hashes dont match'
  end
  local ok, err = api:VoteComment(self.session.userID, self.params.postID, self.params.commentID,'up')
  if ok then
    return 'success!'
  else
    return 'fail: ', err
  end
end

local function DownVoteComment(self)
  if not HashIsValid(self) then
    return 'hashes dont match'
  end

  local ok, err = api:VoteComment(self.session.userID, self.params.postID, self.params.commentID,'down')
  if ok then
    return 'success'
  else
    return 'fail: ',err
  end
end

local function DeleteComment(self)
  local postID = self.params.postID
  local userID = self.session.userID
  local commentID = self.params.commentID

  local ok, err = api:DeleteComment(userID, postID, commentID)
  if ok then
    return 'deleted!'
  else
    return 'failed'..err
  end
end

function m:Register(app)
  app:match('deletecomment','/comment/delete/:postID/:commentID',respond_to({
    GET = DeleteComment,
    POST = DeleteComment
  }))
  app:get('viewcomment','/comment/:postID/:commentID',ViewComment)

  app:get('viewcommentshort','/comment/:commentShortURL',ViewShortURLComment)
  app:get('subscribecomment','/comment/subscribe/:postID/:commentID',SubscribeComment)
  app:get('upvotecomment','/comment/upvote/:postID/:commentID/:commentHash', UpvoteComment)
  app:get('downvotecomment','/comment/downvote/:postID/:commentID/:commentHash',DownVoteComment)
  app:post('newcomment','/comment/',CreateComment)

  app:match('viewcomment','/comment/:postID/:commentID', respond_to({
    GET = ViewComment,
    POST = EditComment
  }))
end

return m
