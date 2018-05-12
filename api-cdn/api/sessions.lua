

local app_helpers = require("lapis.application")
local assert_error = app_helpers.assert_error

local cache = require 'api.cache'

local base = require 'api.base'
local api = setmetatable({}, base)
local sessionLastSeenDict = ngx.shared.sessionLastSeen
local to_json = (require 'lapis.util').to_json


function api:GetHash(values)
  local str = require 'resty.string'
  local resty_sha1 = require 'resty.sha1'
  local sha1 = resty_sha1:new()

  local ok, err = sha1:update(values)
  if not ok then
    ngx.log(ngx.ERR, 'unable to sha1: ',err)
    return nil
  end

  local digest = sha1:final()

  return str.to_hex(digest)
end

function api:GetAccount(accountID)
  return cache:GetAccount(accountID)
end


function api:GetAccount(userAccountID, targetAccountID)
	if userAccountID ~= targetAccountID then
		return nil, 'not available yet'
	end

	if not targetAccountID then
		return nil, 'no target accountID'
	end

	local account,err = cache:GetAccount(targetAccountID)
	return account, err

end


function api:SanitiseSession(session)

  local id = self:GetHash(ngx.time()..session.email..session.ip)

	local newSession = {
		ip = session.ip,
    category = session.category,
    os = session.os,
    browser = session.browser,
		id = id,
		email = session.email:lower():gsub(' ', ''),
		createdAt = ngx.time(),
		activated = false,
    city = session.city,
		validUntil = ngx.time()+5184000,
		activationTime = ngx.time() + 1800,
	}
	return newSession
end


function api:ValidateSession(accountID, sessionID)
	if not accountID then
		return nil, 'no account id!'
	end
	if not sessionID then
		return nil, 'no sessionID!'
	end

	local account = self.userRead:GetAccount(accountID)
  if not account then
    return nil, 'account not found'
  end

	local session = account.sessions[sessionID]
	if not session then
		return nil, 'session not found'
	end

	if not session.activated then
		return nil, 'session not validated yet'
	end

	if session.validUntil < ngx.time() then
		return nil, 'session has expired'
	end
	if session.killed then
		return nil, 'session has been killed'
	end

  sessionLastSeenDict:set(accountID..':'..sessionID, ngx.time())

	return account

end

function api:RegisterAccount(session, confirmURL)

	session = self:SanitiseSession(session)
	session.confirmURL = confirmURL
	local emailLib = require 'email'
	assert_error(emailLib:IsValidEmail(session.email))

	return self.redisWrite:QueueJob('registeraccount',session)
end




function api:ConfirmLogin(_, key)

	local sessionID, accountID = key:match('(.+)%-(%w+)')
	if not key then
		return nil, 'bad key'
	end
	local account = self.userRead:GetAccount(accountID)

	local accountSession = account.sessions[sessionID]
	if not accountSession then
    for k,v in pairs(account.sessions) do
      if not v.killed then
        print(k, to_json(v))
      end
    end
		return nil, 'bad session: '..sessionID
	end


	if accountSession.activated then
		return nil, 'invalid session'
	end
	if accountSession.validUntil < ngx.time() then
		print('expired session')
		return nil, 'expired'
	end

	if accountSession.activationTime < ngx.time() then
		print('expired login time ')
	end

	-- maybe check useragent/ip?

	accountSession.lastSeen = ngx.time()
	accountSession.activated = true
	account.lastSeen = ngx.time()
	account.active = true
	self.userWrite:CreateAccount(account)
	self:InvalidateKey('account', account.id)

  self.userWrite:IncrementAccountStat(account.id, 'logins', 1)

	return account, accountSession.id

end


function api:KillSession(accountID, sessionID)
	local account = cache:GetAccount(accountID)
	if not account then
		return nil, 'no account'
	end

	local session = account.sessions[sessionID]
	if not session then
		return nil, 'no session'
	end

	session.killed = true
  -- purge from cache
  self:InvalidateKey('account', account.id)

  self.userWrite:CreateAccount(account)

	return self:InvalidateKey('account', account.id)

end


return api
