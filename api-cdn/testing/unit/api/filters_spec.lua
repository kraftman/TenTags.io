package.path = package.path.. "../?.lua;./testing/lib/?.lua;;./controllers/?.lua;;./lib/?.lua;;";


local mocker = require 'mocker'
local mockBase  = mocker:CreateMock('api.base')
local mockRedis = mocker:CreateMock('redis.redisread')
local mockCache = mocker:CreateMock('api.cache')
local mockLapis = mocker:CreateMock('lapis.application')
local mockUUID = mocker:CreateMock('lib.uuid')
local mockTagAPI = mocker:CreateMock('api.tags')

mockLapis:Mock('assert_error', function(self, ...)
  return self
end)

local filter = require 'api.filters'

mockBase:Mock('QueueUpdate', true);
mockBase:Mock('InvalidateKey', true);
function mockBase:SanitiseUserInput(input)
  return input
end
mockBase.redisWrite = {
  UpdateFilterTitle = function()
    return true
  end,
  UpdateFilterDescription = function()
    return true
  end,
  FilterBanUser = function()
    return true
  end
}
mockBase.userWrite = {
  AddUserAlert = function()
    return true
  end
}

describe('tests comment api', function() 
  it('tests GetFilters', function()
    mockCache:Mock('GetFilterByID', {'filter1'})
    local ok = filter:GetFilters({'fitlerID'})
    assert.are.same({'filter1'}, ok[1])
  end)

  it('tests GetFilterInfo', function()
    mockCache:Mock('GetFilterInfo', {'filter1'})
    local ok = filter:GetFilterInfo({'fitlerID'})
    assert.are.same('filter1', ok[1])
  end)

  it('tests UpdateFilterTitle', function()
    mockCache:Mock('GetFilterByID', {ownerID = 'userID'})
    local ok = filter:UpdateFilterTitle('userID', 'filterID', 'newTitle')
    assert.are.same('newTitle', ok.title)
  end)

  it('tests UpdateFilterDescription', function()
    mockCache:Mock('GetFilterByID', {ownerID = 'userID'})
    local ok = filter:UpdateFilterDescription('userID', 'filterID', 'newDesc')
    assert.are.same('newDesc', ok.description)
  end)

  it('tests SearchFilters', function()
    mockCache:Mock('SearchFilters', 'filterID')
    local ok = filter:SearchFilters(_, 'searchstring')
    assert.are.same('filterID', ok)
  end)

  it('tests UserCanEditFilter', function()
    local mockFilter = { ownerID = 'userID', mods = {}}
    mockCache:Mock('GetUser', {role = 'Admin'})
    mockCache:Mock('GetFilterByID', mockFilter)
    local ok = filter:UserCanEditFilter(_, 'searchstring')
    assert.are.same(mockFilter, ok)
  end)

  it('tests FilterBanUser', function()
    local mockFilter = { ownerID = 'userID', mods = {}}
    mockCache:Mock('GetUser', {role = 'Admin'})
    mockCache:Mock('GetFilterByID', mockFilter)
    local ok = filter:FilterBanUser('userID', 'filterID', {})
    assert.are.same(mockFilter, ok)
  end)
end)