local lapis = require("lapis")
local app = lapis.Application()
local schema = require("lapis.db.schema")
local types = schema.types

app:get("/", function()

  local t = ""
  for k, v in pairs(types) do
    t = t..' '..k..' '
  end
  return t
end)

return app
