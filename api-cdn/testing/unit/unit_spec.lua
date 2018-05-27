
package.path = package.path.. "./controllers/?.lua;;./lib/?.lua;;";

--local fakenginx = require 'lib.fakengx'

local cache = require 'api.cache'
local redisread = require 'redis.redisread'

describe('tests the cache', function()
  it('loads the cache correctly', function()
    
  end)
end)

describe('thist', function()
  it('checks true', function()
    assert.are.equal(1, 1)
  end)
end)