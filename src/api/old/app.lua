local lapis = require("lapis")
local app = lapis.Application()
local to_json = (require 'lapis.util').to_json

require 'api':Register(app)

return app
