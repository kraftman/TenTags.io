

local m = {}


local respond_to = (require 'lapis.application').respond_to
local userAPI = require 'api.users'
local threadAPI = require 'api.threads'
local commentAPI = require 'api.comments'
local tinsert = table.insert

function m.ViewAlerts(request)
  local alerts = userAPI:GetUserAlerts(request.session.userID)
  userAPI:UpdateLastUserAlertCheck(request.session.userID)
  request.alerts = {}

  for _, v in pairs(alerts) do

    if v:find('thread:') then
      local threadID = v:match('thread:(%w+)')
      local thread = threadAPI:GetThread(threadID)
      tinsert(request.alerts, {alertType = 'thread', data = thread})
    elseif v:find('postComment:') then
      local postID, commentID = v:match('postComment:(%w+):(%w+)')
      local comment = commentAPI:GetComment(postID, commentID)
      comment.username = userAPI:GetUser(comment.createdBy).username

      tinsert(request.alerts,{alertType = 'comment', data = comment})
    end
  end
  return { render = 'alerts'}
end

function m:Register(app)
  app:match('viewalerts','/alerts/view',respond_to({GET = self.ViewAlerts}))
end

return m
