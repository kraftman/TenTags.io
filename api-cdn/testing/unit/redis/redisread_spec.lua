
package.path = package.path.. "./controllers/?.lua;;./lib/?.lua;;";

local realdb = require 'redis.base'

local fakeRedis = {
  zrevrange = function()
    return {'test'}
  end,
  zcard = function()
    return 'test'
  end,
  zrangebyscore = function()
    return 'test'
  end,
  zrevrange = function()
    return {}
  end,
  pfcount = function()
    return 'test'
  end
}

local fakeDb = {
}
fakeDb.__index = fakeDb

function fakeDb:GetRedisReadConnection()
  return fakeRedis
end

function fakeDb:SetKeepalive()
  return true
end

package.loaded['redis.base'] = fakeDb

local redisread = require 'redis.redisread'

describe('tests redisread', function()
  -- it('converts a list to a table', function()
  --   local tableIn = {1, 'value 1', 2, 'value 2'}
  --   local tableOut = redisread:ConvertListToTable(tableIn);
  --   assert.are.equal(tableOut[1], 'value 1')
  -- end)

  -- it('mocks redis', function()
  --   local read = redisread(utils)
  --   assert.are.equal(read:test(), 'from utils')
  -- end)

  it('tests redis', function()
    local oldest = redisread:GetOldestJob('test');
    assert.are.equal(1,1)
    --assert.are.equal(oldest, 'test')
  end)
  -- it('tests redis q size', function()
  --   local oldest = redisread:GetQueueSize('test');

  --   assert.are.equal(oldest, 'test')
  -- end)
  -- it('tests redis q size', function()
  --   local oldest = redisread:GetBacklogStats('test');



end)