
local fakeDb = {
}
fakeDb.__index = fakeDb

local fakeRedis = {
  init_pipeline = function()
    return true
  end,
}

function fakeDb:createMock(name, ...)
  --print(type(...))
  local thisArgs = {...}
  if type(...) == 'function' then
    fakeRedis[name] = ...
    return
  end
  fakeRedis[name] = function(self)
    --self.calledWith = {...}
    if type(returnValue) == 'table' then
     -- return unpack(returnValue)
    end
    return unpack(thisArgs)
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

function fakeDb:GetCommentReadConnection()
  return fakeRedis
end

function fakeDb:GetCommentWriteConnection()
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