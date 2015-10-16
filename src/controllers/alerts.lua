

local m = {}


local respond_to = (require 'lapis.application').respond_to
local api = require 'api.api'
local tinsert = table.insert

local function ViewAlerts(self)
  local alerts = api:GetUserAlerts(self.session.userID)
  api:UpdateLastUserAlertCheck(self.session.userID)
  self.alerts = {}

  local html = ''
  for _, v in pairs(alerts) do

    if v:find('thread:') then
      local threadID = v:match('thread:(%w+)')
      local thread = api:GetThread(threadID)
      tinsert(self.alerts, {alertType = 'thread', data = thread})
    elseif v:find('postComment:') then
      local postID, commentID = v:match('postComment:(%w+):(%w+)')
      local comment = api:GetComment(postID, commentID)
      comment.username = api:GetUserInfo(comment.createdBy).username
      ngx.log(ngx.ERR, to_json(comment))
      tinsert(self.alerts,{alertType = 'comment', data = comment})
    end
  end
  return { render = 'alerts'}
end

function m:Register(app)
  app:match('viewalerts','/alerts/view',respond_to({GET = ViewAlerts}))
end

return m
