


local app = require 'app'

local userAPI = require 'api.users'
local sessionAPI = require 'api.sessions'
local csrf = require("lapis.csrf")
local util = require 'util'

local respond_to = (require 'lapis.application').respond_to


local app_helpers = require("lapis.application")
local capture_errors = app_helpers.capture_errors
local assert_error = app_helpers.assert_error
local yield_error = app_helpers.yield_error



app:match('user.subsettings','/settings', respond_to({
  GET = capture_errors({
    on_error = util.HandleError,
    function(request)
      local user = request.userInfo
      request.account = sessionAPI:GetAccount(request.session.accountID, request.session.accountID)
      if request.account then
        for k,v in pairs(request.account.sessions) do
          if (not v.activated) or v.killed then
            request.account.sessions[k] = nil
          end
        end
      end

      request.allowMentions = user.allowMentions and 'checked' or ''
      request.allowSubs = user.allowSubs and 'checked' or ''
      request.fakeNames = user.fakeNames and 'checked' or ''
      request.enablePM = user.enablePM and 'checked' or ''
      request.hideSeenPosts = user.hideSeenPosts and 'checked' or ''
      request.hideUnsubbedComments = user.hideUnsubbedComments and 'checked' or ''
      request.hideVotedPosts = user.hideVotedPosts and 'checked' or ''
      request.hideClickedPosts = user.hideClickedPosts and 'checked' or ''
      request.showNSFL = user.showNSFL and 'checked' or ''
      request.userBio = user.bio
      request.nsfwLevel = tonumber(user.nsfwLevel)


      return {render = true}
    end
  }),

  POST = capture_errors({
    on_error = util.HandleError,
    function(request)

      csrf.assert_token(request)
      if not request.session.accountID then
        return {render = 'pleaselogin'}
      end

      local user = request.userInfo
      if not user or not user.id then
        return {render = 'pleaselogin'}
      end

      if request.params.resetdefaultview then
        if user.role == 'Admin' then
          assert_error(userAPI:CreateDefaultView(request.session.userID))
        end
        return {redirect_to = request:url_for('user.subsettings')}
      end

      user.enablePM = request.params.enablePM and true or false
      user.fakeNames = request.params.fakeNames and true or false
      user.allowMentions = request.params.allowMentions and true or false
      user.allowSubs = request.params.allowSubs and true or false

      user.hideSeenPosts = request.params.hideSeenPosts and true or false
      user.hideUnsubbedComments = request.params.hideUnsubbedComments and true or false
      user.hideVotedPosts = request.params.hideVotedPosts and true or false
      user.hideClickedPosts = request.params.hideClickedPosts and true or false
      user.nsfwLevel = request.params.nsfwLevel
      user.showNSFL = request.params.showNSFL and true or false
      user.bio = request.params.userbio or ''

      assert_error(userAPI:UpdateUser(user.id, user))

      if request.params.stage == '1' then
        return {redirect_to = request:url_for('home')}
      else
        return {redirect_to = request:url_for('user.subsettings')}
      end
    end
  })
}))

app:match('/settings/filterstyle',respond_to({
  POST = capture_errors({
    on_error = util.HandleError,
    function(request)

      local filterName = request.params.filterName
      local filterStyle = request.params.styleselect

      if not filterName or not filterStyle then
        yield_error 'error, missing arguments'
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

      assert_error(userAPI:UpdateUser(request.session.userID, user))

      return { redirect_to = ngx.var.http_referer }
    end
  })
}))

app:get('killsession', '/sessions/:sessionID/kill', capture_errors({
  on_error = util.HandleError,
  function(request)
    assert_error(sessionAPI:KillSession(request.session.accountID, request.params.sessionID))
    return {redirect_to = request:url_for('user.subsettings')}
  end
}))
