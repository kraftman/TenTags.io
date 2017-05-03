
local CONFIG_CHECK_INTERVAL = 5

local config = {}
config.__index = config
config.http = require 'lib.http'
config.cjson = require 'cjson'

local redisRead = (require 'redis.db').redisRead
local redisWrite = (require 'redis.db').redisWrite



function config:New(util)
  local c = setmetatable({},self)
  c.util = util
	math.randomseed(ngx.now()+ngx.worker.pid())
	math.random()

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
  self:GetStats()

end


local queues = {
  --'CheckReposts',
  'CreatePost',
  --'votepost',
  --'UpdatePostFilters',
  --'AddPostShortURL',
  --'ReIndexPost'
}

function config:GetStats()
  -- check the backlog for each QueueJob
  -- add it to a sorted setmetatable


  local ok, err

  ok, err = redisWrite:GetLock('L:GetStats',5)
  if err then
    ngx.log(ngx.ERR, 'unable to lock commentvote: ',err)
  elseif ok == ngx.null then
    return
  end

  local time = ngx.time()
  for _,jobName in pairs(queues)do


    ok, err = redisRead:GetQueueSize(jobName)
    if not ok then
      ngx.log(ngx.ERR, 'unable to get size of queue: ', err)
    elseif ok > 0 then
      self:LogBacklogStats(jobName, time, ok)
    end
  end
end

function config:LogBacklogStats(jobName, time, value)
  -- log 5 second increments for 24 hours 20,000 keys
  -- log 1 min for 1 week 20,000 keys
  -- log 5 min for 1 month 9000 keys
  local increments = {}
  increments['5'] = 86400
  increments['30'] = 604800
  increments['300'] = 2505600
  local newTime, ok, err
  for increment,timespan in pairs(increments) do
    increment = tonumber(increment)
    newTime = (time - (time % increment))

    print(jobName, ' ', increment, ' ', value)
    ok, err = redisWrite:LogBacklogStats(jobName..':'..increment, newTime, newTime..':'..value, timespan)
    if not ok then
      ngx.log(ngx.ERR, 'unable to write stats: ', err)
    end

  end
end


return config
