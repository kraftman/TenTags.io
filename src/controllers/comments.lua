

local util = require("lapis.util")
local api = require 'api.api'

local m = {}


local function ViewComment(self)
  self.commentInfo = api:GetComment(self.params.commentID)
  ngx.log(ngx.ERR, to_json(self.commentInfo))
  return {render = 'st.comment'}

end

function m:Register(app)
  app:get('viewcomment','/comment/:commentID',ViewComment)
end

return m
