local worker = {}
worker.__index = worker

local RECUR_INTERVAL = 10

function worker:New()
  local w = setmetatable({}, self)

  w.rediswrite = require 'api.rediswrite'
  w.redisread = require 'api.redisread'
  w.cjson = require 'cjson'

  -- shared dicts
  w.locks = ngx.shared.locks
  w.scripts = ngx.shared.scripts

  return w
end

function worker:Run()

  local ok, err = ngx.timer.at(0, self.OnServerStart, self)
  if not ok then
    if not err:find('process exiting') then
      ngx.log(ngx.ERR, 'initialise initman timer failed: '..err)
    end
  end

  self:ScheduleTimer()
end

function worker:ScheduleTimer()
  local ok, err = ngx.timer.at(RECUR_INTERVAL, self.ProcessRecurring,self)
  if not ok then
    if not err:find('process exiting') then
      ngx.log(ngx.ERR, 'initialise statman timer failed: '..err)
    end
  end
end


function worker.ProcessRecurring(_,self)
  self:ScheduleTimer()

  -- do recurring stuff here

end


function worker.OnServerStart(_,self)
  if not self:GetLock('l:ServerStart', 5) then
    return
  end

  self:AddRedisScripts()
end


function worker:GetLock(key, lockTime)
  local success, err = self.locks:add(key, true, lockTime)
  if not success then
    if err ~= 'exists' then
      ngx.log(ngx.ERR, 'failed to add lock key: ',err)
    end
    return nil
  end
  return true
end

function worker:AddRedisScripts()
  -- add the script to redis
  -- add the sha of the script to shdict
  local addKey = require 'redisscripts.addkey'

  local addSHA = self.rediswrite:LoadScript(addKey:GetScript())
  ngx.log(ngx.ERR, addSHA, ' ',addKey:GetSHA1())
  local ok, err = self.scripts:set('addkey',addSHA)

  local checkKey = require 'redisscripts.checkkey'

  local checkSHA = self.rediswrite:LoadScript(checkKey:GetScript())

  ok, err = self.scripts:set('checkKey',checkSHA)

  self.rediswrite:AddKey(addSHA,'baseKey','element')

  local elements = {'test','element','othertest'}

  local result = self.redisread:GetUnseenElements(checkSHA,'baseKey',elements)
  ngx.log(ngx.ERR, self.cjson.encode(result))


end


return worker
