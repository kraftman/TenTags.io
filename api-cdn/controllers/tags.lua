

local uuid = require 'lib.uuid'
local tagAPI = require 'api.tags'

local m = {}
m.__index = m

function m.ParseTags(request)

  local tagName = request.params.splat:match('(%w+)')
  tagName = tagName:lower()
  local res = db.select('id,name,title,description from tag where name = ?',tagName)

  if #res == 0 then
    return {render = 'createtag'}
  else
    res = res[1]
    return DisplayTag(request, res)
    ---return res.name..' '..res.title..' '..res.description
  end
end

function m.CreateTag(request)

  local info ={
    id = uuid.generate_random(),
    name = request.params.tagname,
    createdAt = ngx.time(),
    createdBy = request.session.userID
  }

  local ok, err = tagAPI:CreateTag(request.session.userID, info)
  if ok then
    return 'tag created!'
  else
    return 'error! '..(err or 'no error')
  end
end

function m:Register(app)
  app:get('/tag/*',self.ParseTags)

  app:get('newtag','/createtag',function()    return {render = 'createtag'}  end)

  app:post('/createtagpost',self.CreateTag)
end


return m
