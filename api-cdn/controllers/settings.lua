

local m = {}
m.__index = m

local userAPI = require 'api.users'
local sessionAPI = require 'api.sessions'

local respond_to = (require 'lapis.application').respond_to
local to_json = (require 'lapis.util').to_json

function m.DisplaySettings(request)

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
      if not v.activated then
        request.account.sessions[k] = nil
      end
    end
  end

  print(user.fakeNames)


  request.fakeNames = user.fakeNames == '1' and 'checked' or ''
  request.enablePM = user.enablePM == '1' and 'checked' or ''
  request.hideSeenPosts = user.hideSeenPosts == '1' and 'checked' or ''
  request.hideVotedPosts = user.hideVotedPosts == '1' and 'checked' or ''
  request.hideClickedPosts = user.hideClickedPosts == '1' and 'checked' or ''
  request.showNSFW = user.showNSFW == '1' and 'checked' or ''
  request.userBio = user.bio

  ngx.log(ngx.ERR, user.enablePM)
  return {render = 'user.subsettings'}
end


function m.UpdateSettings(request)

  local user = request.userInfo
  if not user or not user.id then
    print('no user')
  end

  user.enablePM = request.params.EnablePM and 1 or 0
  user.fakeNames = request.params.fakeNames and 1 or 0
  user.hideSeenPosts = request.params.hideSeenPosts and 1 or 0
  user.hideVotedPosts = request.params.hideVotedPosts and 1 or 0
  user.hideClickedPosts = request.params.hideClickedPosts and 1 or 0
  user.showNSFW = request.params.showNSFW and 1 or 0
  user.bio = request.params.userbio or ''

  local ok, err = userAPI:UpdateUser(user.id, user)
  if not ok then

    return 'eek'
  end
  return {redirect_to = request:url_for('usersettings')}

end

function m.UpdateFilterStyle(request)

  local filterName = request.params.filterName
  local filterStyle = request.params.styleselect

  if not filterName or not filterStyle then
    return 'error, missing arguments'
  end

  local user = request.userInfo
  for k,v in pairs(user) do
    if type(v) == 'string' then
      print(k,v)
    end
  end

  user['filterStyle:'..filterName] = filterStyle
  print ('setting filterstyle for filtername '..filterName..' to '..filterStyle)
  userAPI:UpdateUser(request.session.userID, user)

  if filterName == 'frontPage' then
    --return { redirect_to = request:url_for("home") }
  else
    --return { redirect_to = request:url_for("filter",{filterlabel = filterName}) }
  end
  return { redirect_to = ngx.var.http_referer }

end

function m.KillSession(request)

  local ok, err = sessionAPI:KillSession(request.session.accountID, request.params.sessionID)
  if ok then
    return 'killed!'
  else
    print(err)
    return 'not killed!'
  end
end


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


return m
