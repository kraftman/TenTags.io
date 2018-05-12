
local config = require("lapis.config").get()
local emailDict = ngx.shared.emailQueue
local uuid = require ('lib.uuid')
local lapis = require 'lapis'

local to_json = (require 'lapis.util').to_json

local function HandleError(self, err, trace)
  print('handling err ', err)
  if config.hide_errors then
    ngx.log(ngx.ERR, 'BIG ERROR!!', err)
    local error = {
      time = ngx.time(),
      trace = trace,
      error = err,
      id = uuid.generate_random(),
      path = ngx.var.uri
    }
    self.error = error
    local ok, newerr = emailDict:lpush('errorEmails', to_json(error))
    if not ok then
      ngx.log(ngx.ERR, 'unable to q error email: ', newerr)
    end
    return {render = 'errors.500'}
  else
    return lapis.Application.handle_error(self, err, trace)
  end

end

return HandleError
