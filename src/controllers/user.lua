

local m = {}
m.__index = m

local respond_to = (require 'lapis.application').respond_to
local api = require 'api.api'
local trim = (require 'lapis.util').trim
local to_json = (require 'lapis.util').to_json

local function NewUserForm(self)
  return {render = 'newuser'}
end


local function CreateNewUser(self)
  local info = {}
  info.username = self.params.username
  info.password = self.params.password
  info.email = self.params.email

  local confirmURL = self:build_url()..self:url_for("confirmemail")
  local ok,err  = api:CreateMasterUser(confirmURL, info)
  if not ok then
    ngx.log(ngx.ERR, 'unable to activate:',err)
    return {render = err, status = 400}
  end


  return 'success, please activate your account via email'

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
  local userID = api:GetUserID(self.params.username)
  self.userInfo = api:GetUserInfo(userID)
  self.comments = api:GetUserComments(self.session.userID, userID)
  for _,v in pairs(self.comments) do
    v.username = api:GetUserInfo(v.createdBy).username
  end
  ngx.log(ngx.ERR, to_json(self.comments))
  return {render = 'viewuser'}
end

local function LoginUser(self)
  -- check theyve provided the correct credentials
  local email = self.params.email
  local password = self.params.password
  if not email or not password then
    return { redirect_to = self:url_for("register") }
  end

  local userCredentials = {
    email = email,
    password = password
  }

  local masterInfo, inactive = api:ValidateMaster(userCredentials)
  if masterInfo then
    print(to_json(masterInfo))
    self.session.userID = masterInfo.currentUserID
    local userInfo = api:GetUserInfo(self.session.userID)
    self.session.username = userInfo.username
    self.session.masterID = masterInfo.id
    return { redirect_to = self:url_for("home") }
  elseif inactive then
    return 'Your account has not been activated, please click the link in your email'
  else
    return { render = 'newuser' }
  end
end

local function NewSubUser(self)
  return {render = 'newsubuser'}
end

local function CreateSubUser(self)
  if not self.params.username or trim(self.params.username) == '' then
    return 'no username!'
  end
  local succ = api:CreateSubUser(self.session.masterID,self.params.username)
  if succ then
    return 'win!'
  else
    return 'fail'
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

function m:Register(app)

  app:match('newuser','/user/new', respond_to({
    GET = NewUserForm,
    POST = CreateNewUser
  }))
  app:match('newsubuser','/sub/new', respond_to({
    GET = NewSubUser,
    POST = CreateSubUser
  }))


  app:post('login','/login',LoginUser)
  app:get('viewuser','/user/:username',ViewUser)
  app:get('logout','/logout',LogOut)
  app:get('confirmemail','/confirmemail',ConfirmEmail)
  app:get('switchuser','/user/switch/:userID',SwitchUser)

end


return m
