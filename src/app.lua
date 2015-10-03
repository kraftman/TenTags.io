local lapis = require("lapis")
local app = lapis.Application()
local api = require 'api.api'
--https://github.com/bungle/lua-resty-scrypt/issues/1
app:enable("etlua")
app.layout = require 'views.layout'
local csrf = require("lapis.csrf")


-- DEV ONLY
to_json = (require 'lapis.util').to_json


app:before_filter(function(self)
  self.csrf_token = csrf.generate_token(self,self.session.userID)
  self.userFilters = api:GetUserFilters(self.session.userID) or {}
end)

require 'tags':Register(app)
require 'posts':Register(app)
require 'frontpage':Register(app)
require 'user':Register(app)
require 'settings':Register(app)
require 'messages':Register(app)
require 'filters':Register(app)

-- TESTING
require 'test.perftest':Register(app)



return app
