--[[
  forward write requests to the workers

]]

local m = {}

local http = require 'http'
local upstream = require "ngx.upstream"
local get_servers = upstream.get_servers
local to_json = (require 'lapis.util').to_json
local from_json = (require 'lapis.util').from_json
local http = require("lapis.nginx.http")

local function request(url,body)
  local worker = get_servers('worker')
  local address = 'http://'..worker[1].addr
  print(address..url,body)
  local body,code,headers = http.simple(address..url,body)


  return body,code,headers
end

function m:CreateTag(tagInfo)
  local body = to_json({tagInfo = tagInfo})
  print(body)
  local body,code,headers = request('/worker/tag',body)

  if code == 200 then
    return true
  else
    ngx.log(ngx.ERR, 'body: ',body)
    return false, 'status: '..code..' err: '..(err or 'none')
  end
end

return m
