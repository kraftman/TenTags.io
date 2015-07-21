

local m = {}
m.__index = m

local scrypt = require 'scrypt'
local email = require 'testemail'
local uuid = require 'uuid'
local salt = 'poopants'
local respond_to = (require 'lapis.application').respond_to
local db = require("lapis.db")

local function NewUserForm(self)
  return {render = 'newuser'}
end

local function GetActivationKey(hash)
  return hash:match('.+(........)$')
end

local function CreateNewUser(self)
  local info = {}
  info.id = uuid.generate_random()
  info.passwordHash = scrypt.crypt(self.params.password)
  info.username = self.params.username
  info.active = false
  info.email = self.params.email


  db.insert('user',{
    id = info.id,
    username = info.username,
    email = info.email,
    passwordHash = info.passwordHash,
    active = info.active
  })
  return GetActivationKey(ngx.md5(info.username..info.email..salt))
end

local function LoginPost(self)

  local res = db.select("username,passwordHash,id from user where username = ?", self.params.username)
  res = res[1]
  if not res then
    return 'login failed!'
  end

  if res.active == false then
    return 'you need to activate your account via email'
  end
  if scrypt.check(self.params.password,res.passwordHash) then
    self.session.current_user = res.username
    self.session.currend_user_id = res.id
    return 'login successful!'
  else
   return 'login failed'
  end

end


local function SendEmail(self, activateKey)
  local url = self:build_url()..self:url_for("confirmemail")..'?email='..self.params.email..'&activateKey='..activateKey
  local subject = "Email confirmation"
  local body = [[
    Congrats for registering, you are the best!
    Please click this link to confirm your email address
  ]]
  body = body..url
  email:sendMessage(subject,body,self.params.email)

end

local function DisplayConfirmation()
  return 'registration complete!, please check your email for activation key'
end

local function RegisterUser(self)
  local activateKey = CreateNewUser(self)
  SendEmail(self, activateKey)
  return DisplayConfirmation()
end


local function ConfirmEmail(self)
  -- check for username and activateKey

  local res = db.select("username,passwordHash from user where email = ?", self.params.email)

  res = res[1]

  local newHash  = ngx.md5(res.username..self.params.email..salt)

  if GetActivationKey(newHash) == self.params.activateKey then
    db.update('user', {
      active = true
    })
    return 'you have successfully activated your account, please login!'
  else
    return 'activation failed, you suckkkk'
  end

end

local function LogOut(self)
  self.session.current_user = nil
  return 'logged out!'
end

local function LoginForm(self)
  return {render = 'login'}
end

local function ViewUser(self)
  return 'meeeeeeeeep'
end


function m:Register(app)

  app:match('newuser','/user/new', respond_to({
    GET = NewUserForm,
    POST = RegisterUser
  }))

  app:get('viewuser','/user/:id',ViewUser)

  app:match('login','/login', respond_to({
    GET = LoginForm,
    POST = LoginPost
  }))


  app:get('logout','/logout',LogOut)

  app:post('/login', LoginPost)
  app:get('confirmemail','/confirmemail',ConfirmEmail)

end


return m
