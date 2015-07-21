local lapis = require("lapis")
local app = lapis.Application()
--https://github.com/bungle/lua-resty-scrypt/issues/1
app:enable("etlua")



require 'tags':Register(app)
require 'posts':Register(app)
require 'frontpage':Register(app)
require 'user':Register(app)
require 'settings':Register(app)



return app
