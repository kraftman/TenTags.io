

local m = {}


local respond_to = (require 'lapis.application').respond_to
local api = require 'api.api'

local function ViewAlerts(self)
  local alerts = api:GetUserAlerts(self.session.userID)
  api:UpdateLastUserAlertCheck(self.session.userID)

  return to_json(alerts)
end

function m:Register(app)
  app:match('viewalerts','/alerts/view',respond_to({GET = ViewAlerts}))
end

return m
