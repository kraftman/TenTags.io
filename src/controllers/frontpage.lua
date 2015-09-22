

local uuid = require 'uuid'
local util = require("lapis.util")
local api = require 'api.api'

local m = {}


local function FrontPage(self)

  if self.session.current_user then

  else
    self.posts = api:GetDefaultFrontPage(offset)
    print(util.to_json(self.posts))
  end

  return {render = 'frontpage'}
end

function m:Register(app)


  app:get('home','/',FrontPage)

end

return m
