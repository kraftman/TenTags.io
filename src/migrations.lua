local schema = require("lapis.db.schema")
local types = schema.types

return {
  [1] = function()
    schema.create_table("users", {
      { "id", types.serial },
      { "title", types.text },
      { "content", types.text },

      "PRIMARY KEY (id)"
    })
  end
}
