
local CONFIG_CHECK_INTERVAL = 5

local config = {}
config.__index = config
config.http = require 'lib.http'
config.cjson = require 'cjson'
local from_json = (require 'lapis.util').from_json
local pageStatLog = ngx.shared.pageStatLog

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
  self:GetPageStats()


end


function config:GetPageStats()
  local ok, err = self.util:GetLock('UpdateStats', 5)
  if not ok then
    return
  end

  local ok, err, stat
  local keys = pageStatLog:get_keys()
  for id,key in pairs(keys) do
    stat, err = pageStatLog:get(key)
    if not stat then
      return
    end
    stat = from_json(stat)
    self:ProcessAllViews(stat)
    if stat.statType == 'PostView' then
      ok, err = self:ProcessPostView(stat)
    elseif stat.statType == 'FilterView' then
      ok, err = self:ProcessFilterView(stat)
    end
    pageStatLog:delete(key)
  end

  --self.util:RemLock('UpdateStats')
end

function config:ProcessAllViews(stat)
  -- log unique views for each category
  local cat = { 'device', 'os', 'browser'}

  local key, ok, err
  redisWrite:IncrementSiteStat('views', 1)

  for _,category in pairs(cat) do
    key = 'sitestat:'..category
    ok, err = redisWrite:LogUniqueSiteView(key, stat.time, stat.userID, stat[category])
    if not ok then
      ngx.log(ngx.ERR, 'unable to add stats: ', err)
    end

  end

end

function config:ProcessFilterView(stat)
  print('porcessing filter ')
  if not stat.filterName or #stat.filterName < 3 then
    return true
  end
  local filterID = redisRead:GetFilterID(stat.filterName)
  if not filterID then
    print('couldnt find filter: ', stat.filterName)
    return nil
  end


  local ok, err = redisWrite:LogFilterView(filterID, stat.time, stat.userID)

  if not ok then
    ngx.log(ngx.err, 'unable to log filter view: ', err)
  end

  return true

end

function config:ProcessPostView(stat)
  if not stat.postID or #stat.postID < 5 then
    return true
  end
  if #stat.postID < 30 then
    stat.postID = redisRead:ConvertShortURL(stat.postID)
  end
  local post = redisRead:GetPost(stat.postID)
  if not post then
    print('couldnt find post: ', stat.postID)
    return true
  end

  local ok, err = redisWrite:IncrementPostStat(stat.postID, 'views', 1)
  if not ok then
    ngx.log(ngx.ERR, 'unable to update post view count ',err)
  end

  --ok, err = redisWrite:InvalidateKey('post', stat.postID)

  ok, err = redisWrite:AddUniquePostView(stat.postID, stat.userID)
  if not ok then
    ngx.log(ngx.ERR, 'unable to log unique post view: ', err)
    return nil
  end

  return true
end


function config:GetStats()
  -- check the backlog for each QueueJob
  -- add it to a sorted setmetatable


  local queues = {
    'CheckReposts',
    'CreatePost',
    'votepost',
    'UpdatePostFilters',
    'AddPostShortURL',
    'ReIndexPost'
  }

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
