

local m = {}


local respond_to = (require 'lapis.application').respond_to
local api = require 'api.api'
local to_json = (require 'lapis.util').to_json


local function NewMessage(self)
  return {render = 'createmessage'}
end

local function ViewMessages(self)
  self.threads = api:GetThreads(self.session.userID)
  ngx.log(ngx.ERR, to_json(self.threads))
  return {render = 'viewmessages'}
end

local function CreateThread(self)
  local msgInfo = {
    title = self.params.subject,
    body = self.params.body,
    recipient = self.params.recipient,
    createdBy = self.session.userID
  }
  ngx.log(ngx.ERR,self.params.subject)
  api:CreateThread(self.session.userID, msgInfo)

end

local function CreateMessageReply(self)
  -- need the threadID
  local msgInfo = {}
  msgInfo.threadID = self.params.threadID
  msgInfo.body = self.params.body
  msgInfo.createdBy = self.session.userID
  api:CreateMessageReply(self.session.userID, msgInfo)
end

local function MessageReply(self)
  self.thread = api:GetThread(self.params.threadID)
  return {render = 'replymessage'}
end

function m:Register(app)
  app:match('viewmessages','/messages/view',respond_to({GET = ViewMessages}))
  app:match('newmessage','/messages/new',respond_to({GET = NewMessage, POST = CreateThread}))
  app:match('replymessage','/messages/reply/:threadID',respond_to({GET = MessageReply,POST = CreateMessageReply}))
end

return m
