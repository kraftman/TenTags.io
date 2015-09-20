local lapis = require("lapis")
local app = lapis.Application()
local to_json = (require 'lapis.util').to_json

app:get("/", function()
  return "Welcome to Lapis " .. require("lapis.version")
end)


require 'api':Register(app)

return app
