

local m = {}
m.__index = m

local uuid = require 'uuid'
local respond_to = (require 'lapis.application').respond_to
local api = require 'api.api'
local trim = (require 'lapis.util').trim

local function NewUserForm(self)
  return {render = 'newuser'}
end


local function CreateNewUser(self)
  local info = {}
  info.username = self.params.username
  info.password = self.params.password
  info.email = self.params.email

  local confirmURL = self:build_url()..self:url_for("confirmemail")
  local ok,err  = api:CreateUser(confirmURL, info)
  if not ok then
    ngx.log(ngx.ERR, 'unable to activate:',err)
    return {render = err, status = 400}
  end


  return 'success, please activate your account via email'

end

local function LoginPost(self)



  local userInfo = cache:LoadUserByUsername(self.params.username)
  if not userInfo then
    return 'login failed!'
  end

  if userInfo.active == false then
    return 'you need to activate your account via email'
  end
  if scrypt.check(self.params.password,userInfo.passwordHash) then
    self.session.current_user = userInfo.username
    self.session.current_user_id = userInfo.id
    return { redirect_to = self:url_for("home") }
  else
   return 'login failed'
  end

end




local function DisplayConfirmation()
  return 'registration complete!, please check your email for activation key'
end




local function ConfirmEmail(self)
  -- check for username and activateKey

  local ok, err = api:ActivateAccount(self.params.email,self.params.activateKey)
  if ok then
    return 'you have successfully activated your account, please login!'
  else
    return err
  end

  local userInfo = cache:LoadUserCredentialsByEmail(self.params.email)

  local newHash  = ngx.md5(userInfo.username..self.params.email..salt)

  if GetActivationKey(newHash) == self.params.activateKey then
    cache:ActivateUser(userInfo.id)
    return 'you have successfully activated your account, please login!'
  else
    return 'activation failed, you suckkkk'
  end

end

local function LogOut(self)
  self.session.current_user = nil
  self.session.current_user_id = nil
  return { redirect_to = self:url_for("home") }
end



local function ViewUser(self)
  self.comments = cache:GetUserComments(self.params.username)

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

  local userInfo, inactive = api:ValidateUser(userCredentials)
  if userInfo then
    self.session.current_user = userInfo.username
    self.session.curent_user = userInfo.id
    return { redirect_to = self:url_for("home") }
  elseif inactive then
    return 'Your account has not been activated, please click the link in your email'
  else
    return { render = 'newuser' }
  end
end

function m:Register(app)

  app:match('newuser','/user/new', respond_to({
    GET = NewUserForm,
    POST = CreateNewUser
  }))

  app:post('login','/login',LoginUser)
  app:get('viewuser','/user/:username',ViewUser)
  app:get('logout','/logout',LogOut)
  app:get('confirmemail','/confirmemail',ConfirmEmail)

end


return m
