

local m = {}


local respond_to = (require 'lapis.application').respond_to
local userAPI = require 'api.users'
local threadAPI = require 'api.threads'
local commentAPI = require 'api.comments'
local postAPI = require 'api.posts'
local tinsert = table.insert


function m:Register(app)
  app:match('viewalerts','/alerts/view',respond_to({GET = self.ViewAlerts}))
end

function m.ViewAlerts(request)
  if not request.session.userID then
    return {render = 'pleaselogin'}
  end
  
  local alerts = userAPI:GetUserAlerts(request.session.userID)

  request.alerts = {}

  for _, v in pairs(alerts) do

    if v:find('thread:') then
      local threadID = v:match('thread:(%w+)')
      local thread = threadAPI:GetThread(threadID)
      tinsert(request.alerts, {alertType = 'thread', data = thread})
    elseif v:find('postComment:') then
      local postID, commentID = v:match('postComment:(%w+):(%w+)')
      local comment = commentAPI:GetComment(postID, commentID)
      local creator = userAPI:GetUser(comment.createdBy)
      comment.username = creator and creator.username or ''

      tinsert(request.alerts,{alertType = 'comment', data = comment})
    elseif v:find('post') then
      local post = postAPI:GetPost(request.session.userID, v:match('post:(%w+)'))

      tinsert(request.alerts, {alertType = 'post', data = post})
    end
  end
  return { render = 'alerts'}
end


return m
