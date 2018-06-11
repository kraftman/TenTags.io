
package.path = package.path.. "../?.lua;./testing/lib/?.lua;;./controllers/?.lua;;./lib/?.lua;;";

local redisBase = require 'fakeredis'
local redisread = require 'redis.userread'

describe('tests redisread', function()

  it('tests GetNewUsers', function()
    redisBase:createMock('zrange', {1, 'test'})
    local ok = redisread:GetNewUsers('test');
    
    assert.are.same({'test'}, ok);
  end)
  it('tests GetUserAlerts', function()
    redisBase:createMock('zrangebyscore', {1, 'test'})
    local ok = redisread:GetUserAlerts('userID', 0, 10);
    
    assert.are.same({1, 'test'}, ok);
  end)

  it('tests SavedPostExists', function()
    redisBase:createMock('sismember', true)
    local ok = redisread:SavedPostExists('test');
    
    assert.are.equal(true, ok);
  end)

end)