

local m = {}
m.__index = m

local respond_to = (require 'lapis.application').respond_to
local api = require 'api.api'
local trim = require ('lapis.util').trim

local function DisplaySettings(self)
  local user = api:GetUserInfo(self.session.userID)

  self.enablePM = user.enablePM == 1 and 'checked' or ''

  ngx.log(ngx.ERR, user.enablePM)
  return {render = 'ViewSettings'}
end


local function UpdateSettings(self)

  local user = api:GetUserInfo(self.session.userID)
  ngx.log(ngx.ERR, self.params.EnablePM)
  user.enablePM = self.params.EnablePM and 1 or 0
  self.enablePM = self.params.EnablePM and 'checked' or ''
  ngx.log(ngx.ERR, user.enablePM)
  api:UpdateUser(user)

  return {render = 'ViewSettings'}

end


function m:Register(app)
  app:match('viewsettings','/settings', respond_to({
    GET = DisplaySettings,
    POST = UpdateSettings
  }))
end


return m
