

local uuid = require 'lib.uuid'
local tagAPI = require 'api.tags'
local app = require 'app'

local m = {}
m.__index = m



app:get('parsetags','/tag/*',function(request)

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
end)

app:get('newtag','/createtag',function()    return {render = 'createtag'}  end)

app:post('/createtagpost',function(request)
  if not request.session.userID then
    return {render = 'pleaselogin'}
  end

  local info ={
    id = uuid.generate_random(),
    name = request.params.tagname,
    createdAt = ngx.time(),
    createdBy = request.session.userID
  }

  local ok, err = tagAPI:CreateTag(request.session.userID, info.name)
  if ok then
    return 'tag created!'
  else
    return 'error! '..(err or 'no error')
  end
end)
