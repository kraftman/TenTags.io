
local m = {}

local respond_to = (require 'lapis.application').respond_to

local http = require 'lib.http'
local adminAPI = require 'api.admin'


local httpc = http.new()

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
  local ok, err = adminAPI:GetSiteUniqueStats()
  if not ok then
    return 'error: ',err
  end

  local totalViews = adminAPI:GetSiteStats()
  request.totals = totalViews
  request.stats = ok
  return {render = 'stats.view'}
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
function m:Register(app)
  app:match('adminpanel','/admin',respond_to({GET = self.ViewSettings}))
  app:get('ele', '/ele', SearchTitle)
  app:get('stat', '/admin/stats', SiteStats)
  app:get('score', '/admin/score/:up/:down', GetScore)
end

return m
