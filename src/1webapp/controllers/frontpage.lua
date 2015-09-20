

local uuid = require 'uuid'

local util = require("lapis.util")

local cache = require 'cache'()
local worker = require 'worker'

local m = {}


local function FrontPage(self)

  if self.session.current_user then
    self.posts = LoadUserFilters(self)
  else
    self.posts = cache:LoadFrontPage('default')
  end

  return {render = 'frontpage'}
end

function m:Register(app)


  app:get('home','/',FrontPage)

end

return m
