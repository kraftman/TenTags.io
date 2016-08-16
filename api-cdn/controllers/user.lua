

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

local function ConfirmEmail(self)
  -- check for username and activateKey

  local ok, err = api:ActivateAccount(self.params.email,self.params.activateKey)
  if ok then
    return 'you have successfully activated your account, please login!'
  else
    return err
  end

end

local function LogOut(self)
  self.session.username = nil
  self.session.userID = nil
  self.session.masterID = nil
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

local function LoginUser(self)
  -- check theyve provided the correct credentials
  local email = self.params.email or ''
  local password = self.params.password or ''

  if email == '' or password == '' then
    return { render = 'user.createmaster' }
  end

  local userCredentials = {
    email = email,
    password = password
  }

  local masterInfo, inactive = api:ValidateMaster(userCredentials)
  if masterInfo then
    self.session.userID = masterInfo.currentUserID
    local userInfo = api:GetUserInfo(self.session.userID)
    self.session.username = userInfo.username
    self.session.masterID = masterInfo.id
    --return 'true'
    return { redirect_to = self:url_for("home") }
  elseif inactive == true then
    return 'Your account has not been activated, please click the link in your email'
  else
    self.email = email
    return { render = 'user.createmaster' }
  end
end

local function NewSubUser(self)
  return {render = 'user.createsub'}
end

local function CreateSubUser(self)
  if not self.params.username or trim(self.params.username) == '' then
    return 'no username!'
  end
  local succ,err = api:CreateSubUser(self.session.masterID,self.params.username)
  if succ then
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

local function ResetUser(self)
  -- get the email
  -- get the master from the email
  -- set the master to restting
  -- addd a reset uui

  -- dont reveal anything about what happened
  local url = self:build_url()..'/passwordreset?email='..self.params.email..'&key='
  local ok  = api:SendPasswordReset(url, self.params.email)
  if ok then
    return 'success, please check your email'
  else
    return 'there was an error sending the password reset link'
  end

end

local function ResetPasswordLink(self)
  local emailAddr = self.params.email
  local key = self.params.key
  print(emailAddr,key)
  if not emailAddr or not key then
    return 'params missing'
  end

  local ok = api:VerifyReset(emailAddr,key)
  if not ok then
    return 'invalid key!'
  end

  self.emailAddr = emailAddr
  self.resetKey = key

  return { render = 'resetpassword'}

end

local function ChangePassword(self)
  local emailAddr = self.params.emailAddr
  local resetKey = self.params.resetKey
  local newPassword = self.params.password

  local ok = api:ResetPassword(emailAddr, resetKey, newPassword)
  if ok then
    return 'success, please login!'
  else
    return 'failure, sorry!'
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


  app:post('resetpassword', '/user/reset', ResetUser)
  app:post('login','/login',LoginUser)
  app:get('login','/login',LoginUser)
  app:post('taguser', '/user/tag/:userID', TagUser)
  app:get('viewuser','/user/:username',ViewUser)
  app:get('logout','/logout',LogOut)
  app:get('confirmemail','/confirmemail',ConfirmEmail)
  app:get('switchuser','/user/switch/:userID',SwitchUser)

end


return m
