

local m = {}

local userAPI = require 'api.users'
local threadAPI = require 'api.threads'
local commentAPI = require 'api.comments'
local postAPI = require 'api.posts'
local tinsert = table.insert

local app = require 'app'
local app_helpers = require 'lapis.application'
local util = require 'util'
local capture_errors, assert_error = app_helpers.capture_errors, app_helpers.assert_error

local function processThread(request, alertData)
  local threadID = alertData:match('thread:(%w+)')

  local thread = assert_error(threadAPI:GetThread(request.session.userID, threadID))
  for _,message in pairs(thread.messages) do
    message.username = userAPI:GetUser(message.createdBy).username
  end

  tinsert(request.alerts.threads, {alertType = 'thread', data = thread})
end

local function processComment(request, alertData)
  local postID, commentID = alertData:match('postComment:(%w+):(%w+)')
  local comment = commentAPI:GetComment(postID, commentID)
  local creator = userAPI:GetUser(comment.createdBy)
  comment.username = creator and creator.username or ''

  tinsert(request.alerts.comments,{alertType = 'comment', data = comment})

end

local function processPost(request, alertData)

  local post = postAPI:GetPost(request.session.userID, alertData:match('post:(%w+)'))

  tinsert(request.alerts.posts, {alertType = 'post', data = post})
end

local function processCommentMention(request, alertData)

  local postID, commentID = alertData:match('commentMention:(%w+):(%w+)')
  local comment = commentAPI:GetComment(postID, commentID)
  local creator = userAPI:GetUser(comment.createdBy)
  comment.username = creator and creator.username or ''

  tinsert(request.alerts.commentMentions,{alertType = 'commentMention', data = comment})
end

app:get('alerts','/alerts/view',capture_errors({
  on_error = util.HandleError,
  function(request)

    local alerts = userAPI:GetUserAlerts(request.session.userID)

    request.alerts = {
      posts = {},
      comments = {},
      threads = {},
      commentMentions = {}
    }

    for _, alertData in pairs(alerts) do
      if alertData:find('thread:') then
        processThread(request, alertData)
      elseif alertData:find('postComment:') then
        processComment(request, alertData)
      elseif alertData:find('post') then
        processPost(request, alertData)
      elseif alertData:find('commentMention:') then
        processCommentMention(request, alertData)
      end
    end
    return { render = true}
  end
}))


return m
