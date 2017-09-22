

local lapis = require("lapis")
local app = lapis.Application()
package.loaded.app = app
local date = require("date")
local util = require 'util'
local lapisUtil = require("lapis.util")
local errorHandler = require 'middleware.errorhandler'
--https://github.com/bungle/lua-resty-scrypt/issues/1
local checksession = require 'middleware.checksession'
local config = require("lapis.config").get()
local markdown = require 'lib.markdown'

local app_helpers = require("lapis.application")
local capture_errors, assert_error = app_helpers.capture_errors, app_helpers.assert_error



app:enable("etlua")
app.layout = require 'views.layout'
app.cookie_attributes = function(self)
  local expires = date(true):adddays(365):fmt("${http}")
  return "Expires=" .. expires .. "; Path=/; HttpOnly"
end



-- DEV ONLY
-- TODO move this to env
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
  self.handle_error = errorHandler
  capture_errors(util.RateLimit)(self)
  self.res.headers['Content-Security-Policy'] = "default-src 'self'; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com data:; script-src 'self' www.google-analytics.com;img-src 'self' www.google-analytics.com;"
  self.res.headers['X-Frame-Options'] = 'x-frame-options: SAMEORIGIN'
  self.res.headers['X-Xss-Protection'] = '1; mode=block'
  self.res.headers['X-Content-Type-Options'] = 'nosniff'
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

require 'posts'
require 'frontpage'
require 'user'
require 'settings'
require 'messages'
require 'filters'
require 'comments'
require 'alerts'
require 'api'
require 'admin'
require 'search'
require 'images'

if config._name == 'development' then
  require 'auto':Register(app)
  require 'testing.perftest':Register(app)


  -- TESTING
  app:get('/test', function(request)
    local test = 'test: '
    test = test..(ngx.var.geoip_region or 'no region')
    test = test..(ngx.var.geoip_org or 'no org')
    test = test..(ngx.var.geoip_city or 'no city')
    test = test..(ngx.var.geoip_region_name or 'no region')
    test = test..ngx.var.remote_addr

    for k,v in pairs(request.req.headers) do
      if type(v) == 'string' then
        print(k, ' ', v)
      end
    end
    print('this')


    return test

  end)
end



return app
