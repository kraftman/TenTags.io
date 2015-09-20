--[[
  forward write requests to the workers

]]

local m = {}

local http = require 'http'
local upstream = require "ngx.upstream"
local get_servers = upstream.get_servers
local to_json = (require 'lapis.util').to_json
local from_json = (require 'lapis.util').from_json

local function request(url,options)
  local worker = get_servers('worker')
  local address = 'http://'..worker[1].addr
  local httpc = http.new()

  local res,err = httpc:request_uri(address..url,options)


  return res,err
end

function m:CreateTag(tagInfo)
  local body = to_json({tagInfo = tagInfo})
  local res,err = request('/worker/tag',{method = 'POST',body = body})

  if res.status == 200 then
    return true
  else
    ngx.log(ngx.ERR, 'body: ',res.body)
    return false, 'status: '..res.status..' err: '..(err or 'none')
  end
end

function m:CreatePost(postInfo)
  local body = to_json({postInfo = postInfo})
  local res, err = request('/worker/post',{method = 'POST',body = body})

  if res.status == 200 then
    return true
  else
    return false, 'status: '..res.status..' err: '..(err or 'none')
  end
end


return m
