local config = require("lapis.config")

config("development", {
  mysql = {
    host = "127.0.0.1",
    user = "root",
    password = "meep",
    database = "taggr",
  },
  secret = "this is my secrarstrstet string 123456",
  num_workers = 'auto',
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
  code_cache = "on",
  secret = "this is my secrarstrstet string 123456",
  port = 80,
  num_workers = 'auto'
})
