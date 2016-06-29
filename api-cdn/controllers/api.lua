

local m = {}


local respond_to = (require 'lapis.application').respond_to
local api = require 'api.api'
local tinsert = table.insert

local function UserLogin(self)


end

function m:Register(app)
  --app:match('apilogin','/api/login',respond_to({POST = UserLogin}))
end

return m
