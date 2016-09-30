

local m = {}
m.__index = m

local respond_to = (require 'lapis.application').respond_to
local api = require 'api.api'
local trim = (require 'lapis.util').trim
local to_json = (require 'lapis.util').to_json

local function NewUserForm(self)
  return {render = 'user.creatmaster'}
end


local function CreateNewUser(self)
  local info = {}
  info.username = self.params.username
  info.password = self.params.password
  info.email = self.params.email

  local confirmURL = self:build_url()..self:url_for("confirmemail")
  local ok,err  = api:CreateMasterUser(confirmURL, info)

  if ok then
    return 'Success, please activate your account via email!'
  else
    return 'Unable to create account: '..err
  end

end

local function LogOut(self)
  self.session.username = nil
  self.session.userID = nil
  self.session.accountID = nil
  return { redirect_to = self:url_for("home") }
end

local function ViewUser(self)
  self.userID = api:GetUserID(self.params.username)
  self.userInfo = api:GetUserInfo(self.userID)
  print(to_json(self.userInfo))
  self.comments = api:GetUserComments(self.session.userID, self.userID)
  for _,v in pairs(self.comments) do
    v.username = api:GetUserInfo(v.createdBy).username
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
  local user = api:GetUserInfo(self.params.userID)
  if user.parentID == self.session.masterID then
    self.session.userID = user.id
    self.session.username = user.username
    return { redirect_to = self:url_for("home") }
  end

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
  local user, err = api:ConfirmLogin(self.params, self.params.key)
  print(to_json(user))
  if user then

    self.session.accountID = user.accountID

    if not user.username then
      return { redirect_to = self:url_for("newsubuser") }
    end

    self.session.userID = user.id
    self.session.username = user.username
    self.session.accountID = user.accountID
  end

  if user then
    return { redirect_to = self:url_for("home") }
  else
    -- TODO: change this to a custom failure page
    return { redirect_to = self:url_for("home") }
  end

end

function m:Register(app)

  app:match('newuser','/user/new', respond_to({
    GET = NewUserForm,
    POST = CreateNewUser
  }))
  app:match('newsubuser','/sub/new', respond_to({
    GET = NewSubUser,
    POST = CreateSubUser
  }))

  app:match('resetpasswordlink','/passwordreset', respond_to({
    GET = ResetPasswordLink,
    POST = ChangePassword
  }))

  app:post('login','/login',NewLogin)
  app:get('confirmLogin', '/confirmlogin', ConfirmLogin)
  app:post('taguser', '/user/tag/:userID', TagUser)
  app:get('viewuser','/user/:username',ViewUser)
  app:get('logout','/logout',LogOut)
  app:get('confirmemail','/confirmemail',ConfirmEmail)
  app:get('switchuser','/user/switch/:userID',SwitchUser)
  app:get('test', '/test',function() return ngx.encode_base64(ngx.sha1_bin('test')) end)

end


return m
