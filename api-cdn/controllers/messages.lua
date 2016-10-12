

local m = {}


local respond_to = (require 'lapis.application').respond_to
local api = require 'api.api'
local to_json = (require 'lapis.util').to_json


function m.NewMessage(request)
  if not request.session.userID then
    return { render = 'pleaselogin' }
  end
  return {render = 'message.create'}
end

function m.ViewMessages(request)
  request.threads = api:GetThreads(request.session.userID)
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
  print('create thread')
  local ok, err = api:CreateThread(request.session.userID, msgInfo)
  if ok then
    request.threads = api:GetThreads(request.session.userID)
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
  api:CreateMessageReply(request.session.userID, msgInfo)
end

function m.MessageReply(request)
  request.thread = api:GetThread(request.params.threadID)
  return {render = 'message.reply'}
end

function m:Register(app)
  app:match('viewmessages','/messages/view',respond_to({GET = self.ViewMessages}))
  app:match('newmessage','/messages/new',respond_to({GET = self.NewMessage, POST = self.CreateThread}))
  app:match('replymessage','/messages/reply/:threadID',respond_to({GET = self.MessageReply,POST = self.CreateMessageReply}))
end

return m
