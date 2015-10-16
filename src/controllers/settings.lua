

local m = {}
m.__index = m

local respond_to = (require 'lapis.application').respond_to
local api = require 'api.api'
local trim = require ('lapis.util').trim

local function DisplaySettings(self)
  return {render = 'ViewSettings'}
end


local function UpdateSettings(self)
  


end


function m:Register(app)
  app:match('viewsettings','/settings', respond_to({
    GET = DisplaySettings,
    POST = UpdateSettings
  }))
end


return m
