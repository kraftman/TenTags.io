
local CONFIG_CHECK_INTERVAL = 5

local config = {}
config.__index = config
config.http = require 'lib.http'
config.cjson = require 'cjson'

local userRead = require 'api.userread'
local userWrite = require 'api.userwrite'
local redisRead = require 'api.redisread'
local redisWrite = require 'api.rediswrite'
local commentWrite = require 'api.commentwrite'
local cache = require 'api.cache'
local tinsert = table.insert
local TAG_BOUNDARY = 0.15
local to_json = (require 'lapis.util').to_json
local from_json = (require 'lapis.util').from_json
local SEED = 1
local emailDict = ngx.shared.emailQueue
local str = require "resty.string"
local uuid = require 'lib.uuid'

local SPECIAL_TAGS = {
	nsfw = 'nsfw'
}

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

  -- no need to lock since we should be grabbing a different one each time anyway
  self:RegisterAccount()

end

function config:GetJob(jobName)
  local session = redisRead:GetOldestJob(jobName)
  if not session then
    return nil
  end
  -- TODO fix this, its not a good solution
  local ok, err = redisWrite:DeleteJob(jobName,session)

  if ok ~= 1 then
    if err then
      ngx.log(ngx.ERR, 'error deleting job: ',err)
    end
    return nil
  end

  return session
end

function config:CreateAccount(accountID, session)
  local account = {
    id = accountID,
    createdAt = session.createdAt,
    sessions = {},
    users = {},
    userCount = 0,
    active = 0,
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


function config:RegisterAccount()

  local session = self:GetJob('RegisterAccount')
  if not session then
    return
  end

  session = from_json(session)
	local emailAddr = session.email
	session.email = nil

  local accountID = self:GetHash(emailAddr)
  local account = userRead:GetAccount(accountID)
  if not account then
    account = self:CreateAccount(accountID, session)
  end
	account.id = accountID

  if not session.id then
    return
  end
	account.sessions[session.id] = session

  local ok, err = userWrite:CreateAccount(account)
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

  local ok, err, forced = emailDict:set(emailAddr, to_json(email))
  session.email = nil
  if (not ok) and err then
    ngx.log(ngx.ERR, 'unable to set emaildict: ', err)
    return nil, 'unable to send email'
  end
  if forced then
    ngx.log(ngx.ERR, 'WARNING! forced email dict! needs to be bigger!')
  end

  -- Create the Account

  return true
end

return config
