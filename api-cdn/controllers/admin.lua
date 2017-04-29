

local m = {}


local respond_to = (require 'lapis.application').respond_to

local tinsert = table.insert

function m.ViewSettings(request)
  if not request.account then
    return 'you must be logged in to access this'
  end
  if request.account.role == 'Admin' then
    return {render = 'admin.view'}
  else
    return 'you suck go away'
  end

end

function m:Register(app)
  app:match('adminpanel','/admin',respond_to({GET = self.ViewSettings}))
end

return m
