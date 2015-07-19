local db = require("lapis.db")

local uuid = require 'uuid'

local m = {}
m.__index = m
function m:ParseTags()

  local tagName = self.request.params.splat:match('(%w+)')
  tagName = tagName:lower()
  local res = db.select('name,title,description from tag where name = ?',tagName)

  if #res == 0 then
    return ' tag doesnt exist, click here to create it: '..self.request:build_url()..self.request:url_for('createtag')
  else
    res = res[1]
    return res.name..' '..res.title..' '..res.description
  end

  return tagName
end

local function CreateTag(self)

  local info ={
    id = uuid.generate_random(),
    title = self.params.tagtitle,
    name = self.params.tagname,
    description = self.params.tagdesc
  }
  local res = db.insert('tag', info)
  return 'tag created!'
end

function m:Register(app)
  app:get('/tag/*',
  function(request)
    print('test')
    local tag = setmetatable({}, m)
    tag.request = request
    return tag:ParseTags()

  end)

  app:get('/createtag','/createtag',function()
    return {render = 'createtag'}
  end)

  app:post('/createtagpost',CreateTag)
end


return m
