


local cache = require 'api.cache'
local base = require 'api.base'
local api = setmetatable({}, base)
local from_json = (require 'lapis.util').from_json

-- need to check redis for results,
-- otherwise cache them (in redis)

function api:SearchPost(queryString)

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
