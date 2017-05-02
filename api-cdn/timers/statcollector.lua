
local CONFIG_CHECK_INTERVAL = 5

local config = {}
config.__index = config
config.http = require 'lib.http'
config.cjson = require 'cjson'

local redisRead = require 'api.redisread'
local redisWrite = require 'api.rediswrite'
local commentWrite = require 'api.commentwrite'
local commentRead = require 'api.commentread'
local commentAPI = require 'api.comments'
local userAPI = require 'api.users'
local userWrite = require 'api.userwrite'
local cache = require 'api.cache'
local tinsert = table.insert
local to_json = (require 'lapis.util').to_json
local from_json = (require 'lapis.util').from_json

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
  'CheckReposts',
  'createpost',
  'votepost',
  'UpdatePostFilters',
  'AddPostShortURL',
  'ReIndexPost'
}

function config:GetStats()
  -- check the backlog for each QueueJob
  -- add it to a sorted setmetatable
  local ok, err
  local time = ngx.time()
  for _,jobName in pairs(queues)do
    ok, err = redisRead:GetQueueSize(jobName)
    if not ok then
      ngx.log(ngx.ERR, 'unable to get size of queue: ', err)
    else
      ok, err = redisRead:LogBacklogStats(jobName,time, ok)
      print('logging stat ', ok, ' to ', jobName)
      if not ok then
        ngx.log(ngx.ERR, 'unable to write backlog stats: ',err)
      end
    end
  end
end


return config
