

local lapis = require("lapis")
local app = lapis.Application()
local date = require("date")
local util = require 'util'
local errorHandler = require 'middleware.errorhandler'
--https://github.com/bungle/lua-resty-scrypt/issues/1
local checksession = require 'middleware.checksession'
local config = require("lapis.config").get()
local markdown = require 'lib.markdown'


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
  self.markdown = markdown
  self.UserHasFilter = util.UserHasFilter
  self.TimeAgo = util.TimeAgo
  self.Paginate = util.Paginate

end)

app.handle_error = errorHandler
app.handle_404 = function(self)
  ngx.log(ngx.NOTICE, 'Accessed unkown route: ',self.req.cmd_url)
  return {render = 'errors.404'}
end


-- Random stuff that doesnt go anywhere yet
app:get('createpage', '/nojs/create', function() return {render = 'createpage'} end)
app:get('about', '/about',function() return {render = true} end)


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
require 'admin':Register(app)
require 'search':Register(app)

if config._name == 'development' then
  require 'auto':Register(app)
  require 'testing.perftest':Register(app)
end

-- TESTING
app:get('/test', function(request) return 'test'..(ngx.var.geoip_city or '') end)


return app
