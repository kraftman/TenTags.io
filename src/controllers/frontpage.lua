


local util = require("lapis.util")
local api = require 'api.api'

local m = {}


local function FrontPage(self)
  self.pageNum = self.params.page or 1
  local range = 10*(self.pageNum-1)
  local filter = self.req.parsed_url.path:match('/(%w+)$')

  self.posts = api:GetUserFrontPage(self.session.userID or 'default',filter,range)
  -- if empty and logged in then redirect to seen posts
  if not posts or #posts == 0 then
    if filter ~= 'seen' then
      --return { redirect_to = self:url_for("seen") }
    end
  end

  return {render = 'frontpage'}
end

function m:Register(app)
  app:get('home','/',FrontPage)
  app:get('new','/new',FrontPage)
  app:get('best','/best',FrontPage)
  app:get('seen','/seen',FrontPage)
end

return m
