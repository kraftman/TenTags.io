package.path = package.path.. "../?.lua;./testing/lib/?.lua;;./controllers/?.lua;;./lib/?.lua;;";

local mockuna = require 'mockuna'

local redisRead = require 'redis.redisread'

local admin = require 'api.admin'
local cache = require 'api.cache'

describe('tests GetBacklogStats', function()
  before_each(function()
    mockuna:stub(redisRead, 'GetBacklogStats', function() return true end)
  end)

  after_each(function()
    redisRead.GetBacklogStats:restore()
  end)

  it('tests get backlog stats', function()
    local ok = admin:GetBacklogStats('jobName', 0, 10)
    assert.are.same(true, ok)
  end)
end)

describe('tests GetSiteUniqueStats', function()
  before_each(function()
    mockuna:stub(redisRead, 'GetSiteUniqueStats', function() return true end)
  end)

  after_each(function()
    redisRead.GetSiteUniqueStats:restore()
  end)

  it('tests GetSiteUniqueStats', function()
    local ok = admin:GetSiteUniqueStats()
    assert.are.same(true, ok)
  end)

end)

describe('tests GetSiteStats', function()
  before_each(function()
    mockuna:stub(redisRead, 'GetSiteStats', function() return true end)
  end)

  after_each(function()
    redisRead.GetSiteStats:restore()
  end)

  it('tests GetSiteStats', function()
    local ok = admin:GetSiteStats()
    assert.are.same(true, ok)
  end)
end)

describe('tests GetNewUsers', function()
  before_each(function()
    mockuna:stub(cache, 'GetUser', function() return {role = 'Admin'} end)
    mockuna:stub(cache, 'GetNewUsers', function() return true end)
  end)

  after_each(function()
    cache.GetNewUsers:restore()
    cache.GetUser:restore()
  end)

  it('tests GetNewUsers', function()
    local ok = admin:GetNewUsers()
    assert.are.same(true, ok)
  end)
end)


describe('tests GetReports', function()
  before_each(function()
    mockuna:stub(cache, 'GetUser', function() return {role = 'Admin'} end)
    mockuna:stub(cache, 'GetReports', function() return true end)
  end)

  after_each(function()
    cache.GetUser:restore()
    cache.GetReports:restore()
  end)

  it('tests GetReports', function()
    local ok = admin:GetReports()
    assert.are.same(true, ok)
  end)
end)

