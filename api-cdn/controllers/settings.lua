

local m = {}
m.__index = m

local respond_to = (require 'lapis.application').respond_to
local api = require 'api.api'
local to_json = (require 'lapis.util').to_json

local function DisplaySettings(self)
  print(self.session.userID, self.session.accountID, self.session.username)
  local user = api:GetUser(self.session.userID)
  if not user then
    return 'unknown user'
  end
  for k,v in pairs(user) do
    --ngx.log(ngx.ERR, k,to_json(v))
  end

  self.account = api:GetAccount(self.session.accountID, self.session.accountID)
  if self.account then
    for k,v in pairs(self.account.sessions) do
      if not v.activated then
        self.account.sessions[k] = nil
      end
    end
  end
  print(to_json(user))


  self.enablePM = user.enablePM == '1' and 'checked' or ''
  self.hideSeenPosts = user.hideSeenPosts == '1' and 'checked' or ''
  self.hideVotedPosts = user.hideVotedPosts == '1' and 'checked' or ''
  self.hideClickedPosts = user.hideClickedPosts == '1' and 'checked' or ''
  self.showNSFW = user.showNSFW == '1' and 'checked' or ''

  ngx.log(ngx.ERR, user.enablePM)
  return {render = 'user.subsettings'}
end


local function UpdateSettings(self)

  local user = api:GetUser(self.session.userID)
  ngx.log(ngx.ERR, self.params.EnablePM)
  user.enablePM = self.params.EnablePM and 1 or 0
  user.hideSeenPosts = self.params.hideSeenPosts and 1 or 0
  user.hideVotedPosts = self.params.hideVotedPosts and 1 or 0
  user.hideClickedPosts = self.params.hideClickedPosts and 1 or 0
  user.showNSFW = self.params.showNSFW and 1 or 0
  print 'this'
  local ok, err = api:UpdateUser(self.session.userID, user)
  if not ok then
    print(err)
    return 'eek'
  end
  return {redirect_to = self:url_for('usersettings')}

end

local function UpdateFilterStyle(self)

  local filterName = self.params.filterName
  local filterStyle = self.params.styleselect

  if not filterName or not filterStyle then
    return 'error, missing arguments'
  end

  local user = api:GetUser(self.session.userID)
  for k,v in pairs(user) do
    if type(v) == 'string' then
      print(k,v)
    end
  end

  user['filterStyle:'..filterName] = filterStyle
  print ('setting filterstyle for filtername '..filterName..' to '..filterStyle)
  api:UpdateUser(self.session.userID, user)

  if filterName == 'frontPage' then
    --return { redirect_to = self:url_for("home") }
  else
    --return { redirect_to = self:url_for("filter",{filterlabel = filterName}) }
  end
  return { redirect_to = ngx.var.http_referer }

end

local function KillSession(self)

  local ok, err = api:KillSession(self.session.accountID, self.params.sessionID)
  if ok then
    return 'killed!'
  else
    print(err)
    return 'not killed!'
  end
end


function m:Register(app)
  app:match('usersettings','/settings', respond_to({
    GET = DisplaySettings,
    POST = UpdateSettings
  }))

  app:match('/settings/filterstyle',respond_to({
    POST = UpdateFilterStyle
  }))

  app:get('killsession', '/sessions/:sessionID/kill', KillSession)
end


return m
