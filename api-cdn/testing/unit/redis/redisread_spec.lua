
package.path = package.path.. "./controllers/?.lua;;./lib/?.lua;;";

local redisread = require 'redis.redisread'


describe('tests redisread', function()
  it('converts a list to a table', function()
    local tableIn = {1, 'value 1', 2, 'value 2'}
    local tableOut = redisread:ConvertListToTable(tableIn);
    assert.are.equal(tableOut[1], 'value 1')
  end)

end)