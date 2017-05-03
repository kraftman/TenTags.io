
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

function m:Register(app)
  app:match('adminpanel','/admin',respond_to({GET = self.ViewSettings}))
  app:get('ele', '/ele', SearchTitle)
  app:get('stat', '/admin/stats', Stat)
end

return m
