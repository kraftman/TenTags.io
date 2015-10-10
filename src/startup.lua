local worker = {}
worker.__index = worker

local RECUR_INTERVAL = 10

function worker:New()
  local w = setmetatable({}, self)

  w.rediswrite = require 'api.rediswrite'
  w.redisread = require 'api.redisread'
  w.cjson = require 'cjson'
  w.userWrite = require 'api.userwrite'

  -- shared dicts
  w.locks = ngx.shared.locks
  w.scripts = ngx.shared.scripts
  w.userUpdateDict = ngx.shared.userupdates
  w.userSessionSeenDict = ngx.shared.usersessionseen

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

  self:FlushUserSeen()

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

function worker:FlushUserSeen()
  if not self:GetLock('l:FlushUsers',10) then
    return
  end
  ngx.log(ngx.ERR, 'flushing user scripts')

  local userIDs = self.userUpdateDict:get_keys(1000)
  local sessionSeenPosts
  for k,userID in pairs(userIDs) do
    sessionSeenPosts = self.userSessionSeenDict:get(userID)
    sessionSeenPosts = self.cjson.decode(sessionSeenPosts)

    local ok = self.userWrite:AddSeenPosts(userID,sessionSeenPosts)
    if ok then
      self.userSessionSeenDict:delete(userID)
      self.userUpdateDict:delete(userID)
    end
  end
end

function worker:AddRedisScripts()
  -- add the script to redis
  -- add the sha of the script to shdict
  local addKey = require 'redisscripts.addkey'

  local addSHA = self.rediswrite:LoadScript(addKey:GetScript())

  local checkKey = require 'redisscripts.checkkey'

  local checkSHA = self.rediswrite:LoadScript(checkKey:GetScript())

  ngx.log(ngx.ERR, 'set script with sha1:',checkSHA)
  --[[
  local res = self.redisread:CheckKey(checkSHA,addSHA)
  --]]

end


return worker
