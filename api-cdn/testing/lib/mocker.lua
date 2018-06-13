

local mocker = {}

function mocker:CreateMock(moduleName)
  --local original = require(moduleName)

  local fake = {

  }
  function fake:Mock(functionName, returnValues)
    if type(returnValues) == 'function' then
      self[functionName] = returnValues
    else
      self[functionName] = function(...)
        return returnValues
      end
    end
  end

  --fake.original = original
  package.loaded[moduleName] = fake

  return fake
end

return mocker
