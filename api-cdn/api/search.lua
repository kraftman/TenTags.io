

local app_helpers = require("lapis.application")
local capture_errors, assert_error = app_helpers.capture_errors, app_helpers.assert_error


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

  if queryString:find('^http') then
    ok = cache:SearchURL(queryString)
    ok = from_json(ok)
    return ok

  else
    ok, err = cache:SearchPost(queryString)
  end

  return ok, err
end

return api
