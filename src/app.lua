local lapis = require("lapis")
local db = require("lapis.db")
local app = lapis.Application()
local uuid = require 'uuid'
--https://github.com/bungle/lua-resty-scrypt/issues/1
local scrypt = require 'scrypt'
local email = require 'testemail'
app:enable("etlua")
local schema = require("lapis.db.schema")
--local types = schema.types
local salt = 'poopants'

app:get("/", function(self)
  if self.session.current_user then
    return 'you are logged in as: '..self.session.current_user
  end
end)

app:get('/login',function(self)
  return { render = "login" }
end)

app:post('/login', function(self)
  local res = db.select("username,passwordHash from user where username = ?", self.params.username)
  res = res[1]
  if res.active = false then
    return 'you need to activate your account via email'
  end
  if scrypt.check(self.params.password,res.passwordHash) then
    self.session.current_user = res.username
    return 'login successful!'
  else
   return 'login failed'
  end

end)

app:get('/test',function(self)
  return self.session.current_user
end)

app:get('/register', function()
  return { render = "register" }
end)

local function GetActivationKey(hash)
  return hash:match('.+(........)$')
end

app:get('confirm','/userconfirm',function(self)
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

end)

local function ValidateCredentials()
  -- check passwords match etc
end



local function CreateUser(self)
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


local function SendEmail(self, activateKey)
  local url = self:build_url()..self:url_for("confirm")..'?email='..self.params.email..'&activateKey='..activateKey
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

app:post('/register',function(self)
  --validate the inputs
  --create the user
  --send an email
  -- tell them its been sents

  ValidateCredentials()
  local activateKey = CreateUser(self)
  SendEmail(self, activateKey)
  return DisplayConfirmation()



end)

app:get('/email',function(self)
  email:sendMessage('test', 'testing', 'crtanner@gmail.com')
  return 'test'
end)



return app
