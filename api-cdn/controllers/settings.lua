

local m = {}
m.__index = m

local respond_to = (require 'lapis.application').respond_to
local api = require 'api.api'
local to_json = (require 'lapis.util').to_json

local function DisplaySettings(self)
  local user = api:GetUserInfo(self.session.userID)
  for k,v in pairs(user) do
    ngx.log(ngx.ERR, k,to_json(v))
  end

  self.enablePM = user.enablePM == '1' and 'checked' or ''
  self.hideSeenPosts = user.hideSeenPosts == '1' and 'checked' or ''

  ngx.log(ngx.ERR, user.enablePM)
  return {render = 'user.subsettings'}
end


local function UpdateSettings(self)

  local user = api:GetUserInfo(self.session.userID)
  ngx.log(ngx.ERR, self.params.EnablePM)
  user.enablePM = self.params.EnablePM and 1 or 0
  self.enablePM = self.params.EnablePM and 'checked' or ''
  user.hideSeenPosts = self.params.hideSeenPosts and 1 or 0
  self.hideSeenPosts = self.params.hideSeenPosts and 'checked' or ''
  ngx.log(ngx.ERR, user.enablePM)
  api:UpdateUser(self.session.userID, user)

  return {render = 'user.subsettings'}

end


function m:Register(app)
  app:match('usersettings','/settings', respond_to({
    GET = DisplaySettings,
    POST = UpdateSettings
  }))
end


return m
