

local M = {}

local sessionAPI = require 'api.sessions'
local userAPI = require 'api.users'
local csrf = require("lapis.csrf")

local uuid = require 'lib.uuid'



function M:RemoveSession(request)
  request.session.accountID = nil
  request.session.userID = nil
  request.session.sessionID = nil
  request.session.username = nil
end


function M:ValidateSession(request)
  if request.session.accountID then
    local account,err = sessionAPI:ValidateSession(request.session.accountID, request.session.sessionID)
    if account then
      request.account = account
      return
    end

    self:RemoveSession(request)
    return {redirect_to = request:url_for('home')}

  elseif request.session.username or request.session.userID then
    self:RemoveSession(request)
  end
end


function M:GetHash(values)
  local str = require 'resty.string'
  local resty_sha1 = require 'resty.sha1'
  local sha1 = resty_sha1:new()

  local ok, err = sha1:update(values)

  local digest = sha1:final()

  return str.to_hex(digest)
end


function M:LoadUser(request)
  if request.session.userID then
    request.tempID = nil
    request.userInfo = userAPI:GetUser(request.session.userID)
  elseif not request.session.accountID then
    local unique = ngx.var.remote_addr..ngx.var.http_user_agent
    print('ua:', ngx.var.http_user_agent)

    request.session.tempID = request.session.tempID or self:GetHash(unique)
  end
  ngx.ctx.userID = request.session.userID or request.session.tempID
  request.cookies.cacheKey = ngx.md5(ngx.ctx.userID)
end

function M:Run(request)
  self:ValidateSession(request)
  self:LoadUser(request)


    if request.session.accountID then
      request.otherUsers = userAPI:GetAccountUsers(request.session.accountID, request.session.accountID)
    end

    if request.session.userID then
      if userAPI:UserHasAlerts(request.session.userID) then
        request.userHasAlerts = true
      end
    end

    if not request.otherUsers then
      request.otherUsers = {}
    end
    --ngx.log(ngx.ERR, to_json(user))

    request.csrf_token = csrf.generate_token(request,request.session.userID)
    request.userFilters = userAPI:GetUserFilters(request.session.userID or 'default') or {}
end
return M
