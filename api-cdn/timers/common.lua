

local M = {}

local db = require 'redis.db'
for k,v in pairs(db) do
  M[k] = v
end

local from_json = (require 'lapis.util').from_json

function M:ConvertToUnique(jsonData)
  -- this also removes duplicates, using the newest only
  -- as they are already sorted old -> new by redis
  local commentVotes = {}
  local converted
  for _,v in pairs(jsonData) do

    converted = from_json(v)
    converted.json = v
		if converted.id then
      commentVotes[converted.id] = converted
    else
			ngx.log(ngx.ERR, 'jsonData contains no id: ',v)
		end
  end
  return commentVotes
end

function M:ProcessJob(jobName, callback)

  local lockName = 'L:'..jobName


  local ok,err = self.redisRead:GetOldestJobs(jobName, 1000)
  if err then
    ngx.log(ngx.ERR, 'unable to get list of comment votes:' ,err)
    return
  end

  local jobs = self:ConvertToUnique(ok)

  local count = 0

  for jobID,job in pairs(jobs) do
    if (ngx.now() > self.startTime+4) then
      print(jobName, ' processed: ',count,' aborting after: ',ngx.now()-self.startTime)
      return
    end

    count = count +1

    ok, err = self.redisWrite:GetLock(lockName..jobID,10)

    if err then
      ngx.log(ngx.ERR, 'unable to lock commentvote: ',err)
    elseif ok ~= ngx.null then
      -- the bit that does stuff
      ok, err = self[callback](self,job)
      if ok then
        self.redisWrite:RemoveJob(jobName,job.json)
        -- purge the comment from the cache
        -- dont remove lock, just to limit updates a bit
      else
        ngx.log(ngx.ERR, 'unable to process ',jobName,':', err)
        self.redisWrite:RemLock(lockName..jobID)
      end
    end
  end
end

M.__index = M


return M
