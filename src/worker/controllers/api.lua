


local m = {}
m.__index = m
local util = require('lapis.util')
local mysql = require 'resty.mysql'
local redis = require 'resty.redis'


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

local function CreateTag()
  local tagInfo = self.params.tag
  -- add to mysql
  -- add to redis master 'tags'

end

function m:Register(app)

  app:post('createfilter','/api/filter',CreateFilter)
  app:post('createtag', '/worker/tag',CreateTag)

end
