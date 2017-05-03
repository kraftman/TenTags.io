
local woothee = require "resty.woothee"

local stats = {}
local redisWrite = (require 'redis.db')
local pageStatLog = ngx.shared.pageStatLog

function stats:LogStats(request)
  local uniqueID = request.session.accountID or request.session.tempID
  local r = woothee.parse(ngx.var.http_user_agent)


  local stat = {
    device = r.category,
    os = r.os,
    browser = r.name,
    version = r.version,
    userID = uniqueID,
    time = ngx.now()

  }

  local rawPath = request.req.parsed_url.path
  if rawPath:find('^/p/.*') then
    self:ProcessPostPath(stat, uniqueID, rawPath)
  elseif rawPath:find('^/f/*') then
    self:ProcessFilterPath(request, rawPath)
  elseif rawPath:find('^/api') or rawPath:find('^/static') then
    return
  end
  print('============ ',rawPath, ' ================ ')

  local success, err, forcible = pageStatLog:set(stat.time..':'..stat.userID, to_json(stat))
  if not success then
    if forcible then
      ngx.log(ngx.ERR, 'pageStatLog is full! stats are being lost')
    else
      ngx.log(ngx.ERR, 'error storing stats: ', err)
    end
  end


  -- per post:
  -- total views
  -- unique views

  -- per filter
  -- total views
  -- unique views
  -- category
  -- os

  -- log unique views for category, device type, version
end

function stats:ProcessPostPath(stat, path)
  stat.statType = 'PostView'
  stat.postID = path:match('^/p/(%w+)')
end

function stats:ProcessFilterPath(request, path)

end

return stats
