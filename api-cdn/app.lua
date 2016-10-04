
--[[
  This checks the users cookies and loads some initial values that every request needs
  Then dispatches the request to the controller that can handle the request
  the controllers for the most part just do some basic checks before requesting stuff from the api
  then load the required information for the page to be rendered
--]]

local lapis = require("lapis")
local app = lapis.Application()
local api = require 'api.api'
local date = require("date")
--https://github.com/bungle/lua-resty-scrypt/issues/1
app:enable("etlua")
app.layout = require 'views.layout'
local csrf = require("lapis.csrf")

app.cookie_attributes = function(self)
  local expires = date(true):adddays(365):fmt("${http}")
  return "Expires=" .. expires .. "; Path=/; HttpOnly"
end


-- DEV ONLY
to_json = (require 'lapis.util').to_json
from_json = (require 'lapis.util').from_json

local filterStyles = {
  default = 'views.st.postelement',
  minimal = 'views.st.postelement-min',
  HN = 'views.st.postelement-HN',
  full = 'views.st.postelement-full',
  filtta = 'views.st.postelement-filtta'
}


local function GetStyleSelected(self, styleName)
  self.userInfo = self.userInfo or api:GetUser(self.session.userID)

  if not self.userInfo then
    return ''
  end

  local filterName = self.thisfilter and self.thisfilter.name or 'frontPage'

  if self.userInfo['filterStyle:'..filterName] and self.userInfo['filterStyle:'..filterName] == styleName then
    return 'selected="selected"'
  else
    return ''
  end

end

local function CalculateColor(name)
  local colors = { '#ffcccc', '#ccddff', '#ccffcc', '#ffccf2','lightpink','lightblue','lightyellow','lightgreen','lightred'};
  local sum = 0

  for i = 1, #name do
    sum = sum + (name:byte(i))
  end

  sum = sum % #colors + 1

  return 'style="background: '..colors[sum]..';"'

end

local function SignOut(self)
  -- kill the session with the api so it cant be reused
  -- delete everything in the session
  local ok, err = api:KillSession(self.session.accountID, self.session.sessionID)
  if not ok then
    print('error killing session: ',err)
  end
end

local function ValidateSession(self)
  if self.session.accountID then
    local account,err = api:ValidateSession()
    if not account then
      print('invalid session: ',err)
      self.session.accountID = nil
      self.session.userID = nil
      self.session.sessionID = nil
      return {redirect_to = self:url_for('home')}
    end

  end
end


local function GetFilterTemplate(self)

  local filterStyle = 'default'
  local filterName = self.thisfilter and self.thisfilter.name or 'frontPage'
  if self.session.userID then
    self.userInfo = self.userInfo or api:GetUser(self.session.userID)


    if self.userInfo then
      --print('getting filter style for name: '..filterName,', ', self.userInfo['filterStyle:'..filterName])
      filterStyle = self.userInfo['filterStyle:'..filterName] or 'default'
    end
  else
    filterStyle = 'default'
  end

  if not filterStyles[filterStyle] then
    print('filter style not found: ',filterStyle)
    return filterStyles.default
  end

  return filterStyles[filterStyle]
end

app:before_filter(function(self)
  --ngx.log(ngx.ERR, self.session.userID, to_json(self.session.username))

  self.enableAds = false

  ValidateSession(self)

  if self.session.accountID then
    self.otherUsers = api:GetAccountUsers(self.session.accountID, self.session.accountID)
  end

  if self.session.userID then
    if api:UserHasAlerts(self.session.userID) then
      self.userHasAlerts = true
    end
  end

  if not self.otherUsers then
    self.otherUsers = {}
  end
  --ngx.log(ngx.ERR, to_json(user))

  self.csrf_token = csrf.generate_token(self,self.session.userID)
  self.userFilters = api:GetUserFilters(self.session.userID or 'default') or {}

  self.GetFilterTemplate = GetFilterTemplate
  self.GetStyleSelected = GetStyleSelected
  self.filterStyles = filterStyles
  self.CalculateColor = CalculateColor


end)

--TODO: change to this: https://gist.github.com/leafo/92ef8250f1f61e3f45ec

require 'tags':Register(app)
require 'posts':Register(app)
require 'frontpage':Register(app)
require 'user':Register(app)
require 'settings':Register(app)
require 'messages':Register(app)
require 'filters':Register(app)
require 'comments':Register(app)
require 'alerts':Register(app)
require 'api':Register(app)
require 'auto':Register(app)

-- TESTING
require 'test.perftest':Register(app)



return app
