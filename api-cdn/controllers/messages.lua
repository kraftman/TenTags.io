local threadAPI = require 'api.threads'
local userAPI = require 'api.users'
local respond_to = (require 'lapis.application').respond_to

local app_helpers = require("lapis.application")
local capture_errors, assert_error = app_helpers.capture_errors, app_helpers.assert_error
local yield_error = app_helpers.yield_error

local to_json = (require 'lapis.util').to_json
local app = require 'app'

app:match('message.view','/messages',capture_errors(function(request)
  if not request.session.userID then
    return {render = 'pleaselogin'}
  end

  local startAt = request.params.startAt or 0
  if not tonumber(startAt) then
    startAt = 0
  end
  local range = request.params.range or 10
  if not tonumber(range) then
    range = 10
  end

  request.threads = threadAPI:GetThreads(request.session.userID, startAt, range)
  for k,thread in pairs(request.threads) do
    for k,message in pairs(thread.messages) do
      message.username = userAPI:GetUser(message.createdBy).username
    end
  end

  return {render = true}
end))

app:match('message.create','/messages/new',respond_to({
  GET = capture_errors(function(request)
    if not request.session.userID then
      return { render = 'pleaselogin' }
    end
    return {render = true}
  end),

  POST = capture_errors(function(request)
    if not request.session.userID then
      return {render = 'pleaselogin'}
    end

    local msgInfo = {
      title = request.params.subject,
      body = request.params.body,
      recipient = request.params.recipient,
      createdBy = request.session.userID
    }

    threadAPI:CreateThread(request.session.userID, msgInfo)

    request.threads = threadAPI:GetThreads(request.session.userID, 0, 10)

    return {redirect_to = request:url_for('message.view')}

  end)
}))

app:match('message.reply','/messages/reply/:threadID',respond_to({
  GET = capture_errors(function(request)
    if not request.session.userID then
      return {render = 'pleaselogin'}
    end
    --TODO check they are allowed to view the thread
    local userID = request.session.userID

    local thread, err = threadAPI:GetThread(request.session.userID, request.params.threadID)
    if not thread then
      yield_error('thread not found')
    end

    local found
    print(to_json(thread.messages))
    for k,v in pairs(thread.viewers) do
      if v == userID then
        found = true
        break
      end
    end
    if not found then
      print('viewer not found')
      yield_error('you dont have permission to view this message')
    end

    request.thread = thread

    for k,message in pairs(request.thread.messages) do
      message.username = userAPI:GetUser(message.createdBy).username
    end

    return {render = 'message.reply'}
  end),
  POST = capture_errors(function(request)

    if not request.session.userID then
      return {render = 'pleaselogin'}
    end

    local msgInfo = {}
    msgInfo.threadID = request.params.threadID
    msgInfo.body = request.params.body
    msgInfo.createdBy = request.session.userID
    threadAPI:CreateMessageReply(request.session.userID, msgInfo)
    return 'done'
  end)
}))
