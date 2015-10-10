


local util = require("lapis.util")
local api = require 'api.api'

local m = {}


local function FrontPage(self)
  self.pageNum = self.params.page or 1
  local range = 10*(self.pageNum-1)
  local filter = self.req.parsed_url.path:match('/(%w+)$')

  if self.session.userID then
    self.posts = api:GetUserFrontPage(self.session.userID)
    --self.posts = api:GetDefaultFrontPage(range,filter) or {}
  else
    self.posts = api:GetDefaultFrontPage(range,filter) or {}
  end
  return {render = 'frontpage'}
end

function m:Register(app)
  app:get('home','/',FrontPage)
  app:get('new','/new',FrontPage)
  app:get('best','/best',FrontPage)
end

return m
