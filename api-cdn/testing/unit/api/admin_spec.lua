package.path = package.path.. "../?.lua;./testing/lib/?.lua;;./controllers/?.lua;;./lib/?.lua;;";


local mocker = require 'mocker'
local mockuna = require 'mockuna'

local redisRead = require 'redis.redisread'
local mockRedis = mocker:CreateMock('redis.redisread')
local mockCache = mocker:CreateMock('api.cache')
local mockLapis = mocker:CreateMock('lapis.application')

mockLapis:Mock('assert_error', function(self, ...)
  return self
end)

local admin = require 'api.admin'

describe('tests admin api', function()
  it('tests get backlog stats', function()
    --mockRedis:Mock('GetBacklogStats', true)
    mockuna:stub(redisRead, 'GetBacklogStats', function() return true end)
    local ok = admin:GetBacklogStats('jobName', 0, 10)
    assert.are.same(true, ok)
    redisRead.GetBacklogStats:restore()
  end)
  
  it('tests GetSiteUniqueStats', function()
    mockRedis:Mock('GetSiteUniqueStats', true)
    local ok = admin:GetSiteUniqueStats()
    assert.are.same(true, ok)
  end)

  it('tests GetSiteStats', function()
    mockRedis:Mock('GetSiteStats', true)
    local ok = admin:GetSiteStats()
    assert.are.same(true, ok)
  end)

  it('tests GetNewUsers', function()
    mockCache:Mock('GetUser', {role = 'Admin'})
    mockCache:Mock('GetNewUsers', true)
    local ok = admin:GetNewUsers()
    assert.are.same(true, ok)
  end)

  it('tests GetReports', function()
    mockCache:Mock('GetUser', {role = 'Admin'})
    mockCache:Mock('GetReports', true)
    local ok = admin:GetReports()
    assert.are.same(true, ok)
  end)
  
end)
