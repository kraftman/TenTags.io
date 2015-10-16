

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

function m:Register(app)
  app:get('viewcomment','/comment/:postID/:commentID',ViewComment)
  app:get('subscribecomment','/comment/subscribe/:postID/:commentID',SubscribeComment)
end

return m
