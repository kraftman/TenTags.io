

local m = {}


local respond_to = (require 'lapis.application').respond_to
local api = require 'api.api'
local tinsert = table.insert

local function SearchFilter(self)
  if not self.params.searchString then
    return {json = {error = 'no searchString provided', data = {}}}
  end
  if not self.session.userID then
    return {json = {error = 'you must be logged in!', data = {}}}
  end
  local ok, err = api:SearchFilters(self.session.userID, self.params.searchString)
  print(to_json(ok))
  if ok then
    return {json ={error = {}, data = ok} }
  else
    return {json = {error = {err}, data = {}}}
  end
end

local function GetUserFilters(self)
  local ok, err = api:GetUserFilters(self.session.userID)
  return {json = {error = {err}, data = ok or {}}}
end


function m:Register(app)
  --app:match('apilogin','/api/login',respond_to({POST = UserLogin}))
  app:match('filtersearch', '/api/filter/search/:searchString', SearchFilter)
  app:match('userfilters', '/api/user/filters', GetUserFilters)
end

return m
