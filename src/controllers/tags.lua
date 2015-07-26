local db = require("lapis.db")

local uuid = require 'uuid'

local m = {}
m.__index = m

function m:DisplayTag(tag)
  local query = "SELECT p.title from post p inner join itemtags pt on p.id = pt.itemID where pt.tagID = '"..tag.id.."'"
  print(query)
  local res = db.query(query)
  print('found results: ',#res)
  self.request.posts = res
  return {render = 'tag'}
end

function m:ParseTags()

  local tagName = self.request.params.splat:match('(%w+)')
  tagName = tagName:lower()
  local res = db.select('id,name,title,description from tag where name = ?',tagName)

  if #res == 0 then
    return {render = 'createtag'}
  else
    res = res[1]
    return self:DisplayTag(res)
    ---return res.name..' '..res.title..' '..res.description
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
    local tag = setmetatable({}, m)
    tag.request = request
    return tag:ParseTags()

  end)

  app:get('newtag','/createtag',function()
    return {render = 'createtag'}
  end)

  app:post('/createtagpost',CreateTag)
end


return m
