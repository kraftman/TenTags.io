local worker = {}
worker.__index = worker

local RECUR_INTERVAL = 10

function worker:New()
  local w = setmetatable({}, self)

  w.rediswrite = (require 'redis.db').redisWrite
  w.redisread = (require 'redis.db').redisRead
  w.cjson = require 'cjson'
  w.userwrite = (require 'redis.db').userWrite
  w.commentwrite = (require 'redis.db').commentWrite
  w.util = require 'util'

  -- shared dicts
  w.locks = ngx.shared.locks
  w.userUpdateDict = ngx.shared.userupdates
  w.userSessionSeenDict = ngx.shared.usersessionseenpost

  w.emailer = (require 'timers.emailsender'):New(w.util)
  w.postUpdater = (require 'timers.postupdater'):New(w.util)
  w.filterUpdater = (require 'timers.filterupdater'):New(w.util)
  w.registerUser = (require 'timers.registeruser'):New(w.util)
  w.invalidateCache = (require 'timers.cacheinvalidator'):New(w.util)
  w.statcollector = (require 'timers.statcollector'):New(w.util)
  w.commentupdater = (require 'timers.commentupdater'):New(w.util)
  self.elasticDone = false

  return w
end

function worker:Run()

  local ok, err = ngx.timer.at(1, self.OnServerStart, self)
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
  -- if not self.elasticDone then
  --
  --   print('creating elastic')
  --   local ok, err = elastic:CreateIndex()
  --   print(ok, err)
  --   if ok then
  --     self.elasticDone = true
  --     print('done ============= ')
  --   end
  -- end
  self:ScheduleTimer()
  self:FlushUserSeen()
end


function worker.OnServerStart(_,self)
  self.emailer.Run(_,self.emailer)
  self.postUpdater.Run(_,self.postUpdater)
  self.filterUpdater.Run(_,self.filterUpdater)
  self.registerUser.Run(_,self.registerUser)
  self.invalidateCache.Run(_,self.invalidateCache)
  self.statcollector.Run(_,self.statcollector)
  self.commentupdater.Run(_,self.commentupdater)

  if not self.util:GetLock('l:ServerStart', 5) then
    return
  end

end


function worker:FlushUserSeen()
  if not self.util:GetLock('l:FlushUsers',10) then
    return
  end

  local userIDs = self.userUpdateDict:get_keys(1000)
  local sessionSeenPosts
  for _,userID in pairs(userIDs) do
    sessionSeenPosts = self.userSessionSeenDict:get(userID)
    sessionSeenPosts = self.cjson.decode(sessionSeenPosts)

    local ok = self.userwrite:AddSeenPosts(userID,sessionSeenPosts)
    if ok then
      self.userSessionSeenDict:delete(userID)
      self.userUpdateDict:delete(userID)
    end
  end
end

return worker
