



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

local app_helpers = require("lapis.application")
local capture_errors, assert_error = app_helpers.capture_errors, app_helpers.assert_error

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
  POST = capture_errors(function(request)
    if not request.params.username or trim(request.params.username) == '' then
      return 'no username!'
    end

    local succ = assert_error(userAPI:CreateSubUser(request.session.accountID,request.params.username))

    request.session.username = succ.username
    request.session.userID = succ.id
    return { redirect_to = request:url_for("user.subsettings")..'?stage=1' }

  end)
}))

app:match('login','/login',respond_to({
  POST = capture_errors(function(request)

      local session = GetSession(request)
      local body = {remoteip = session.ip,
                    response = request.params['g-recaptcha-response'],
                    secret = os.getenv('RECAPTCHA_SECRET')}

      body = encode_query_string(body)


      local httpc = http.new()
      local res = assert_error(httpc:request_uri("https://www.google.com/recaptcha/api/siteverify",{
        method='POST',
        body=body,
        headers = {
          ["Content-Type"] = "application/x-www-form-urlencoded",
        }
      }))

      local response = from_json(res.body)
      if response.success ~= true then
        print(to_json(response))
        request.success = false
        request.errorMessage = 'Apparently you arent human, sorry!'
        return {render = 'user.login'}
      end

      local confirmURL = request:build_url("confirmlogin")
      sessionAPI:RegisterAccount(session, confirmURL)
      request.success = true

      return {render = 'user.login'}
  end),
  GET = function() return 'Please login using the top bar'  end
}))

app:get('user.viewsub','/u/:username', capture_errors(function(request)
  -- deny public by default
  request.userID = userAPI:GetUserID(request.params.username)
  request.userInfo = userAPI:GetUser(request.userID)
  if not request.userInfo then
    return 'user not found'
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
end))

app:get('deleteuser', '/user/:username/delete', capture_errors(function(request)
  if not request.session.userID then
    return {render = 'pleaselogin'}
  end

  local userID = request.session.userID
  local username = request.params.username
  if not userID then
    return {render = 'pleaselogin'}
  end

  assert_error(userAPI:DeleteUser(userID, username))

  return 'deleted'

end))

app:get('confirmLogin', '/confirmlogin', capture_errors(function(request)
  local session = GetSession(request)
  local account, sessionID = sessionAPI:ConfirmLogin(session, request.params.key)

  if not account then
    -- TODO: change this to a custom failure page
    print('couldnt login:', sessionID)
    return { redirect_to = request:url_for("home") }
  end
  print('got account: ',account.id)

  request.session.accountID = account.id
  request.session.userID = account.currentUserID
  request.session.username = account.currentUsername
  request.session.sessionID = sessionID

  if not account.currentUsername then
    return { redirect_to = request:url_for("newsubuser") }
  end

  if not request.session.userID then
    return { redirect_to = request:url_for("newsubuser") }
  end

  return { redirect_to = request:url_for("home") }
end))


app:get('user.viewsubcomments','/user/:username/comments', capture_errors(function(request)
  if not request.session.userID then
    return {render = 'pleaselogin'}
  end
  request.userID = userAPI:GetUserID(request.params.username)
  request.userInfo = userAPI:GetUser(request.userID)
  if not request.userInfo then
    return 'user not found'
  end

  local startAt = request.params.startAt or 0
  local range = request.params.range or 20
  range = math.min(range, 50)
  local sortBy = 'date'

  request.comments = commentAPI:GetUserComments(request.session.userID, request.userID, sortBy, startAt, range)

  return {render = true}
end))

app:get('user.viewsubposts','/user/:username/posts', capture_errors(function(request)
  if not request.session.userID then
    return {render = 'pleaselogin'}
  end

  request.userID = userAPI:GetUserID(request.params.username)
  request.userInfo = userAPI:GetUser(request.userID)


    local startAt = request.params.startAt or 0
    local range = request.params.range or 20
    range = math.min(range, 50)

  request.posts = postAPI:GetUserPosts(request.session.userID, request.userID, startAt,range)
  return {render = true}
end))

app:get('user.viewsubupvotes','/user/:username/posts/upvoted', capture_errors(function(request)
  local userID = userAPI:GetUserID(request.params.username)
  if not userID then
    return 'user not found'
  end
  if not request.session.userID then
    return {render = 'pleaselogin'}
  end

  local posts = assert_error(userAPI:GetRecentPostVotes(request.session.userID, userID,'up'))

  request.posts = posts
  return {render = true}
end))


app:get('logout','/logout', capture_errors(function(request)
  request.session.accountID = nil
  request.session.userID = nil
  request.session.sessionID = nil
  request.session.username = nil
  request.account = nil
  return { redirect_to = request:url_for("home") }
end))

app:get('switchuser','/user/switch/:userID', capture_errors(function(request)
  local newUser = userAPI:SwitchUser(request.session.accountID, request.params.userID)
  if not newUser then
    return 'error switching user:'
  end
  request.session.userID = newUser.id
  request.session.username = newUser.username

  return { redirect_to = request:url_for("home") }
end))

app:get('listusers','/user/list',capture_errors(function(request)
  if not request.session.accountID then
    return {render = 'pleaselogin'}
  end
  request.otherUsers = userAPI:GetAccountUsers(request.session.accountID, request.session.accountID)
  return {render = true}
end))

app:get('subscribeusercomment','/user/:username/comments/sub',capture_errors(function(request)
  local userID = request.session.userID
  local username = request.params.username
  if not userID then
    return {render = 'pleaselogin'}
  end
  if not username then
    return 'user not found'
  end

  local userToSubToID = userAPI:GetUserID(username)

  assert_error(userAPI:ToggleCommentSubscription(userID, userToSubToID))

  return { redirect_to = request:url_for("user.viewsubcomments", {username = request.params.username}) }

end))

app:get('subscribeuserpost','/user/:username/posts/sub',capture_errors(function(request)
  local userID = request.session.userID
  local username = request.params.username
  if not userID then
    return {render = 'pleaselogin'}
  end
  if not username then
    return 'user not found'
  end

  local userToSubToID = assert_error(userAPI:GetUserID(username))

  assert_error(userAPI:TogglePostSubscription(userID, userToSubToID))

  return { redirect_to = request:url_for("viewuserposts", {username = request.params.username}) }
end))

app:post('blockuser','/user/:username/block',capture_errors(function(request)
  if not request.session.userID then
    return {render = 'pleaselogin'}
  end
  local userToBlockID = userAPI:GetUserID(request.params.username)

  assert_error(userAPI:BlockUser(request.session.userID, userToBlockID))

  return { redirect_to = request:url_for("user.viewsub", {username = request.params.username}) }

end))
