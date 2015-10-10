
local m = {}


local respond_to = (require 'lapis.application').respond_to
local api = require 'api.api'

local function FlushPosts()
  api:FlushAllPosts()
  return 'done'

end

function m:Register(app)

  app:match('flushposts','/admin/posts/flush',respond_to({GET = FlushPosts}))
end

return m
