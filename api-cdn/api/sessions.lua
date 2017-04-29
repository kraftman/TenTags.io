
local cache = require 'api.cache'
local util = require 'api.util'
local uuid = require 'lib.uuid'
local worker = require 'api.worker'

local api = {}


function api:GetHash(values)
  local str = require 'resty.string'
  local resty_sha1 = require 'resty.sha1'
  local sha1 = resty_sha1:new()

  local ok, err = sha1:update(values)

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

	local newSession = {
		ip = session.ip,
		userAgent = session.userAgent,
		id = self:GetHash(ngx.time()..session.email..session.ip),
		email = session.email:lower(),
		createdAt = ngx.time(),
		activated = false,
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

	local account = cache:GetAccount(accountID)
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

	session.lastSeen = ngx.time()

	return account

end



function api:RegisterAccount(session, confirmURL)
	-- TODO rate limit
	session = self:SanitiseSession(session)
	session.confirmURL = confirmURL
	local emailLib = require 'email'
	local ok, err = emailLib:IsValidEmail(session.email)
	if not ok then
		ngx.log(ngx.ERR, 'invalid email: ',session.email, ' ',err)
		return false, 'Email provided is invalid'
	end

	session = to_json(session)
	print(session)
	ok, err = worker:RegisterAccount(session)
	return ok, err
end




function api:ConfirmLogin(userSession, key)

	local sessionID, accountID = key:match('(.+)%-(%w+)')
	if not key then
		return nil, 'bad key'
	end
	local account = cache:GetAccount(accountID)
	if not account then
		return nil, 'no account'
	end

	local accountSession = account.sessions[sessionID]
	if not accountSession then
		return nil, 'bad session'
	end


	if accountSession.activated then
		--return nil, 'invalid session'
	end
	if accountSession.validUntil < ngx.time() then
		print('expired session')
		--return nil, 'expired'
	end

	if accountSession.activationTime < ngx.time() then
		print('expired login time ')
	end

	-- maybe check useragent/ip?

	accountSession.lastSeen = ngx.time()
	accountSession.activated = true
	account.lastSeen = ngx.time()
	account.active = true
	worker:UpdateAccount(account)

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
	local ok, err = worker:KillSession(account)
	return ok, err

end


return api
