local lapis = require("lapis")
local app = lapis.Application()
app:enable("etlua")
local schema = require("lapis.db.schema")
local types = schema.types

app:get("/", function()

  local t = ""
  for k, v in pairs(types) do
    t = t..' '..k..' '
  end
  return t
end)

app:get('/register', function()
  return { render = "register" }
end)

app:post('/register',function()

  return
end)

return app
