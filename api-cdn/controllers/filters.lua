

local M = {}

local api = require 'api.api'


local util = require("lapis.util")
local from_json = util.from_json
local to_json = util.to_json
local respond_to = (require 'lapis.application').respond_to


local function ToggleDefault(self)
  if not self.session.userID then
    return { redirect_to = self:url_for("login") }
  end

  if self.params.setdefault == 'true' then
    print('this')
    return api:SubscribeToFilter(self.session.userID, 'default',self.params.filterID)
  elseif self.params.setdefault == 'false' then
    return api:UnsubscribeFromFilter(self.session.userID,'default',self.params.filterID)
  end

  if self.params.subscribe == 'true' then
    return api:SubscribeToFilter(self.session.userID, self.session.userID,self.params.filterID)
  elseif self.params.setdefault == 'false' then
    return api:UnsubscribeFromFilter(self.session.userID, self.session.userID,self.params.filterID)
  end
end

local function NewFilter(self)

  if self.params.setdefault or self.params.subscribe then
    return ToggleDefault(self)
  end


  local requiredTags = from_json(self.params.requiredTags)
  local bannedTags = from_json(self.params.bannedTags)

  local info ={
    title = self.params.title,
    name= self.params.label:gsub(' ','') ,
    description = self.params.description,
    createdAt = ngx.time(),
    createdBy = self.session.userID,
    ownerID = self.session.userID
  }

  info.bannedTags = bannedTags
  info.requiredTags = requiredTags

  local ok, err = api:CreateFilter(self.session.userID, info)
  if ok then
    print('thisssss')
    return { json = ok }
  else
    ngx.log(ngx.ERR, 'error creating filter: ',err)
    print('tairesnti')
    return {}
  end
end


local function CreateFilter(self)
  if not self.session.userID then
    return { redirect_to = self:url_for("login") }
  end
  self.tags = api:GetAllTags()
  return {render = 'filter.create'}
end


local function DisplayFilter(self)

  -- does the filter exist? if not then lets make it
  local filter = api:GetFilterByName(self.params.filterlabel)

  if not filter then
    return CreateFilter(self)
  end

  for _,v in pairs(filter.mods) do
    local user = api:GetUserInfo(v.id)
    print(to_json(user))
    v.username = user.username
  end

  filter.ownerName = api:GetUserInfo(filter.ownerID or filter.createdBy).username

  self.thisfilter = filter
  print('added filter')

  self.posts = api:GetFilterPosts(filter)
  -- also load the list of mods
  -- check if the current user is on the list of mods
  -- display settings if they are

  return {render = 'filter.view'}

end

local function LoadAllFilters(self)
  local user = api:GetUserInfo(self.session.userID)
  if user and user.role == 'Admin' then
    self.isAdmin = true
  end

  --TODO: also get all user filters
  -- so we can change 'subscribe'  to 'unsubscribe'

  self.filters = api:GetFiltersBySubs()
  --print(to_json(self.filters))

  return {render = 'filter.all'}
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
  local ok, err = api:FilterBanUser(self.session.userID, filter.id, banInfo)
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
  local ok, err = api:FilterBanDomain(self.session.userID,filter.id, banInfo)
  if ok then
    return 'success'
  else
    return 'fail: ',err
  end
end

local function UpdateFilterTags(self,filter)
  print(self.params.requiredTags)
  local requiredTags = from_json(self.params.requiredTags)
  local bannedTags = from_json(self.params.bannedTags)
  local userID = self.session.userID


  local ok, err = api:UpdateFilterTags(userID, filter.id, requiredTags, bannedTags)
  if ok then
    return 'ok'
  else
    return 'not ok, ',err
  end
end

local function AddMod(self, filter)
  local modName = self.params.addmod
  local ok, err = api:AddMod(self.session.userID, filter.id, modName)
  if ok then
    return 'success'
  else
    return 'fail: ',err
  end
end

local function DelMod(self, filter)
  local modID = self.params.delmod
  local ok, err = api:DelMod(self.session.userID, filter.id, modID)
  if ok then
    return 'success'
  else
    return 'fail: ',err
  end
end

local function UpdateTitle(self, filter)
  local title = self.params.filtertitle

  local description = self.params.filterdescription

  local ok, err = api:UpdateFilterDescription(self.session.userID, filter.id,description)
  if not ok then
    return 'failed to update description: ',err
  end

  ok, err = api:UpdateFilterTitle(self.session.userID, filter.id, title)
  if not ok then
    return 'failed to update title: ',err
  else
    return 'success'
  end

end


local function UpdateFilter(self)
  local filter = api:GetFilterByName(self.params.filterlabel)
  if not filter then
    return CreateFilter(self)
  end
  self.selectedFilter = filter

  if self.params.filtertitle then
    return UpdateTitle(self, filter)
  end

  if self.params.banuser then
     return BanUser(self, filter)
  end

  if self.params.banDomain then
    ngx.log(ngx.ERR, 'banning domain: ')
     return BanDomain(self,filter)
  end

  if self.params.requiredTags then
     return UpdateFilterTags(self,filter)
  end

  if self.params.addmod then
    return AddMod(self, filter)
  end

  if self.params.delmod then
    return DelMod(self, filter)
  end

  return 'not found'
end



local function ViewFilterSettings(self)

  local filter = api:GetFilterByName(self.params.filterlabel)
  if not filter then
    ngx.log(ngx.ERR, 'no filter label found!')
    return 'error!'
  end
  print(to_json(filter))
  local user = api:GetUserInfo(self.session.userID)

  if user.role ~= 'Admin' then
    if filter.ownerID ~= self.session.userID then
      local found = nil
      for _,mod in pairs(filter.mods) do
        if mod.id == user.id then
          found = true
          break
        end
      end
      if not found then
        return 'Zutritt verboten!'
      end
    end
  end

  self.tags = api:GetAllTags()

  -- get key indexed tags
  self.requiredTagKeys = {}
  for k, v in pairs(filter.requiredTags) do
    self.requiredTagKeys[v] = true
  end
  print(to_json(self.requiredTagKeys))

  self.bannedTagKeys = {}
  for k,v in pairs(filter.bannedTags) do
    self.bannedTagKeys[v] = true
  end

  -- add usernames to list of banned users
  self.bannedUsernames = {}
  local userInfo
  for _,v in pairs(filter.bannedUsers) do
    userInfo= api:GetUserInfo(v.userID)
    self.bannedUsernames[v.userID] = userInfo.username
  end

  for _,v in pairs(filter.mods) do
    local user = api:GetUserInfo(v.id)
    print(to_json(user))
    v.username = user.username
  end


  self.selectedFilter = filter
  return {render = 'filter.edit'}
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

  local ok, err = api:FilterUnbanDomain(self.session.userID, filter.id, self.params.domainName)
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
