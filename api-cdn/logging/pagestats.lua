
local woothee = require "resty.woothee"

local stats = {}
local pageStatLog = ngx.shared.pageStatLog
local to_json = (require 'lapis.util').to_json

function stats:Run()
  local uniqueID = ngx.ctx.userID
  local r = woothee.parse(ngx.var.http_user_agent)
  if r.category == 'crawler' or r.category == 'UNKNOWN' then
    return
  end


  local stat = {
    device = r.category,
    os = r.os,
    browser = r.name,
    version = r.version,
    userID = uniqueID,
    time = ngx.now()

  }

  local rawPath = ngx.var.uri

  if rawPath:find('^/p/.*') then
    self:ProcessPostPath(stat, rawPath)
  elseif rawPath:find('^/f/.*') then
    self:ProcessFilterPath(stat,rawPath)
  elseif rawPath:find('^/api') or rawPath:find('^/static') then
    return
  end

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

function stats:ProcessFilterPath(stat, path)
  stat.statType = 'FilterView'
  stat.filterName = path:match('^/f/(%w+)')
end

return stats
