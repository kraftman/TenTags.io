
local m = {}

local respond_to = (require 'lapis.application').respond_to

local http = require 'lib.http'
local adminAPI = require 'api.admin'
local imageAPI = require 'api.images'


local httpc = http.new()

function m.ViewSettings(request)
  if not request.account then
    return 'you must be logged in to access this'
  end
  if request.account.role ~= 'Admin' then
    return 'you suck go away'
  end
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


end

local function SearchTitle(request)
  local search = 'testing'
  local path = "http://elasticsearch1:9200"..'/_search'
  local res, err = httpc:request_uri(path, {
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
      })
  for k,v in pairs(from_json(res.body)) do
    ngx.say(k, ' ' , to_json(v),'</br>')
  end
end


local function Stat(request)
  if not request.account then
    return 'you must be logged in to access this'
  end
  if request.account.role ~= 'Admin' then
    return 'you suck go away'
  end

  local startAt = ngx.time() - 100000
  local endAt = ngx.time()

  local ok, err = adminAPI:GetBacklogStats('ReIndexPost:30', startAt, endAt)
  if not ok then
    return 'error: ',err
  end
  print('thiss ',#ok)
  request.stats = ok

  return {render = 'stats.view'}
end

local function SiteStats(request)

    if not request.account then
      return 'you must be logged in to access this'
    end
    if request.account.role ~= 'Admin' then
      return 'you suck go away'
    end
  local ok, err = adminAPI:GetSiteUniqueStats()
  if not ok then
    return 'error: ',err
  end

  local totalViews = adminAPI:GetSiteStats()
  request.totals = totalViews
  request.stats = ok
  return {render = 'admin.stats'}
end


local function GetScore(request)
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
end

local function GetReports(request)
  if not request.account then
    return 'you must be logged in to access this'
  end
  if request.account.role ~= 'Admin' then
    return 'you suck go away'
  end

  local ok, err = adminAPI:GetReports(request.session.userID)
  if ok then
    request.reports = ok
    return {render = 'admin.reports'}
  else
    return err
  end

end

local function GetTakedowns(request)
  if not request.account then
    return 'you must be logged in to access this'
  end
  if request.account.role ~= 'Admin' then
    return 'you suck go away'
  end

  local pendingTakeDowns, err = imageAPI:GetPendingTakedowns(request.session.userID)
  if not pendingTakeDowns then
    return 'couldnt load takedowns ', err
  end


  for k,v in pairs(pendingTakeDowns) do

    v.image = imageAPI:GetImage(v.imageID)
    if not image then
      print(to_json(v))
      print('image not found: ', v.imageID)
    end
  end

  request.takedowns = pendingTakeDowns

  return {render = 'admin.takedowns'}
end

local function ConfirmTakedown(request)
  -- remove image
  -- remvoe takedown from pendingn

  if not request.account then
    return 'you must be logged in to access this'
  end
  if request.account.role ~= 'Admin' then
    return 'you suck go away'
  end

  if not request.params.takedownID then
    return 'not found'
  end

  local ok, err = imageAPI:AcknowledgeTakedown(request.session.userID, request.params.takedownID)
  ok, err = imageAPI:BanImage(request.session.userID, request.params.takedownID)
  if ok then
    return GetTakedowns(request)
  else
    ngx.log(ngx.ERR, 'failed to process takedown: ', err)
    return 'failed'
  end
end

local function CancelTakedown(request)

  if not request.account then
    return 'you must be logged in to access this'
  end
  if request.account.role ~= 'Admin' then
    return 'you suck go away'
  end

  if not request.params.takedownID then
    print(request.params.takedownID, 'takedown id')
    return 'not found'
  end

  local ok, err = imageAPI:AcknowledgeTakedown(request.session.userID, request.params.takedownID)
  if not ok then
    return err
  end

  ok, err = imageAPI:BanImage(request.session.userID, request.session.takedownID)
  if ok then
    return GetTakedowns(request)
  else
    return 'failed:'..err
  end
  -- remove takedown from pending
end

function m:Register(app)
  app:match('adminpanel','/admin',respond_to({GET = self.ViewSettings}))
  app:get('ele', '/ele', SearchTitle)
  app:get('adminstats', '/admin/stats', SiteStats)
  app:get('score', '/admin/score/:up/:down', GetScore)
  app:get('adminreports','/admin/reports',GetReports)
  app:get('admintakedowns','/admin/takedowns',GetTakedowns)
  app:get('confirmtakedown', '/admin/takedown/:takedownID/confirm', ConfirmTakedown)
  app:get('canceltakedown', '/admin/takedown/:takedownID/cancel', CancelTakedown)
end

return m
