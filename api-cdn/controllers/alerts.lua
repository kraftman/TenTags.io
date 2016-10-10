

local m = {}


local respond_to = (require 'lapis.application').respond_to
local api = require 'api.api'
local tinsert = table.insert

function m.ViewAlerts(request)
  local alerts = api:GetUserAlerts(request.session.userID)
  api:UpdateLastUserAlertCheck(request.session.userID)
  request.alerts = {}

  for _, v in pairs(alerts) do

    if v:find('thread:') then
      local threadID = v:match('thread:(%w+)')
      local thread = api:GetThread(threadID)
      tinsert(request.alerts, {alertType = 'thread', data = thread})
    elseif v:find('postComment:') then
      local postID, commentID = v:match('postComment:(%w+):(%w+)')
      local comment = api:GetComment(postID, commentID)
      comment.username = api:GetUser(comment.createdBy).username

      tinsert(request.alerts,{alertType = 'comment', data = comment})
    end
  end
  return { render = 'alerts'}
end

function m:Register(app)
  app:match('viewalerts','/alerts/view',respond_to({GET = self.ViewAlerts}))
end

return m
