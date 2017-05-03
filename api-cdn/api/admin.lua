

local redisRead = (require 'redis.db').redisRead

local M = {}

function M:GetBacklogStats(jobName, startAt, endAt)
  local ok, err = self.redisRead:GetBacklogStats(jobName, startAt, endAt)
  if not ok then
    ngx.log(ngx.ERR, 'error getting stat backlog: ', err)
    return nil, 'couldnt get stats'
  end
  return ok
end

return M
