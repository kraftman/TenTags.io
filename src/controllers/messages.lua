--[[
each messages is actually the start of a thread with
title
id
viewers (from and to users for now)

hash containing messages




]]

local m = {}


local respond_to = (require 'lapis.application').respond_to
local api = require 'api.api'


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
  api:CreateThread(msgInfo)

end

local function MessageReply(self)
  -- need the threadID
  local msgInfo = {}
  msgInfo.threadID = self.params.threadID
  msgInfo.body = self.params.body
  msgInfo.createdBy = self.session.userID
  api:CreateMessageReply(msgInfo)
end

function m:Register(app)
  app:match('viewmessages','/message/view',respond_to({GET = ViewMessages}))
  app:match('newmessage','/message/new',respond_to({GET = NewMessage, POST = CreateThread}))
  app:match('replymessage','/message/reply/:threadID',respond_to(POST = MessageReply))
end

return m
