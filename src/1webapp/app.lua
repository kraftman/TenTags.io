local lapis = require("lapis")
local app = lapis.Application()
local cache = (require 'cache')()
--https://github.com/bungle/lua-resty-scrypt/issues/1
app:enable("etlua")
app.layout = require 'views.layout'



app:before_filter(function(self)
  if self.session.current_user then
    self.filters = cache:LoadFilterList('default')
  else
    self.filters = cache:LoadFilterList('default')
  end
end)

require 'tags':Register(app)
require 'posts':Register(app)
require 'frontpage':Register(app)
require 'user':Register(app)
require 'settings':Register(app)
require 'messages':Register(app)
require 'filters':Register(app)



return app
