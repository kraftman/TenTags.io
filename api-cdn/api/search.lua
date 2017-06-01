

local cache = require 'api.cache'
local base = require 'api.base'
local api = setmetatable({}, base)

-- need to check redis for results,
-- otherwise cache them (in redis)

function api:SearchPost(queryString)
  -- need to ratelimit on id or only allow logged in users to search
	-- local ok, err = util.RateLimit('SearchPost:', userID, 5, 10)
	-- if not ok then
	-- 	return ok, err
	-- end
  if #queryString < 2 then
    return nil, 'search is too short'
  elseif #queryString > 200 then
    return nil, 'search is too long'
  end
  local ok, err

  if not queryString:find('^http') then
    ok, err = cache:SearchPost(queryString)
    if not ok then
      ngx.log(ngx.ERR, 'failed to search posts: ', err)
      return nil, 'failed to search posts'
    end
  end


  if ok.hits.total < 1 then
    ok, err = cache:SearchURL(queryString)
    if not ok then
      ngx.log(ngx.ERR, 'failed to search posts: ', err)
      return nil, 'failed to search posts'
    end
    ok = from_json(ok)
    return ok
  end

  return ok, err

end

return api
