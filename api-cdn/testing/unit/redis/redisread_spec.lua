
package.path = package.path.. "./controllers/?.lua;;./lib/?.lua;;";

local base = require 'redis.base'
local redisread = require 'redis.redisread'

local utils = {
  test = function()
    return 'from utils'
  end
}

describe('tests redisread', function()
  -- it('converts a list to a table', function()
  --   local tableIn = {1, 'value 1', 2, 'value 2'}
  --   local tableOut = redisread:ConvertListToTable(tableIn);
  --   assert.are.equal(tableOut[1], 'value 1')
  -- end)

  it('mocks redis', function()
    local read = redisread(utils)
    print(read:test())
    assert.are.equal(read:test(), 'from utils')
  end)

end)