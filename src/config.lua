local config = require("lapis.config")

config("development", {
  mysql = {
    host = "127.0.0.1",
    user = "root",
    password = "meep",
    database = "taggr"
  }
})

config("production", {
  mysql = {
    host = "127.0.0.1",
    user = "root",
    password = "meep",
    database = "taggr"
  },
  logging = {
    queries = false,
    requests = false
  },
  code_cache = "on"
})
