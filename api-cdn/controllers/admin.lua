--local respond_to = (require 'lapis.application').respond_to

local http = require 'lib.http'
local adminAPI = require 'api.admin'
local imageAPI = require 'api.images'

local app = require 'app'
local app_helpers = require("lapis.application")
local capture_errors, assert_error = app_helpers.capture_errors, app_helpers.assert_error
local yield_error = app_helpers.yield_error
local to_json = (require 'lapis.util').to_json
local from_json = (require 'lapis.util').from_json
local util = require 'util'

local httpc = http.new()

app:get('admin.view','/admin',capture_errors(function(request)

  local newUsers = adminAPI:GetNewUsers(request.session.userID) or {}
  request.newUsers = {}
  local accountID, email
  for v,date in pairs(newUsers) do
    accountID, email = v:match("(%w+):(.+)")
    table.insert(request.newUsers,{
      id = accountID,
      email = email,

      date = os.date('%x %X',tonumber(date))
    })
  end
  return {render = 'admin.view'}

end))

app:get('ele', '/ele', capture_errors(function()
  local search = 'testing'
  local path = "http://elasticsearch1:9200"..'/_search'
  local res = assert(httpc:request_uri(path, {
        method = "GET",
        body = to_json({
          query = {
            match = {
              title = search
            }
          }
        }),
        headers = {
          ["Content-Type"] = "application/json",
        }
      }))

  for k,v in pairs(from_json(res.body)) do
    ngx.say(k, ' ' , to_json(v),'</br>')
  end
end))

app:get('admin.stats', '/admin/stats', capture_errors({
  on_error = util.HandleError,
  function(request)

    request.totals = assert_error(adminAPI:GetSiteStats())
    request.stats = assert_error(adminAPI:GetSiteUniqueStats())

    return {render = true}
  end
}))

app:get('score', '/admin/score/:up/:down', capture_errors(function(request)
  --http://julesjacobs.github.io/2015/08/17/bayesian-scoring-of-ratings.html
  --http://www.evanmiller.org/bayesian-average-ratings.html

  local up = request.params.up or 0
  local down = request.params.down or 0
  if up == 0 then
      return -down
  end
  local n = up + down
  local z = 1.64485 --1.0 = 85%, 1.6 = 95%
  local phat = up / n
  return ''..(phat+z*z/(2*n)-z*math.sqrt((phat*(1-phat)+z*z/(4*n))/n))/(1+z*z/n)
end))

app:get('admin.reports','/admin/reports',capture_errors({
  on_error = util.HandleError,
  function(request)

    request.reports = assert_error(adminAPI:GetReports(request.session.userID))
    return {render = 'admin.reports'}

  end
}))

app:get('admin.takedowns','/admin/takedowns',capture_errors({
  on_error = util.HandleError,
  function(request)

    request.takedowns = assert_error(imageAPI:GetPendingTakedowns(request.session.userID))
    for _,v in pairs(request.takedowns) do

      v.image = imageAPI:GetImage(v.imageID)
      if not v.image then
        print(to_json(v))
        print('image not found: ', v.imageID)
      end
    end

    return {render = true}
  end
}))

app:get('confirmtakedown', '/admin/takedown/:takedownID/confirm', capture_errors({
  on_error = util.HandleError,
  function(request)
    -- remove image
    -- remvoe takedown from pendingn

    if not request.params.takedownID then
      return 'not found'
    end

    assert_error(imageAPI:AcknowledgeTakedown(request.session.userID, request.params.takedownID))
    assert_error(imageAPI:BanImage(request.session.userID, request.params.takedownID))
    return {redirect_to = request.url_for( 'admin.takedowns')}

  end
}))

app:get('canceltakedown', '/admin/takedown/:takedownID/cancel', capture_errors(function(request)

  if not request.params.takedownID then
    ngx.log(ngx.ERR, request.params.takedownID, 'takedown id')
    yield_error('takedown not found')
  end

  assert_error(imageAPI:AcknowledgeTakedown(request.session.userID, request.params.takedownID))

  assert_error(imageAPI:BanImage(request.session.userID, request.session.takedownID))

  return {redirect_to = request.url_for( 'admin.takedowns')}

end))
