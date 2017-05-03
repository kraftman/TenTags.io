
local util = {}

util.locks = ngx.shared.locks


function util:GetLock(key, lockTime)
  local success, err = self.locks:add(key, true, lockTime)
  if not success then
    if err ~= 'exists' then
      ngx.log(ngx.ERR, 'failed to add lock key: ',err)
    end
    return nil
  end
  return true
end


function util:SplitShortURL(shortURL)
  return shortURL:sub(1,5),shortURL:sub(6,-1)
end


function util:GetScore(up,down)
	--http://julesjacobs.github.io/2015/08/17/bayesian-scoring-of-ratings.html
	--http://www.evanmiller.org/bayesian-average-ratings.html
	if up == 0 then
      return -down
  end
  local n = up + down
  local z = 1.64485 --1.0 = 85%, 1.6 = 95%
  local phat = up / n
  return (phat+z*z/(2*n)-z*math.sqrt((phat*(1-phat)+z*z/(4*n))/n))/(1+z*z/n)

end



function util:ConvertToUnique(jsonData)
  -- this also removes duplicates, using the newest only
  -- as they are already sorted old -> new by redis
  local commentVotes = {}
  local converted
  for _,v in pairs(jsonData) do

    converted = from_json(v)
    converted.json = v
		if not converted.id then
			ngx.log(ngx.ERR, 'jsonData contains no id: ',v)
		end
    commentVotes[converted.id] = converted
  end
  return commentVotes
end




--[[
function util:GetRedisConnectionFromSentinel(masterName, role)
  local redis_connector = require "resty.redis.connector"
  local rc = redis_connector.new()

  local redis, err = rc:connect{ url = "sentinel://"..masterName..":"..role, sentinels = sentinels }


  if not redis then
    ngx.log(ngx.ERR, 'error getting connection from master:', masterName, ', role: ',role, ', error: ', err)
    return nil
  else
    return redis
  end
end

function util:GetUserWriteConnection()
  return self:GetRedisConnectionFromSentinel('master-user', 'm')
end

function util:GetUserReadConnection()
  return self:GetRedisConnectionFromSentinel('master-user', 's')
end

function util:GetRedisReadConnection()
  return self:GetRedisConnectionFromSentinel('master-general', 's')
end

function util:GetRedisWriteConnection()
  return self:GetRedisConnectionFromSentinel('master-user', 'm')
end

function util:GetCommentWriteConnection()
  return self:GetRedisConnectionFromSentinel('master-user', 'm')
end

function util:GetCommentReadConnection()
  return self:GetRedisConnectionFromSentinel('master-user', 's')
end
--]]


return util
