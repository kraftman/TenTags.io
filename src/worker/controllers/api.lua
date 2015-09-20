


local m = {}
m.__index = m
local util = require('lapis.util')
local mysql = require 'resty.mysql'
local redisWrite = require 'rediswrite'
local mysqlwrite = require 'mysqldal'
local to_json = (require 'lapis.util').to_json
local from_json = (require 'lapis.util').from_json



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

  mysqlwrite:CreateTag(tagInfo)
  redisWrite:CreateTag(tagInfo)

  -- add to mysql
  -- add to redis master 'tags'

end

local function CreatePost(self)
  ngx.req.read_body()
  local body = ngx.req.get_body_data()
  local postInfo = from_json(body).postInfo
  if (not body) or (not postInfo) then
    return {json = {},status = 400}
  end

  -- add the post to mysql
  -- add the post to redis 'posts'
  -- work out which filters want this post
  -- add the post to the relevant filters




end

function m:Register(app)

  app:post('createfilter','/api/filter',CreateFilter)
  app:post('createtag', '/worker/tag',CreateTag)
  app:post('createpost','/worker/post',CreatePost)

end

return m
