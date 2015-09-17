

local uuid = require 'uuid'

local util = require("lapis.util")

local DAL = require 'DAL'

local m = {}

local function LoadUserPosts()
  return DAL:GetUserFrontPage()
end

local function LoadDefaults()
  return DAL:LoadDefaults()
end

local function LoadUserFilters()
 return {}
end

local function LoadDefaultFilters()
  return DAL:LoadDefaultFilters()
end

local function FrontPage(self)


  if self.session.current_user then
    self.posts = LoadUserFilters(self)
  else
    self.posts = LoadDefaults(self)
  end



  return {render = 'frontpage'}
end

function m:Register(app)


  app:get('home','/',FrontPage)

end

return m
