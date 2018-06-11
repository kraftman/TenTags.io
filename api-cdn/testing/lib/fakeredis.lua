
local realdb = require 'redis.base'

local fakeDb = {
}
fakeDb.__index = fakeDb

local fakeRedis = {

}

function fakeDb:createMock(name, returnValue)
  fakeRedis[name] = function(self, ...)
    self.calledWith = {...}
    return returnValue
  end
end

function fakeDb:GetRedisReadConnection()
  return fakeRedis
end


function fakeDb:GetUserReadConnection()
  return fakeRedis
end
function fakeDb:GetUserWriteConnection()
  return fakeRedis
end

function fakeDb:SetKeepalive()
  return true
end

function fakeDb:SplitShortURL()
  return 'test'
end

function fakeDb:from_json()
  return 'test'
end

package.loaded['redis.base'] = fakeDb

return fakeDb