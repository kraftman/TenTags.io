local lapis = require("lapis")
local app = lapis.Application()
--https://github.com/bungle/lua-resty-scrypt/issues/1
app:enable("etlua")
app.layout = require 'views.layout'



require 'tags':Register(app)
require 'posts':Register(app)
require 'frontpage':Register(app)
require 'user':Register(app)
require 'settings':Register(app)
require 'messages':Register(app)
require 'filters':Register(app)



return app
