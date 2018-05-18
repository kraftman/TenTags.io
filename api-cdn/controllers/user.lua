



local respond_to = (require 'lapis.application').respond_to
local userAPI = require 'api.users'
local postAPI = require 'api.posts'
local commentAPI = require 'api.comments'
local sessionAPI = require 'api.sessions'
local trim = (require 'lapis.util').trim
local to_json = (require 'lapis.util').to_json
local http = require 'lib.http'
local encode_query_string = (require 'lapis.util').encode_query_string
local woothee = require "resty.woothee"
local from_json = (require 'lapis.util').from_json
local util = require 'util'

local app_helpers = require("lapis.application")
local capture_errors, assert_error = app_helpers.capture_errors, app_helpers.assert_error
local yield_error = app_helpers.yield_error

local function GetSession(request)
  local details = woothee.parse(ngx.var.http_user_agent)
  local session = {
    ip = ngx.var.remote_addr,
    email = request.params.email,
    category = details.category,
    os = details.os,
    browser = details.name..' '..details.version,
    city = ngx.var.geoip_city
  }

  return session
end


local app = require 'app'

app:match('newsubuser','/sub/new', respond_to({
  GET = function() return {render = 'user.createsub'} end,
  POST = capture_errors({
    on_error = util.HandleError,
    function(request)
      if not request.params.username or trim(request.params.username) == '' then
        return 'no username!'
      end

      local succ = assert_error(userAPI:CreateSubUser(request.session.accountID,request.params.username))

      request.session.username = succ.username
      request.session.userID = succ.id
      return { redirect_to = request:url_for("user.subsettings")..'?stage=1' }

    end
  })
}))

app:match('user.login','/login',respond_to({
  POST = capture_errors({
    on_error = util.HandleError,
    function(request)

      local session = GetSession(request)
      local body = {remoteip = session.ip,
                    response = request.params['g-recaptcha-response'],
                    secret = os.getenv('RECAPTCHA_SECRET')}

      body = encode_query_string(body)

      local httpc = http.new()
      local res = assert_error(httpc:request_uri("https://www.google.com/recaptcha/api/siteverify",{
        method = 'POST',
        body = body,
        headers = {
          ["Content-Type"] = "application/x-www-form-urlencoded",
        }
      }))

      local response = from_json(res.body)
      if response.success ~= true then
        request.success = false
        request.errorMessage = 'Apparently you arent human, sorry!'
        return {render = 'errors.general'}
      end

      local confirmURL = request:build_url("confirmlogin")
      assert_error(sessionAPI:RegisterAccount(session, confirmURL))
      request.success = true

      return {render = true}
    end
  }),
  GET = function() return 'Please login using the top bar'  end
}))

app:get('user.viewsub','/u/:username', capture_errors({
  on_error = util.HandleError,
  function(request)

    if not request.userInfo then
      request.errorMessage = 'User not found'
      return { render = 'errors.general' }
    end

    if request.session.userID then

      local viewingUser = userAPI:GetUser(request.session.userID)
      for _,v in pairs(request.userInfo.blockedUsers) do
        if viewingUser.id == v then
          request.viewerIsBlocked = true
        end
      end
      for _,v in pairs(viewingUser.blockedUsers) do
        if request.userID == v then
          request.userIsBlocked = true
          break
        end
      end
    end

    return {render = 'user.viewsub'}
  end
}))

app:get('user.delete', '/u/delete/:username', capture_errors({
  on_error = util.HandleError,
  function(request)

    local userID = request.session.userID
    local username = request.params.username

    assert_error(userAPI:DeleteUser(userID, username))

    return { redirect_to = request:url_for("home") }

  end
}))

app:get('confirmLogin', '/confirmlogin', capture_errors({
  on_error = util.HandleError,
  function(request)
    local session = GetSession(request)
    local key = request.params.key
    if not key then
      return 'No key provided'
    end

    local account, sessionID = sessionAPI:ConfirmLogin(session, request.params.key)

    if not account then
      -- TODO: change this to a custom failure page
      print('couldnt login:', sessionID)
      return { redirect_to = request:url_for("home") }
    end

    if account.defaultUserID then
      local defaultUser = assert_error(userAPI:GetUserSettings(account.defaultUserID))
      request.session.userID = defaultUser.id
      request.session.username = defaultUser.username

    else

      request.session.userID = account.currentUserID
      request.session.username = account.currentUsername
    end


    request.session.accountID = account.id
    request.session.sessionID = sessionID

    if not account.currentUsername then
      return { redirect_to = request:url_for("newsubuser") }
    end

    if not request.session.userID then
      return { redirect_to = request:url_for("newsubuser") }
    end

    return { redirect_to = request:url_for("home") }
  end
}))


