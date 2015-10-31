

local util = require("lapis.util")
local api = require 'api.api'

local m = {}


local function ViewComment(self)
  self.commentInfo = api:GetComment(self.params.postID,self.params.commentID)

  self.commentInfo.username = api:GetUserInfo(self.commentInfo.createdBy).username
  ngx.log(ngx.ERR, to_json(self.commentInfo))
  return {render = 'st.comment'}

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
end

local function DownVoteComment(self)
  if not HashIsValid(self) then
    return 'hashes dont match'
  end

  local ok, err = api:VoteComment(self.session.userID, self.params.postID, self.params.commentID,'down')
end

function m:Register(app)
  app:get('viewcomment','/comment/:postID/:commentID',ViewComment)
  app:get('subscribecomment','/comment/subscribe/:postID/:commentID',SubscribeComment)
  app:get('upvotecomment','/comment/upvote/:postID/:commentID/:commentHash', UpvoteComment)
  app:get('downvotecomment','/comment/downvote/:postID/:commentID/:commentHash',DownVoteComment)
end

return m
