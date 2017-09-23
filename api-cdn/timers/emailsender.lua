
local CONFIG_CHECK_INTERVAL = 1

local config = {}
config.__index = config
config.http = require 'lib.http'
config.cjson = require 'cjson'

local from_json = (require 'lapis.util').from_json

function config:New(util)
  local c = setmetatable({},self)
  c.util = util
  c.emailer = require 'lib.email'
  c.emailDict = ngx.shared.emailQueue

  return c
end


function config.Run(_,self)
  local ok, err = ngx.timer.at(CONFIG_CHECK_INTERVAL, self.Run, self)
  if not ok then
    if not err:find('process exiting') then
      ngx.log(ngx.ERR, 'WARNING: unable to reschedule email: '..err)
    end
  end

  self:SendRegistrationEmails()
  self:SendErrorEmails()

end

function config:SendRegistrationEmails()

  if not self.util:GetLock('SendEmail', 1) then
    return
  end


  --print('sending email')
  local ok = self.emailDict:rpop('registrationEmails')
  if not ok then
    return
  end

  local emailInfo = from_json(ok)
  print(emailInfo.body)
  ok, err = self.emailer:SendMessage(emailInfo.subject, emailInfo.body, emailInfo.recipient)
  if not ok then
    ngx.log(ngx.ERR, 'error sending email: ', err)
  end

end

function config:SendErrorEmails()

  if not self.util:GetLock('SendErrorEmail', 10) then
    return
  end
  --print('sending error emails')

  local body = ''
  local count = 0
  local ok, err
  while count <=10 do

    ok, err = self.emailDict:rpop('errorEmails')
    if not ok then
      break
    end
    local error = from_json(ok)
    body = body.. 'Error: '..error.error..'\n'..
    'Trace: '..error.trace..'\n'..
    'Time: '..error.time..'\n'..
    'ID: '..error.id..'\n'..
    'Path: '..error.path..'\n'
    count = count + 1
  end

  if body == '' then
    return
  end
  local subject = count..' Website Errors Booo'
  body = 'Errors from website: \n\n'..body

  ok, err = self.emailer:SendMessage(subject, body, 'me@itschr.is')
  if not ok then
    ngx.log(ngx.ERR, 'error getting email from stack: ', err)
  end

end

return config
