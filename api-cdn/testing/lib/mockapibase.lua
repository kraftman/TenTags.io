

local mockBase = {
}
mockBase.__index = mockBase

function mockBase:QueueUpdate()
  return true
end


package.loaded['api.base'] = mockBase

return mockBase