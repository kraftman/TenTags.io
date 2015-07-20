

local uuid = require 'uuid'
local db = require("lapis.db")
local util = require("lapis.util")

local from_json = util.from_json

local m = {}

local respond_to = (require 'lapis.application').respond_to


local function CreatePost(self)

  print(self.params.selectedtags)
  local selected = from_json(self.params.selectedtags)


  local info ={
    id = uuid.generate_random(),
    title = self.params.title,
    link = self.params.link,
    text = self.params.text
  }
  local res = db.insert('post', info)

  for _, tagID in pairs(selected) do
    local postTagInfo = {
      postID = info.id,
      tagID = tagID,
      up = 0,
      down = 0,
      date = ngx.time()
    }
    local res = db.insert('posttags', postTagInfo)
  end

  return {json = self.req.selectedtags}
end

local function GetPost(self)

end

local function CreatePostForm(self)
  local res = db.select('* from tag ')
  print(#res)
  self.tags = res

  return { render = 'createpost' }
end

function m:Register(app)
  app:match('newpost','/post/new', respond_to({
    GET = CreatePostForm,
    POST = CreatePost
  }))

  app:get('/post/*',GetPost)
  app:get('/test',CreatePost)

end

return m
