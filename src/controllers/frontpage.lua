
local api = require 'api.api'

local m = {}


local function FrontPage(self)
  self.pageNum = self.params.page or 1
  local range = 10*(self.pageNum-1)
  local filter = self.req.parsed_url.path:match('/(%w+)$')

  self.posts = api:GetUserFrontPage(self.session.userID or 'default',filter,range)
  -- if empty and logged in then redirect to seen posts
  if self.session.userID then
    for _,v in pairs(self.posts) do
      if v.id then
        v.hash = ngx.md5(v.id..self.session.userID)
      end
    end


  end

  if not self.posts or #self.posts == 0 then
    if filter ~= 'seen' then
      return { redirect_to = self:url_for("seen") }
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
