
local util = {}

util.locks = ngx.shared.locks



local filterStyles = {
  default = 'views.st.postelement',
  minimal = 'views.st.postelement-min',
  HN = 'views.st.postelement-HN',
  full = 'views.st.postelement-full',
  filtta = 'views.st.postelement-filtta'
}

util.filterStyles = filterStyles

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

function util:RemLock(key)
  self.locks:delete(key)
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



 function util.TagColor(_,score)
  local offset = 100
  local r = offset+ math.floor((1 - score)*(255-offset))
  local g = offset+ math.floor(score*(255-offset))
  local b = 100
  return 'style="background-color: rgb('..r..','..g..','..b..')"'
end

function util.GetStyleSelected(self, styleName)

  if not self.userInfo then
    return ''
  end

  local filterName = self.thisfilter and self.thisfilter.name or 'frontPage'

  if self.userInfo['filterStyle:'..filterName] and self.userInfo['filterStyle:'..filterName] == styleName then
    return 'selected="selected"'
  else
    return ''
  end

end

function util.UserHasFilter(self, filterID)
  if not self.session.userID then
    return false
  end
  for k,v in pairs(self.userFilters) do
    if v.id == filterID then
      return true
    end
  end
  return false

end

function util.CalculateColor(name)
  local colors = { '#ffcccc', '#ccddff', '#ccffcc', '#ffccf2','lightpink','lightblue','lightyellow','lightgreen','lightred'};
  local sum = 0

  for i = 1, #name do
    sum = sum + (name:byte(i))
  end

  sum = sum % #colors + 1

  return 'style="background: '..colors[sum]..';"'

end


function util.GetFilterTemplate(self)

  local filterStyle = 'default'
  local filterName = self.thisfilter and self.thisfilter.name or 'frontPage'
  if self.session.userID then
    self.userInfo = self.userInfo or userAPI:GetUser(self.session.userID)


    if self.userInfo then
      --print('getting filter style for name: '..filterName,', ', self.userInfo['filterStyle:'..filterName])
      filterStyle = self.userInfo['filterStyle:'..filterName] or 'default'
    end
  else
    filterStyle = 'default'
  end

  if not filterStyles[filterStyle] then
    print('filter style not found: ',filterStyle)
    return filterStyles.default
  end

  return filterStyles[filterStyle]
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
