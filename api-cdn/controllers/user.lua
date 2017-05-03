

local m = {}
m.__index = m

local respond_to = (require 'lapis.application').respond_to
local userAPI = require 'api.users'
local commentAPI = require 'api.comments'
local sessionAPI = require 'api.sessions'
local trim = (require 'lapis.util').trim
local to_json = (require 'lapis.util').to_json

function m.LogOut(request)
  request.session.username = nil
  request.session.userID = nil
  request.session.accountID = nil
  return { redirect_to = request:url_for("home") }
end

function m.ViewUser(request)
  request.userID = userAPI:GetUserID(request.params.username)
  request.userInfo = userAPI:GetUser(request.userID)

  local startAt = request.params.startAt or 0
  local range = request.params.range or 20
  range = math.min(range, 50)
  local sortBy = 'date'
  request.comments = commentAPI:GetUserComments(request.session.userID, request.userID, sortBy, startAt, range)
  for _,v in pairs(request.comments) do
    v.username = userAPI:GetUser(v.createdBy).username
  end

  return {render = 'user.viewsub'}
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
    return { redirect_to = request:url_for("usersettings") }
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
  local session = {
    ip = ngx.var.remote_addr,
    userAgent = ngx.var.http_user_agent,
    email = request.params.email
  }
  print(ngx.var.http_user_agent)
  print(ngx.var.remote_addr)
  local confirmURL = request:build_url("confirmlogin")
  local ok, err = sessionAPI:RegisterAccount(session, confirmURL)
  if not ok then
    return 'There was an error registering you, please try again later'
  else
    return "Thanks, we've sent you a login email, please check it to log in."
  end
end

function m.ConfirmLogin(request)
  local session = {
    ip = ngx.var.remote_addr,
    userAgent = ngx.var.http_user_agent,
    email = request.params.email
  }
  local account, sessionID = sessionAPI:ConfirmLogin(session, request.params.key)
  print()

  if not account then
    -- TODO: change this to a custom failure page
    return { redirect_to = request:url_for("home") }
  end

  print(to_json(account))
  print(sessionID)
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


function m:Register(app)

  app:match('newsubuser','/sub/new', respond_to({
    GET = self.NewSubUser,
    POST = self.CreateSubUser
  }))

  app:post('login','/login',self.NewLogin)
  app:get('confirmLogin', '/confirmlogin', self.ConfirmLogin)
  app:post('taguser', '/user/tag/:userID', self.TagUser)
  app:get('viewuser','/user/:username', self.ViewUser)
  app:get('logout','/logout', self.LogOut)
  app:get('switchuser','/user/switch/:userID', self.SwitchUser)
  app:get('listusers','/user/list',function() return {render = 'listusers'} end)

end


return m
