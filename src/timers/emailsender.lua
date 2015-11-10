
local CONFIG_CHECK_INTERVAL = 5

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

  if not self.util:GetLock('SendEmail', 10) then
    return
  end

  local keys = self.emailDict:get_keys(1)
  for _, recipientAddress in pairs(keys) do
    ok = self.emailDict:get(recipientAddress)
    if not ok then
      return
    end

    local emailInfo = from_json(ok)
    ok, err = self.emailer:SendMessage(emailInfo.subject, emailInfo.body, recipientAddress)
    if not ok then
      return
    end

    self.emailDict:delete(recipientAddress)

  end


end

return config
