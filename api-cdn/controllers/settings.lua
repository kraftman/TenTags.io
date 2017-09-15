


local m = {}
m.__index = m

local userAPI = require 'api.users'
local sessionAPI = require 'api.sessions'

local respond_to = (require 'lapis.application').respond_to
local to_json = (require 'lapis.util').to_json


local app_helpers = require("lapis.application")
local capture_errors, assert_error = app_helpers.capture_errors, app_helpers.assert_error



function m:Register(app)
  app:match('usersettings','/settings', respond_to({
    GET = self.DisplaySettings,
    POST = self.UpdateSettings
  }))

  app:match('/settings/filterstyle',respond_to({
    POST = self.UpdateFilterStyle
  }))

  app:get('killsession', '/sessions/:sessionID/kill', self.KillSession)
end

function m.DisplaySettings(request)

  if not request.session.accountID then
    return {render = 'pleaselogin'}
  end

  local user = request.userInfo
  if not user then
    return 'unknown user'
  end
  for k,v in pairs(user) do
    --ngx.log(ngx.ERR, k,to_json(v))
  end

  request.account = sessionAPI:GetAccount(request.session.accountID, request.session.accountID)
  if request.account then
    for k,v in pairs(request.account.sessions) do
      if (not v.activated) or v.killed then
        request.account.sessions[k] = nil
      end
    end
  end

  request.fakeNames = user.fakeNames and 'checked' or ''
  request.enablePM = user.enablePM and 'checked' or ''
  request.hideSeenPosts = user.hideSeenPosts and 'checked' or ''
  request.hideUnsubbedComments = user.hideUnsubbedComments and 'checked' or ''
  request.hideVotedPosts = user.hideVotedPosts and 'checked' or ''
  request.hideClickedPosts = user.hideClickedPosts and 'checked' or ''
  request.showNSFL = user.showNSFL and 'checked' or ''
  request.userBio = user.bio
  request.nsfwLevel = tonumber(user.nsfwLevel)


  return {render = 'user.subsettings'}
end


function m.UpdateSettings(request)

  if not request.session.accountID then
    return {render = 'pleaselogin'}
  end

  local user = request.userInfo
  if not user or not user.id then
    print('no user')
  end

  if request.params.resetdefaultview then
    if user.role == 'Admin' then
      local ok, err = userAPI:CreateDefaultView(request.session.userID)
      if not ok then
        return err
      end
    end
    return {redirect_to = request:url_for('usersettings')}
  end

  user.enablePM = request.params.enablePM and true or false
  user.fakeNames = request.params.fakeNames and true or false

  user.hideSeenPosts = request.params.hideSeenPosts and true or false
  user.hideUnsubbedComments = request.params.hideUnsubbedComments and true or false
  user.hideVotedPosts = request.params.hideVotedPosts and true or false
  user.hideClickedPosts = request.params.hideClickedPosts and true or false
  user.nsfwLevel = request.params.nsfwLevel
  user.showNSFL = request.params.showNSFL and true or false
  user.bio = request.params.userbio or ''

  local ok, err = userAPI:UpdateUser(user.id, user)
  if not ok then
    print('err')
    return 'eek'
  end

  if request.params.stage=='1' then
    return {redirect_to = request:url_for('home')}
  else
    return {redirect_to = request:url_for('usersettings')}
  end

end

function m.UpdateFilterStyle(request)

  local filterName = request.params.filterName
  local filterStyle = request.params.styleselect

  if not filterName or not filterStyle then
    return 'error, missing arguments'
  end

  local user = request.userInfo
  if not user then
    return 'you must be logged in to do that'
  end
  for k,v in pairs(user) do
    if type(v) == 'string' then
      print(k,v)
    end
  end

  user['filterStyle:'..filterName] = filterStyle

  userAPI:UpdateUser(request.session.userID, user)

  if filterName == 'frontPage' then
    --return { redirect_to = request:url_for("home") }
  else
    --return { redirect_to = request:url_for("filter",{filterlabel = filterName}) }
  end
  return { redirect_to = ngx.var.http_referer }

end

function m.KillSession(request)

  if not request.session.accountID then
    return {render = 'pleaselogin'}
  end

  local ok, err = sessionAPI:KillSession(request.session.accountID, request.params.sessionID)
  if ok then
    return {redirect_to = request:url_for('usersettings')}
  else
    print(err)
    return 'not killed!'
  end
end



return m
