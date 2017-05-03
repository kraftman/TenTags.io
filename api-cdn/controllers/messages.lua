

local m = {}

local threadAPI = require 'api.threads'
local respond_to = (require 'lapis.application').respond_to

local to_json = (require 'lapis.util').to_json


function m.NewMessage(request)
  if not request.session.userID then
    return { render = 'pleaselogin' }
  end
  return {render = 'message.create'}
end

function m.ViewMessages(request)
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
  return {render = 'message.view'}
end

function m.CreateThread(request)
  local msgInfo = {
    title = request.params.subject,
    body = request.params.body,
    recipient = request.params.recipient,
    createdBy = request.session.userID
  }

  local ok, err = threadAPI:CreateThread(request.session.userID, msgInfo)
  if ok then
    request.threads = threadAPI:GetThreads(request.session.userID, 0, 10)
    ngx.log(ngx.ERR, to_json(request.threads))
    return {render = 'message.view'}
  else
    return 'fail '..err
  end
end

function m.CreateMessageReply(request)
  -- need the threadID
  local msgInfo = {}
  msgInfo.threadID = request.params.threadID
  msgInfo.body = request.params.body
  msgInfo.createdBy = request.session.userID
  threadAPI:CreateMessageReply(request.session.userID, msgInfo)
end

function m.MessageReply(request)
  request.thread = threadAPI:GetThread(request.params.threadID)
  return {render = 'message.reply'}
end

function m:Register(app)
  app:match('viewmessages','/messages',respond_to({GET = self.ViewMessages}))
  app:match('newmessage','/messages/new',respond_to({GET = self.NewMessage, POST = self.CreateThread}))
  app:match('replymessage','/messages/reply/:threadID',respond_to({GET = self.MessageReply,POST = self.CreateMessageReply}))
end

return m
