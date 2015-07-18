local schema = require("lapis.db.schema")
local types = schema.types

return {
  [1] = function()
    schema.create_table("user", {
      { "id", types.uuid },
      { "username", types.text },
      { "email", types.text },
      { "passwordHash", types.text },
      { "active", types.boolean},
    })
  end
}
