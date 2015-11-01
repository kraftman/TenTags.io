local db = require("lapis.db")

local uuid = require 'lib.uuid'
local api = require 'api.api'

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
end

local function CreateTag(self)

  local info ={
    id = uuid.generate_random(),
    name = self.params.tagname,
    createdAt = ngx.time(),
    createdBy = self.session.userID
  }

  local ok, err = api:CreateTag(info)
  if ok then
    return 'tag created!'
  else
    return 'error! '..(err or 'no error')
  end
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
