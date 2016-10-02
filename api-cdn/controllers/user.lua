

local m = {}
m.__index = m

local respond_to = (require 'lapis.application').respond_to
local api = require 'api.api'
local trim = (require 'lapis.util').trim
local to_json = (require 'lapis.util').to_json

local function LogOut(self)
  self.session.username = nil
  self.session.userID = nil
  self.session.accountID = nil
  return { redirect_to = self:url_for("home") }
end

local function ViewUser(self)
  self.userID = api:GetUserID(self.params.username)
  self.userInfo = api:GetUser(self.userID)
  print(to_json(self.userInfo))
  self.comments = api:GetUserComments(self.session.userID, self.userID)
  for _,v in pairs(self.comments) do
    v.username = api:GetUser(v.createdBy).username
  end

  return {render = 'user.viewsub'}
end


local function NewSubUser(self)
  return {render = 'user.createsub'}
end

local function CreateSubUser(self)
  if not self.params.username or trim(self.params.username) == '' then
    return 'no username!'
  end
  local succ,err = api:CreateSubUser(self.session.accountID,self.params.username)
  if succ then
    self.session.username = succ.username
    self.session.userID = succ.id
    return { redirect_to = self:url_for("usersettings") }
  else
    return 'fail: '..err
  end
end


local function SwitchUser(self)
  local newUser = api:SwitchUser(self.session.accountID, self.params.userID)
  if not newUser then
    return 'error switching user:'
  end
  self.session.userID = newUser.id
  self.session.username = newUser.username

  return { redirect_to = self:url_for("home") }

end

local function TagUser(self)

  local userTag = self.params.tagUser

  local ok, err = api:LabelUser(self.session.userID, self.params.userID, userTag)
  if ok then
    return 'success'
  else
    return 'fail: '..err
  end

end



local function NewLogin(self)
  local session = {
    ip = ngx.var.remote_addr,
    userAgent = ngx.var.http_user_agent,
    email = self.params.email
  }
  local confirmURL = self:build_url("confirmlogin")
  local ok, err = api:RegisterAccount(session, confirmURL)
  if not ok then
    return 'There was an error registering you, please try again later'
  else
    return "Thanks, we've sent you a login email, please check it to log in."
  end
end

local function ConfirmLogin(self)
  local session = {
    ip = ngx.var.remote_addr,
    userAgent = ngx.var.http_user_agent,
    email = self.params.email
  }
  local account, sessionID = api:ConfirmLogin(session, self.params.key)

  if not account then
    -- TODO: change this to a custom failure page
    return { redirect_to = self:url_for("home") }
  end

  self.session.accountID = account.id
  self.session.userID = account.currentUserID
  self.session.username = account.currentUsername
  self.session.sessionID = sessionID

  if not account.currentUsername then
    return { redirect_to = self:url_for("newsubuser") }
  end

  if not self.session.userID then
    return { redirect_to = self:url_for("newsubuser") }
  end

  return { redirect_to = self:url_for("home") }

end

function m:Register(app)


  app:match('newsubuser','/sub/new', respond_to({
    GET = NewSubUser,
    POST = CreateSubUser
  }))


  app:post('login','/login',NewLogin)
  app:get('confirmLogin', '/confirmlogin', ConfirmLogin)
  app:post('taguser', '/user/tag/:userID', TagUser)
  app:get('viewuser','/user/:username',ViewUser)
  app:get('logout','/logout',LogOut)
  app:get('switchuser','/user/switch/:userID',SwitchUser)

end


return m
