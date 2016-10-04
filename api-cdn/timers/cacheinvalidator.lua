
local CONFIG_CHECK_INTERVAL = 10

local config = {}
config.__index = config
config.http = require 'lib.http'
config.cjson = require 'cjson'

local redisRead = require 'api.redisread'
local redisWrite = require 'api.rediswrite'
local commentWrite = require 'api.commentwrite'
local cache = require 'api.cache'
local tinsert = table.insert
local TAG_BOUNDARY = 0.15
local to_json = (require 'lapis.util').to_json
local SEED = 1

local SPECIAL_TAGS = {
	nsfw = 'nsfw'
}

function config:New(util)
  local c = setmetatable({},self)
  c.util = util
  c.lastUpdate = ngx.now()*1000

  return c
end

function config.Run(_,self)
  local ok, err = ngx.timer.at(CONFIG_CHECK_INTERVAL, self.Run, self)
  if not ok then
    if not err:find('process exiting') then
      ngx.log(ngx.ERR, 'WARNING: unable to reschedule postupdater: '..err)
    end
  end

  -- no need to lock since we should be grabbing a different one each time anyway
  self:InvalidateCache()

end

function config:InvalidateCache()
  -- we want this to run on all workers so dont use locks

  local timeNow = ngx.now()*1000 --milliseconds

  local ok, err = redisRead:GetInvalidationRequests(self.lastUpdate, timeNow)
  if not ok then
    return
  end
  for k,v in pairs(ok) do
    v = from_json(v)
    cache:PurgeKey(v)
  end

  self.lastUpdate = timeNow

end

return config
