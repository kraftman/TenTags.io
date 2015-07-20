

local uuid = require 'uuid'
local db = require("lapis.db")
local util = require("lapis.util")


local m = {}

local function FrontPage(self)
  local query = [[SELECT p.title,pt.postID,t.name
    from post p
    inner join posttags pt
    on p.id = pt.postID
    inner join tag t
    on pt.tagID = t.id]]
  local res = db.query(query)
  self.posts = res
  return {render = 'frontpage'}
end

function m:Register(app)


  app:get('/',FrontPage)

end

return m
