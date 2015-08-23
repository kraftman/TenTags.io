

local uuid = require 'uuid'

local util = require("lapis.util")

local DAL = require 'DAL'

local m = {}

local function LoadUserFilters()
  return DAL:GetUserFrontPage()
end

local function LoadDefaults()
  return DAL:LoadDefaults()
end

local function FrontPage(self)

  local posts
  if self.session.current_user then
    posts = LoadUserFilters(self)
  else
    posts = LoadDefaults(self)
  end

  for _,v in pairs(posts) do
    print(v.link)
  end

  self.posts = posts
  return {render = 'frontpage'}
end

function m:Register(app)


  app:get('home','/',FrontPage)

end

return m
