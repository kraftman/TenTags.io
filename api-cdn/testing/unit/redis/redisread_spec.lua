
package.path = package.path.. "./controllers/?.lua;;./lib/?.lua;;";

local base = require 'redis.base'
local redisread = require 'redis.redisread'

-- local fakeRedis = {}

--   fakeRedis.init_pipeline = function() 
--     return true
--   end
--   fakeRedis.zrevrange = function()
--     return true
--   end
-- end

describe('tests redisread', function()
  it('converts a list to a table', function()
    local tableIn = {1, 'value 1', 2, 'value 2'}
    local tableOut = redisread:ConvertListToTable(tableIn);
    assert.are.equal(tableOut[1], 'value 1')
  end)



end)