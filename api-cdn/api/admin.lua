

local redisRead = require 'api.redisread'

local M = {}

function M:GetBacklogStats(jobName, startAt, endAt)
  local ok, err = redisRead:GetBacklogStats(jobName, startAt, endAt)
  if not ok then
    ngx.log(ngx.ERR, 'error getting stat backlog: ', err)
    return nil, 'couldnt get stats'
  end
  return ok
end

return M
