

local M = {}

local api = require 'api.api'


local util = require("lapis.util")
local from_json = util.from_json
local to_json = util.to_json
local respond_to = (require 'lapis.application').respond_to


local function ToggleDefault(self)

  if self.params.setdefault == 'true' then
    api:SubscribeToFilter('default',self.params.filterID)
  elseif self.params.setdefault == 'false' then
    api:UnsubscribeFromFilter('default',self.params.filterID)
  end
  if self.params.subscribe == 'true' then
    api:SubscribeToFilter(self.session.userID,self.params.filterID)
  elseif self.params.setdefault == 'false' then
    api:UnsubscribeFromFilter(self.session.userID,self.params.filterID)
  end
end

local function NewFilter(self)

  if self.params.setdefault or self.params.subscribe then
    return ToggleDefault(self)
  end
  for k,v in pairs(self.req) do
    print(k,to_json(v))
  end
  print(self.session.userID)

  local requiredTags = from_json(self.params.requiredTags)
  local bannedTags = from_json(self.params.bannedTags)

  local info ={
    title = self.params.title,
    name= self.params.label ,
    description = self.params.description,
    createdAt = ngx.time(),
    createdBy = self.session.userID,
    ownerID = self.session.userID
  }

  info.bannedTags = bannedTags
  info.requiredTags = requiredTags

  local ok, err = api:CreateFilter(info)
  if ok then
    return
  else
    ngx.log(ngx.ERR, 'error creating filter: ',err)
    return {status = 500}
  end
end

local function CreateFilter(self)
  self.tags = api:GetAllTags()

  print(self.session.userID, self.session.username)

  return {render = 'createfilter'}
end

local function DisplayFilter(self)

  -- does the filter exist? if not then lets make it
  local filter = api:GetFilterByName(self.params.filterlabel)
  if not filter then
    return CreateFilter(self)
  end
  self.thisfilter = filter

  self.posts = api:GetFilterPosts(filter)
  -- also load the list of mods
  -- check if the current user is on the list of mods
  -- display settings if they are


  return {render = 'viewfilter'}

end

local function LoadAllFilters(self)

  self.filters = api:GetFiltersBySubs()
  print(to_json(self.filters))

  return {render = 'allfilters'}
end

local function BanUser(self,filter)
  local userID = api:GetUserID(self.params.banuser)
  if not userID then
    ngx.log(ngx.ERR, 'attempt to ban a non-existant user: ',self.params.banuser)
    return 'user '..self.params.banuser..' does not exist'
  end
  local banInfo = {
    userID = userID,
    banReason = self.params.banUserReason or '',
    bannedBy = self.session.userID
  }
  local ok, err = api:FilterBanUser(filter.id, banInfo)
  if ok then
    return 'success'
  else
    return 'fail: ',err
  end
end

local function BanDomain(self,filter)

  local banInfo = {
    domainName = self.params.banDomain,
    banReason = self.params.banDomainReason or '',
    bannedBy = self.session.userID
  }
  local ok, err = api:FilterBanDomain(filter.id, banInfo)
  if ok then
    return 'success'
  else
    return 'fail: ',err
  end
end

local function UpdateFilter(self)
  local filter = api:GetFilterByName(self.params.filterlabel)
  if not filter then
    return CreateFilter(self)
  end
  self.selectedFilter = filter

  if self.params.banuser then
    return BanUser(self, filter)
  end

  if self.params.banDomain then
    ngx.log(ngx.ERR, 'banning domain: ')
    return BanDomain(self,filter)
  end
  return {render = 'editfilter'}
end

local function ViewFilterSettings(self)
  local filter = api:GetFilterByName(self.params.filterlabel)
  if not filter then
    ngx.log(ngx.ERR, 'no filter label found!')
  end
  print(to_json(filter))

  self.bannedUsernames = {}
  local userInfo
  for _,v in pairs(filter.bannedUsers) do
    userInfo= api:GetUserInfo(v.userID)
    self.bannedUsernames[v.userID] = userInfo.username
  end

  self.selectedFilter = filter
  return {render = 'editfilter'}
end

local function UnbanUser(self)
  local filter = api:GetFilterByName(self.params.filterlabel)
  if not filter then
    ngx.log(ngx.ERR, 'no filter label found!')
  end

  local ok, err = api:FilterUnbanUser(filter.id, self.params.userID)
  if ok then
    return 'success'
  else
    return 'fail: ',err
  end

end

local function UnbanDomain(self)
  local filter = api:GetFilterByName(self.params.filterlabel)
  if not filter then
    ngx.log(ngx.ERR, 'no filter label found!')
  end

  local ok, err = api:FilterUnbanDomain(filter.id, self.params.domainName)
  if ok then
    return 'success'
  else
    return 'fail: ',err
  end
end

function M:Register(app)
  app:match('filter','/f/:filterlabel',respond_to({GET = DisplayFilter,POST = NewFilter}))
  app:match('newfilter','/filters/create',respond_to({GET = CreateFilter,POST = NewFilter}))
  app:match('updatefilter','/filters/:filterlabel',respond_to({GET = ViewFilterSettings,POST = UpdateFilter}))
  app:get('allfilters','/f',LoadAllFilters)
  app:get('unbanfilteruser','/filters/:filterlabel/unbanuser/:userID',UnbanUser)
  app:get('unbanfilterdomain','/filters/:filterlabel/unbandomain/:domainName',UnbanDomain)


end

return M
