local threadAPI = require 'api.threads'
local respond_to = (require 'lapis.application').respond_to

local app_helpers = require("lapis.application")
local capture_errors, assert_error = app_helpers.capture_errors, app_helpers.assert_error

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
  ngx.log(ngx.ERR, to_json(request.threads))
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

    assert_error(threadAPI:CreateThread(request.session.userID, msgInfo))

    request.threads = threadAPI:GetThreads(request.session.userID, 0, 10)
    ngx.log(ngx.ERR, to_json(request.threads))
    return {render = 'message.view'}

  end)
}))

app:match('message.reply','/messages/reply/:threadID',respond_to({
  GET = capture_errors(function(request)
    if not request.session.userID then
      return {render = 'pleaselogin'}
    end
    --TODO check they are allowed to view the thread
    request.thread = assert_error(threadAPI:GetThread(request.session.userID, request.params.threadID))
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
    assert_error(threadAPI:CreateMessageReply(request.session.userID, msgInfo))
  end)
}))
