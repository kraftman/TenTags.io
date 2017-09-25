local config = require("lapis.config")

config("development", {
  hide_errors = false,
  session_name = 'filtta_session',
  secret = "this is my secrarstrstet string 123456",
  num_workers = '1',
  port = 80,
  dict_filters = '1m',
  dict_posts = '1m',
  dict_locks = '1m',
  dict_userupdates = '1m',
  dict_usersessionseen = '1m',
  dict_searchresults = '1m',
  dict_users = '1m',
  dict_comments = '1m',
  dict_uservotes = '1m',
  dict_ratelimit = '1m',
  dict_emailqueue = '1m',
  dict_pagestatlog = '1m',
  dict_userfilterids = '1m',
  dict_useralerts = '1m',
  dict_sessionlastseen = '1m',
  dict_userfrontpageposts = '1m',
  dict_images = '100m',
  dict_updatequeue = '10m'

})

config("production", {
  code_cache = "on",
  secret = os.getenv('LAPIS_SECRET'),
  port = 80,

  dict_filters = '100m',
  dict_posts = '100m',
  dict_locks = '10m',
  dict_userupdates = '10m',
  dict_usersessionseen = '10m',
  dict_searchresults = '10m',
  dict_users = '100m',
  dict_comments = '100m',
  dict_uservotes = '10m',
  dict_ratelimit = '10m',
  dict_emailqueue = '10m',
  dict_pagestatlog = '10m',
  dict_userfilterids = '10m',
  dict_useralerts = '1m',
  dict_sessionlastseen = '1m',
  dict_userfrontpageposts = '1m',
  dict_images = '2000m',
  dict_updatequeue = '100m',
  hide_errors = true,
  num_workers = 'auto',
  logging = {
    queries = false,
    requests = false
  }
})
