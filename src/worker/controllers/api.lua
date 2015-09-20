


local m = {}
m.__index = m
local util = require('lapis.util')
local mysql = require 'resty.mysql'
local redis = require 'resty.redis'
local mysqlwrite = require 'mysqldal'
local to_json = (require 'lapis.util').to_json
local from_json = (require 'lapis.util').from_json


local function GetRedisConnection()
  local red = redis:new()
  red:set_timeout(1000)
  local ok, err = red:connect("127.0.0.1", 6379)
  if not ok then
      ngx.say("failed to connect: ", err)
      return
  end
  return red
end

local function SetKeepalive(red)
  local ok, err = red:set_keepalive(10000, 100)
  if not ok then
      ngx.say("failed to set keepalive: ", err)
      return
  end
end


local function CreateFilter()

end

local function CreateTag(self)
  ngx.req.read_body()
  local body = ngx.req.get_body_data()


  if not body then
    return {json = {},status = 400}
  end
  local tagInfo = from_json(body).tagInfo
  for k,v in pairs(tagInfo) do
    print(k)
  end

  if mysqlwrite:CreateTag(tagInfo) then
    return {json = {}}
  else
    return {json = {},status = 500}
  end
  -- add to mysql
  -- add to redis master 'tags'

end

function m:Register(app)

  app:post('createfilter','/api/filter',CreateFilter)
  app:match('createtag', '/worker/tag',CreateTag)

end

return m
