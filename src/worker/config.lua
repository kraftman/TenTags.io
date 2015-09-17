local config = require("lapis.config")

config("development", {
  port = 8081,
  mysql = {
    host = "127.0.0.1",
    user = "root",
    password = "meep",
    database = "taggr",

  }
})