app:get('user.viewsubcomments','/u/:username/comments', capture_errors({
  on_error = util.HandleError,
  function(request)

    request.userID = userAPI:GetUserID(request.params.username)
    request.userInfo = userAPI:GetUser(request.userID)
    if not request.userInfo then
      return 'user not found'
    end

    local startAt = request.params.startAt or 0
    local range = request.params.range or 20
    range = math.min(range, 50)
    local sortBy = 'date'
    local userID = request.session.userID
    request.comments = assert_error(commentAPI:GetUserComments(userID, request.userID, sortBy, startAt, range))

    return {render = true}
  end
}))

app:get('user.viewsubposts','/u/:username/posts', capture_errors({
  on_error = util.HandleError,
  function(request)

    request.userID = userAPI:GetUserID(request.params.username)
    request.userInfo = userAPI:GetUser(request.userID)

    local startAt = request.params.startAt or 0
    local range = request.params.range or 20
    range = math.min(range, 50)

    request.posts = assert_error(postAPI:GetUserPosts(request.session.userID, request.userID, startAt,range))
    return {render = true}
  end
}))

app:get('user.viewsubupvotes','/u/:username/posts/upvoted', capture_errors({
  on_error = util.HandleError,
  function(request)
    local userID = userAPI:GetUserID(request.params.username)
    if not userID then
      return 'user not found'
    end

    local posts = assert_error(userAPI:GetRecentPostVotes(request.session.userID, userID,'up'))

    request.posts = posts
    return {render = true}
  end
}))


app:get('logout','/u/logout', capture_errors(function(request)
  request.session.accountID = nil
  request.session.userID = nil
  request.session.sessionID = nil
  request.session.username = nil
  request.account = nil
  return { redirect_to = request:url_for("home") }
end))

app:get('user.switch','/u/switch/:userID', capture_errors({
  on_error = util.HandleError,
  function(request)
    local newUser, err = assert_error(userAPI:SwitchUser(request.session.accountID, request.params.userID))
    if not newUser then
      return 'error switching user:'..err
    end
    request.session.userID = newUser.id
    request.session.username = newUser.username

    return { redirect_to = request:url_for("home") }
  end
}))

app:get('user.setdefault','/u/default/:userID', capture_errors({
  on_error = util.HandleError,
  function(request)
    assert_error(userAPI:SetDefault(request.session.accountID, request.session.userID, request.params.userID))
    return { redirect_to = request:url_for("listusers") }
  end
}))

app:get('listusers','/u/list',capture_errors({
  on_error = util.HandleError,
  function(request)
    request.otherUsers = userAPI:GetAccountUsers(request.session.accountID, request.session.accountID)
    return {render = true}
  end
}))

app:get('subscribeusercomment','/u/:username/comments/sub',capture_errors({
  on_error = util.HandleError,
  function(request)
    local userID = request.session.userID
    local username = request.params.username
    if not username then
      yield_error('user not found')
    end

    local userToSubToID = assert_error(userAPI:GetUserID(username))
    assert_error(userAPI:ToggleCommentSubscription(userID, userToSubToID))

    return { redirect_to = request:url_for("user.viewsubcomments", {username = request.params.username}) }

  end
}))

app:get('subscribeuserpost','/u/:username/posts/sub',capture_errors({
  on_error = util.HandleError,
  function(request)
    local userID = request.session.userID
    local username = request.params.username

    if not username then
      return 'user not found'
    end

    local userToSubToID = assert_error(userAPI:GetUserID(username))

    assert_error(userAPI:TogglePostSubscription(userID, userToSubToID))

    return { redirect_to = request:url_for("user.viewsubposts", {username = request.params.username}) }
  end
}))

app:post('blockuser','/u/:username/block',capture_errors({
  on_error = util.HandleError,
  function(request)

    local userToBlockID = userAPI:GetUserID(request.params.username)

    assert_error(userAPI:BlockUser(request.session.userID, userToBlockID))

    return { redirect_to = request:url_for("user.viewsub", {username = request.params.username}) }

  end
}))
