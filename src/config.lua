local config = require("lapis.config")

config("development", {
  port = 8080,
  mysql = {
    host = "127.0.0.1",
    user = "root",
    password = "meep",
    database = "taggr"
  }
})

config("production", {
  port = 80,
  num_workers = 4,
  code_cache = "on"
})
