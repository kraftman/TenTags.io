

local lapis = require("lapis")
local app = lapis.Application()
local sessionAPI = require 'api.sessions'
local date = require("date")
local util = require 'util'
--https://github.com/bungle/lua-resty-scrypt/issues/1
local checksession = require 'middleware.checksession'


app:enable("etlua")
app.layout = require 'views.layout'
app.cookie_attributes = function(self)
  local expires = date(true):adddays(365):fmt("${http}")
  return "Expires=" .. expires .. "; Path=/; HttpOnly"
end


-- DEV ONLY
to_json = (require 'lapis.util').to_json
from_json = (require 'lapis.util').from_json

app:before_filter(function(self)
  checksession:Run(self)
end)

app:before_filter(function(self)

  self.enableAds = false

  self.GetFilterTemplate = util.GetFilterTemplate
  self.GetStyleSelected = util.GetStyleSelected
  self.filterStyles = util.filterStyles
  self.CalculateColor = util.CalculateColor
  self.TagColor = util.TagColor

end)


-- Random stuff that doesnt go anywhere yet
app:get('createpage', '/nojs/create', function() return {render = 'createpage'} end)


--TODO: change to this: https://gist.github.com/leafo/92ef8250f1f61e3f45ec

require 'tags':Register(app)
require 'posts':Register(app)
require 'frontpage':Register(app)
require 'user':Register(app)
require 'settings':Register(app)
require 'messages':Register(app)
require 'filters':Register(app)
require 'comments':Register(app)
require 'alerts':Register(app)
require 'api':Register(app)
require 'auto':Register(app)
require 'admin':Register(app)
require 'search':Register(app)


-- TESTING
--require 'testing.perftest':Register(app)



return app
