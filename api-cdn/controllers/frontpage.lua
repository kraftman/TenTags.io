
local api = require 'api.api'

local m = {}

local postTemplates = {
  default = 'views.st.postelement',
  minimal = 'views.st.postelement-min'
}

local function GetPostTemplate(self)

  local postStyle = 'default'
  if self.session.userID then
    postStyle = 'default'
  else
    postStyle = 'default'
  end
  postStyle = 'default'

  if not postTemplates[postStyle] then
    return postTemplates.default
  end

  return postTemplates[postStyle]
end


local function FrontPage(self)
  self.pageNum = self.params.page or 1
  local range = 10*(self.pageNum-1)
  local filter = self.req.parsed_url.path:match('/(%w+)$')

  self.posts = api:GetUserFrontPage(self.session.userID or 'default',filter,range)

  if self.session.userID then
    for _,v in pairs(self.posts) do
      if v.id then
        v.hash = ngx.md5(v.id..self.session.userID)
      end
    end
  end

  -- if empty and logged in then redirect to seen posts
  if not self.posts or #self.posts == 0 then
    if filter ~= 'seen' then
      --return { redirect_to = self:url_for("seen") }
    end
  end

  self.GetPostTemplate = GetPostTemplate

  return {render = 'frontpage'}
end

function m:Register(app)
  app:get('home','/',FrontPage)
  app:get('new','/new',FrontPage)
  app:get('best','/best',FrontPage)
  app:get('seen','/seen',FrontPage)
end

return m
