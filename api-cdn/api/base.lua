

local trim = (require 'lapis.util').trim
local rateDict = ngx.shared.ratelimit
local cache = require 'api.cache'
local TAG_BOUNDARY = 0.15

local M = {}
local db = require 'redis.db'

for k,v in pairs(db) do
	M[k] = v
end

function M:SanitiseHTML(str)
	return str
	-- local html = {
	-- 	["<"] = "&lt;",
	-- 	--[">"] = "&gt;",
	-- 	["&"] = "&amp;",
	-- }
	-- return string.gsub(tostring(str), "[<>&]", function(char)
	-- 	return html[char] or char
	-- end)
	--return web_sanitize.sanitize_html(str)
end

function M:InvalidateKey(key, id)
	cache:PurgeKey({keyType = key, id = id})
	local ok, err = self.redisWrite:InvalidateKey(key,id)
	return ok, err
end



function M:GetDomain(url)
  return url:match('^%w+://([^/]+)')
end


function M:GetScore(up,down)
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

function M:SanitiseUserInput(msg, length)
	if type(msg) ~= 'string' then
		--ngx.log(ngx.ERR, 'string expected, got: ',type(msg))
		return ''
	end
	msg = trim(msg)

	if msg == '' then
		ngx.log(ngx.ERR, 'string is blank')
		return ''
	end

	msg = self:SanitiseHTML(msg)
	if not length then
		return msg
	end

	return msg:sub(1, length)

end


function M:RateLimit(action, userID, limit, duration)

	local DISABLE_RATELIMIT = os.getenv('DISABLE_RATELIMIT')

	if DISABLE_RATELIMIT == 'true' then
		return true
	end

	if not userID then
		return nil, 'you must be logged in to do that'
	end
	local key = action..userID

	local ok, err = rateDict:get(key)
	if err then
		ngx.log(ngx.ERR, 'error getting rate limit key ',key)
	end

	if not ok then
		rateDict:set(key, 0, duration)
	end

	rateDict:incr(key,1)

	if not ok then
		return true
	end

	if ok < limit then
		return ok
	else
		return nil, 429
	end

end


function M.AverageTagScore(filterrequiredTagNames,postTags)

	local score = 0
	local count = 0

  for _,filtertagName in pairs(filterrequiredTagNames) do
    for _,postTag in pairs(postTags) do
      if filtertagName == postTag.name then
				if (not postTag.name:find('^meta:')) and
					(not postTag.name:find('^source:')) and
					postTag.score > TAG_BOUNDARY then
	        	score = score + postTag.score
						count = count + 1
				end
      end
    end
  end

	if count == 0 then
		return 0
	end

	return score / count
end

M.__index = M


return M
