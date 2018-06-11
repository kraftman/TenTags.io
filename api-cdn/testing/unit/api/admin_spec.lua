package.path = package.path.. "../?.lua;./testing/lib/?.lua;;./controllers/?.lua;;./lib/?.lua;;";


local mocker = require 'mocker'

local mockRedis = mocker:CreateMock('redis.redisread')
local mockCache = mocker:CreateMock('api.cache')
local mockLapis = mocker:CreateMock('lapis.application')

mockLapis:Mock('assert_error', function(self, ...)
  return ...
end)

local admin = require 'api.admin'

describe('tests admin api', function()
  -- it('tests get backlog stats', function()
  --   mockRedis:Mock('GetBacklogStats', true)
  --   local ok = admin:GetBacklogStats('jobName', 0, 10)
  --   assert.are.same({}, ok)
  -- end)
end)