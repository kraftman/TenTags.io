

--need some way of ensuring that a default post is always present
--[[
  could use the existing redisread module to create a post
  if it doesnt already exist, then perform tests on that


]]

local url = 'http://localhost:8080'
local http = require 'socket.http'

local function CreatePost()

end

local function CreateUser()

end

describe('basic access for logged out user', function()
  it('can load frontpage', function()
    local b,c,h = http.request(url..'/')
    assert.are.equal(c, 200)
  end)

end)
