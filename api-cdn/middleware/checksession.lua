

local M = {}

local sessionAPI = require 'api.sessions'
local userAPI = require 'api.users'
local csrf = require("lapis.csrf")

local uuid = require 'lib.uuid'


local filterStyles = {
  default = 'views.st.postelement',
  minimal = 'views.st.postelement-min',
  HN = 'views.st.postelement-HN',
  full = 'views.st.postelement-full',
  filtta = 'views.st.postelement-filtta'
}



local function RemoveSession(self)
  self.session.accountID = nil
  self.session.userID = nil
  self.session.sessionID = nil
  self.session.username = nil
end


function M:ValidateSession(self)
  if self.session.accountID then
    local account,err = sessionAPI:ValidateSession(self.session.accountID, self.session.sessionID)
    if account then
      self.account = account
      return
    end

    print('invalid session: ',err)
    RemoveSession(self)
    return {redirect_to = self:url_for('home')}

  end
  if self.session.username or self.session.userID then
    RemoveSession()
  end
end


function M:LoadUser(self)
  if self.session.userID then
    self.tempID = nil
    self.userInfo = userAPI:GetUser(self.session.userID)
  elseif not self.session.accountID then
    self.session.tempID = self.session.tempID or uuid:generate_random()
  end
  ngx.ctx.userID = self.session.userID or self.session.tempID
end

function M:Run(request)
  request:ValidateSession()
  self:LoadUser()


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
