


local m = {}
m.__index = m

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



function m:Register(app)

  app:match('newsubuser','/sub/new', respond_to({
    GET = self.NewSubUser,
    POST = self.CreateSubUser
  }))

  app:match('login','/login',respond_to({
    POST = self.NewLogin,
    GET = function() return 'Please login using the top bar'  end
  }))

  app:get('viewuser','/user/:username', self.ViewUser)
  app:get('deleteuser', '/user/:username/delete', self.DeleteUser)

  app:get('confirmLogin', '/confirmlogin', self.ConfirmLogin)
  app:post('taguser', '/user/tag/:userID', self.TagUser)

  app:get('viewusercomments','/user/:username/comments', self.ViewUserComments)
  app:get('viewuserposts','/user/:username/posts', self.ViewUserPosts)
  app:get('viewuserupvoted','/user/:username/posts/upvoted', self.ViewUserUpvoted)
  app:get('logout','/logout', self.LogOut)
  app:get('switchuser','/user/switch/:userID', self.SwitchUser)
  app:get('listusers','/user/list',self.ListUsers)
  app:get('subscribeusercomment','/user/:username/comments/sub',self.SubUserComment)
  app:get('subscribeuserpost','/user/:username/posts/sub',self.SubUserPost)
  app:post('blockuser','/user/:username/block',self.BlockUser)

end

function m.ListUsers(request)
  request.otherUsers = userAPI:GetAccountUsers(request.session.accountID, request.session.accountID)
  return {render = 'listusers'}
end

function m.BlockUser(request)
  if not request.session.userID then
    return {render = 'pleaselogin'}
  end
  local userToBlockID = userAPI:GetUserID(request.params.username)

  local ok, err = userAPI:BlockUser(request.session.userID, userToBlockID)
  if ok then
    return { redirect_to = request:url_for("viewuser", {username = request.params.username}) }
  else
    print(err)
    return 'error blocking user'
  end
end

function m.ViewUserUpvoted(request)
  local userID = userAPI:GetUserID(request.params.username)
  if not userID then
    return 'user not found'
  end
  if not self.session.userID then
    return {render = 'pleaselogin'}
  end

  local posts, err = userAPI:GetRecentPostVotes(request.session.userID, userID,'up')
  if not  posts  then
    print('posts not found,  ',err)
    return 'none found'
  end
  print(to_json(posts))
  request.posts = posts
  return {render = 'user.viewsubupvotes'}
end

function m.SubUserComment(request)
  local userID = request.session.userID
  local username = request.params.username
  if not userID then
    return {render = 'pleaselogin'}
  end
  if not username then
    return 'user not found'
  end

  local userToSubToID = userAPI:GetUserID(username)

  local ok, err = userAPI:ToggleCommentSubscription(userID, userToSubToID)
  if not ok  then
    return err
  end

  return { redirect_to = request:url_for("viewusercomments", {username = request.params.username}) }

end

function m.SubUserPost(request)
  local userID = request.session.userID
  local username = request.params.username
  if not userID then
    return {render = 'pleaselogin'}
  end
  if not username then
    return 'user not found'
  end

  local userToSubToID = userAPI:GetUserID(username)

  local ok, err = userAPI:TogglePostSubscription(userID, userToSubToID)
  if not ok  then
    return err
  end

  return { redirect_to = request:url_for("viewuserposts", {username = request.params.username}) }

end

function m.LogOut(request)
  request.session.accountID = nil
  request.session.userID = nil
  request.session.sessionID = nil
  request.session.username = nil
  request.account = nil
  return { redirect_to = request:url_for("home") }
end

function m.DeleteUser(request)

  local userID = request.session.userID
  local username = request.params.username
  if not userID then
    return {render = 'pleaselogin'}
  end

  local ok , err = userAPI:DeleteUser(userID, username)
  if ok then
    return 'deleted'
  else
    print('error: ', err)
    return 'error deleting user'
  end

end

function m.ViewUser(request)
  request.userID = userAPI:GetUserID(request.params.username)
  request.userInfo = userAPI:GetUser(request.userID)
  if not request.userInfo then
    return 'user not found'
  end

  if request.session.userID then
    print('this')
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

function m.ViewUserComments(request)
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

  return {render = 'user.viewsubcomments'}
end

function m.ViewUserPosts(request)

  request.userID = userAPI:GetUserID(request.params.username)
  request.userInfo = userAPI:GetUser(request.userID)


    local startAt = request.params.startAt or 0
    local range = request.params.range or 20
    range = math.min(range, 50)

  request.posts = postAPI:GetUserPosts(request.session.userID, request.userID, startAt,range)
  return {render = 'user.viewsubposts'}
end


function m.NewSubUser(request)
  return {render = 'user.createsub'}
end

function m.CreateSubUser(request)
  if not request.params.username or trim(request.params.username) == '' then
    return 'no username!'
  end

  local succ,err = userAPI:CreateSubUser(request.session.accountID,request.params.username)
  if succ then
    request.session.username = succ.username
    request.session.userID = succ.id
    return { redirect_to = request:url_for("usersettings")..'?stage=1' }
  else
    return 'fail: '..err
  end
end


function m.SwitchUser(request)
  local newUser = userAPI:SwitchUser(request.session.accountID, request.params.userID)
  if not newUser then
    return 'error switching user:'
  end
  request.session.userID = newUser.id
  request.session.username = newUser.username

  return { redirect_to = request:url_for("home") }

end

function m.TagUser(request)

  local userTag = request.params.tagUser

  local ok, err = userAPI:LabelUser(request.session.userID, request.params.userID, userTag)
  if ok then
    return 'success'
  else
    return 'fail: '..err
  end

end



function m.NewLogin(request)

  local session = m.GetSession(request)
  local body = {remoteip = session.ip,
                response = request.params['g-recaptcha-response'],
                secret = os.getenv('RECAPTCHA_SECRET')}

  body = encode_query_string(body)


  local httpc = http.new()
  local res, err = httpc:request_uri("https://www.google.com/recaptcha/api/siteverify",{
    method='POST',
    body=body,
    headers = {
      ["Content-Type"] = "application/x-www-form-urlencoded",
    }
  })

  if not res then
    request.success = false
    request.errorMessage = 'There was an error registering you, please try again later'
    return {render = 'user.login'}
  end
  local response = from_json(res.body)
  if response.success ~= true then
    request.success = false
    request.errorMessage = 'Apparently you arent human, sorry!'
    return {render = 'user.login'}
  end

  local confirmURL = request:build_url("confirmlogin")
  local ok,code, err = sessionAPI:RegisterAccount(session, confirmURL)
  if code == 429 then
    return {render = 'errors.'..code}
  end

  if not ok then
    request.success = false
    request.errorMessage = 'There was an error registering you, please try again later'
  else
    request.success = true
  end
  return {render = 'user.login'}
end

function m.GetSession(request)
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

function m.ConfirmLogin(request)
  local session = m.GetSession(request)
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

end



return m
