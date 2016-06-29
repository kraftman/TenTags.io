
--[[
  This checks the users cookies and loads some initial values that every request needs
  Then dispatches the request to the controller that can handle the request
  the controllers for the most part just do some basic checks before requesting stuff from the api
  then load the required information for the page to be rendered
--]]

local lapis = require("lapis")
local app = lapis.Application()
local api = require 'api.api'
--https://github.com/bungle/lua-resty-scrypt/issues/1
app:enable("etlua")
app.layout = require 'views.layout'
local csrf = require("lapis.csrf")


-- DEV ONLY
to_json = (require 'lapis.util').to_json
from_json = (require 'lapis.util').from_json


app:before_filter(function(self)
  --ngx.log(ngx.ERR, self.session.userID, to_json(self.session.username))

  self.enableAds = false

  if self.session.userID and self.session.masterID then
    if api:UserHasAlerts(self.session.userID) then
      self.userHasAlerts = true
    end
    self.otherUsers = api:GetMasterUsers(self.session.userID, self.session.masterID)
  end
  if not self.otherUsers then
    self.otherUsers = {}
  end
  --ngx.log(ngx.ERR, to_json(user))

  self.csrf_token = csrf.generate_token(self,self.session.userID)
  self.userFilters = api:GetUserFilters(self.session.userID or 'default') or {}
end)

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

-- TESTING
require 'test.perftest':Register(app)



return app
