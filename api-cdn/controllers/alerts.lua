

local m = {}


local respond_to = (require 'lapis.application').respond_to
local userAPI = require 'api.users'
local threadAPI = require 'api.threads'
local commentAPI = require 'api.comments'
local postAPI = require 'api.posts'
local tinsert = table.insert

local app = require 'app'
local app_helpers = require("lapis.application")
local capture_errors, assert_error = app_helpers.capture_errors, app_helpers.assert_error

app:get('alerts','/alerts/view',capture_errors(function(request)


  local alerts = userAPI:GetUserAlerts(request.session.userID)

  request.alerts = {
    posts = {},
    comments = {},
    threads = {},
    commentMentions = {}
  }

  for _, v in pairs(alerts) do

    if v:find('thread:') then
      local threadID = v:match('thread:(%w+)')

      local thread = threadAPI:GetThread(request.session.userID, threadID)
      for _,message in pairs(thread.messages) do
        message.username = userAPI:GetUser(message.createdBy).username
      end

      tinsert(request.alerts.threads, {alertType = 'thread', data = thread})
    elseif v:find('postComment:') then
      local postID, commentID = v:match('postComment:(%w+):(%w+)')
      local comment = commentAPI:GetComment(postID, commentID)
      local creator = userAPI:GetUser(comment.createdBy)
      comment.username = creator and creator.username or ''

      tinsert(request.alerts.comments,{alertType = 'comment', data = comment})
    elseif v:find('post') then
      local post = postAPI:GetPost(request.session.userID, v:match('post:(%w+)'))

      tinsert(request.alerts.posts, {alertType = 'post', data = post})
    elseif v:find('commentMention:') then
      local postID, commentID = v:match('commentMention:(%w+):(%w+)')
      local comment = commentAPI:GetComment(postID, commentID)
      local creator = userAPI:GetUser(comment.createdBy)
      comment.username = creator and creator.username or ''

      tinsert(request.alerts.commentMentions,{alertType = 'commentMention', data = comment})
    end
  end
  return { render = true}
end))


return m
