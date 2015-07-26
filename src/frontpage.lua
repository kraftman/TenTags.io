

local uuid = require 'uuid'
local db = require("lapis.db")
local util = require("lapis.util")


local m = {}

local function FrontPage(self)
  local query = [[SELECT p.id,p.title,p.link,pt.itemID,t.name
    from post p
    inner join itemtags pt
    on p.id = pt.itemID
    inner join tag t
    on pt.tagID = t.id]]
  local res = db.query(query)

  for k,v in pairs(res) do
    print(v.link)
    if not v.link then
      v.link = self:url_for('viewpost',{postID = v.id})
    end

  end

  self.posts = res
  return {render = 'frontpage'}
end

function m:Register(app)


  app:get('home','/',FrontPage)

end

return m
