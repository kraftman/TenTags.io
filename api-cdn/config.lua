local config = require("lapis.config")

config("development", {
  mysql = {
    host = "127.0.0.1",
    user = "root",
    password = "meep",
    database = "taggr",
  },
  hide_errors = true,
  session_name = 'filtta_session',
  secret = "this is my secrarstrstet string 123456",
  num_workers = '1',
  port = 8080
})

config("production", {
  code_cache = "on",
  secret = os.getenv('LAPIS_SECRET'),
  port = 8080,
  hide_errors = true,
  num_workers = 'auto',
  logging = {
    queries = false,
    requests = false
  }
})
