local lapis = require("lapis")
local app = lapis.Application()

require 'api':Register(app)

return app
