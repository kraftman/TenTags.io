
--[[
need to handle
inbox
sent
alert that there are new messages
show conversation threads between people



]]


local m = {}


local respond_to = (require 'lapis.application').respond_to

local function SendMessage()
  return 'meep'

end

function m:Register(app)

  app:match('sendmessage','/message/new',respond_to({GET = SendMessage}))
end

return m
