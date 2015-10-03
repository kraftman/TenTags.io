

local m = {}
m.__index = m

local respond_to = (require 'lapis.application').respond_to

local util = require("lapis.util")
local db = require("lapis.db")
local from_json = util.from_json

local function DisplaySettings(self)
  if not self.session.username then
    return "Y'aint logged in luv!"
  end

  --all tags
  local res = db.select('* from tag ')
  self.tags = res

  --selected tags
  local query = [[select t.name as name from user as u
                  inner join itemtags as it
                  on u.id = it.itemID
                  inner join tag as t
                  on it.tagID = t.id
                  where username = 'kraftman']]
  res = db.query(query)
  local usertags = {}
  for k,v in pairs(res) do
    usertags[v] = v
  end
  self.usertags = usertags

  res = db.select('* from user where username = ?',self.session.username)
  if not res then
    return 'user not found'
  end
  res = res[1]
  self.userinfo = res

  return {render = 'settings'}

end

local function UpdateSettings(self)
  local res = db.select('id from user where username = "kraftman"')

  local res = db.query([[delete it from itemtags as it
inner join user as u
on it.itemID = u.id
where u.username = 'kraftman']])

  local res = db.select("id from user where username ='kraftman'")
  res = res[1]

  local selected = from_json(self.params.selectedtags)
  print(self.params.selectedtags)
  print('meep')
  for _,tag in pairs(selected) do

    local itemTagInfo = {
      itemID = res.id,
      tagID = tag
    }
    res = db.insert('itemtags',itemTagInfo)
  end
  return 'success!'

end


function m:Register(app)
  app:get('settings','/settings',DisplaySettings)
  app:match('settings','/settings', respond_to({
    GET = DisplaySettings,
    POST = UpdateSettings
  }))
end


return m
