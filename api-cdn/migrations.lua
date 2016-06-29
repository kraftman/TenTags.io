local schema = require("lapis.db.schema")
local types = schema.types

return {
  [1] = function()
    schema.create_table("user", {
      { "id", types.text },
      { "username", types.text },
      { "email", types.text },
      { "passwordHash", types.text },
      { "active", types.boolean},
    })
    schema.create_table("post", {
      { "id", types.text },
      { "parentID",types.text},
      { "title", types.text },
      { "link", types.text },
      { "text", types.text },
      { 'commentCount',types.integer},
      { "createdBy",types.text},
      { "createdAt",types.integer }
    })
    schema.create_table("postparents", {
      { "postID", types.text },
      { "parentID",types.text},
      { "up", types.integer},
      { "down", types.integer },
      { "createdBy",types.text},
      { "createdAt",types.integer}
    })
    schema.create_table("tag", {
      { "id", types.text },
      { "name", types.text },
      { "createdAt", types.text},
      { "createdBy",types.text}
    })
    schema.create_table("posttags", {
      { "postID", types.text },
      { "tagID", types.text },
      { "up", types.integer },
      { "down", types.integer },
      { "score",types.integer},
      { "active", types.boolean},
      { "createdAt", types.integer },
      { 'createdBy', types.text}
    })
    schema.create_table("comment", {
      { "id", types.text },
      { "postID",types.text},
      { "parentID",types.text},
      { "createdBy", types.text },
      { "text", types.text },
      { "createdAt", types.integer },
      { "up", types.integer},
      { "down",types.integer}
    })
    schema.create_table("filter", {
      { "id",types.text},
      { "title",types.text},
      { "description",types.text},
      { "label",types.text},
      { "createdBy",types.text},
      { "createdAt", types.text},
      { "ownerID", types.text}
    })
    schema.create_table("filtertags", {
      { "filterID",types.text},
      { "tagID",types.text},
      { "filterType",types.text},
      { "createdBy",types.text},
      { "createdAt", types.text},
    })
    schema.create_table("filtermods", {
      { "id",types.text},
      { "filterID",types.text},
      { "userID",types.text}
    })
    schema.create_table("filterposts", {
      { "filterID",types.text},
      { "postID",types.text}
    })
    schema.create_table("userseenposts", {
      { "userID",types.text},
      { "nodeID",types.text},
      { "seenAt",types.integer},
      { "seenType",types.text} -- displayed/clicked/voted
    })
end
}
