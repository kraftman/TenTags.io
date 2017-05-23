
local CONFIG_CHECK_INTERVAL = 5

local config = {}
config.__index = config
config.http = require 'lib.http'
config.cjson = require 'cjson'
local sessionLastSeenDict = ngx.shared.sessionLastSeen

local to_json = (require 'lapis.util').to_json
local emailDict = ngx.shared.emailQueue


local common = require 'timers.common'
setmetatable(config, common)

function config:New(util)
  local c = setmetatable({},self)
  c.util = util

  return c
end

function config.Run(_,self)
  local ok, err = ngx.timer.at(CONFIG_CHECK_INTERVAL, self.Run, self)
  if not ok then
    if not err:find('process exiting') then
      ngx.log(ngx.ERR, 'WARNING: unable to reschedule postupdater: '..err)
    end
  end

  self.startTime = ngx.now()
  self:ProcessJob('registeraccount', 'ProcessAccount')
  self:FlushSessionLastSeen()

end

function config:FlushSessionLastSeen()
  --dump from shdict to redis
  local ok, err = self.util:GetLock('FlushSessionLastSeen', 10)
  if err then
    print(err)
  end
  if not ok then
    return
  end

  local sessionData = sessionLastSeenDict:get_keys()
  local sessionID, accountID,lastSeen, account,session
  for _,key in pairs(sessionData) do
    sessionLastSeenDict:get(key)
    sessionID, accountID = key:match('(%w+):(%w+)')
    lastSeen = sessionLastSeenDict:get(key)
    account = self.userRead:GetAccount(accountID)
    session = account.sessions[sessionID]
    if account and session then
      session.lastSeen = lastSeen

      ok, err = self.redisWrite:InvalidateKey('account', account.id)
      ok, err = self.userWrite:CreateAccount(account)
      if not ok then
        print('error updating lastseen:',err)
      end
    end
    sessionLastSeenDict:delete(key)

  end




end

function config:CreateAccount(accountID, session)
  local account = {
    id = accountID,
    createdAt = session.createdAt,
    sessions = {},
    users = {},
    userCount = 0,
    active = 0,
		modCount = 0
  }
  return account
end

function config:GetHash(values)
  local str = require 'resty.string'
  local resty_sha1 = require 'resty.sha1'
  local sha1 = resty_sha1:new()

  local ok, err = sha1:update(values)

  local digest = sha1:final()

  return str.to_hex(digest)
end


function config:ProcessAccount(session)

	local emailAddr = session.email
	session.email = nil

  local accountID = self:GetHash(emailAddr)
  local account = self.userRead:GetAccount(accountID)

  if not account then
    account = self:CreateAccount(accountID, session)
    ok, err = self.userWrite:AddNewUser(ngx.time(), account.id, emailAddr)

  end
	account.id = accountID

  if not session.id then
    return
  end
	account.sessions[session.id] = session

  ok, err = self.redisWrite:InvalidateKey('account', account.id)
  local ok, err = self.userWrite:CreateAccount(account)
	if not ok then
		ngx.log(ngx.ERR, err)
		return
	end

  -- TODO: move to other function

  local url = session.confirmURL..'?key='..session.id..'-'..accountID

  local email = {}
  email.body = [[ Please click this link to login: ]]
  email.body = email.body..url
  email.subject = 'Login email'
  email.recipient = emailAddr

  local ok, err = emailDict:lpush('registrationEmails', to_json(email))

  if (not ok) and err then
    ngx.log(ngx.ERR, 'unable to set emaildict: ', err)
    return nil, 'unable to send email'
  end
  if err == 'no memory' then
    ngx.log(ngx.ERR, 'WARNING: emailDict is full!')
  end

  -- Create the Account

  return true
end

return config
