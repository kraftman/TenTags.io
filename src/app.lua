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

  if self.session.userID and self.session.masterID then
    
    if api:UserHasAlerts(self.session.userID) then

      self.userHasAlerts = true
    end
    self.otherUsers = api:GetMasterUsers(self.session.userID, self.session.masterID)
  end
  --ngx.log(ngx.ERR, to_json(user))

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
require 'comments':Register(app)
require 'alerts':Register(app)

-- TESTING
require 'test.perftest':Register(app)



return app
