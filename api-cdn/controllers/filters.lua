

local m = {}

local api = require 'api.api'


local util = require("lapis.util")
local from_json = util.from_json
local to_json = util.to_json
local respond_to = (require 'lapis.application').respond_to


function m.ToggleDefault(request)
  if not request.session.userID then
    return { render = 'pleaselogin' }
  end

  if request.params.setdefault == 'true' then
    print('this')
    return api:SubscribeToFilter(request.session.userID, 'default',request.params.filterID)
  elseif request.params.setdefault == 'false' then
    return api:UnsubscribeFromFilter(request.session.userID,'default',request.params.filterID)
  end

  if request.params.subscribe == 'true' then
    return api:SubscribeToFilter(request.session.userID, request.session.userID,request.params.filterID)
  elseif request.params.setdefault == 'false' then
    return api:UnsubscribeFromFilter(request.session.userID, request.session.userID,request.params.filterID)
  end
end

function m.NewFilter(request)

  local info ={
    title = request.params.title,
    name= request.params.filterName:gsub(' ','') ,
    description = request.params.description,
    createdAt = ngx.time(),
    createdBy = request.session.userID,
    ownerID = request.session.userID,
    bannedTagNames = {},
    requiredTagNames = {}
  }

  if to_json(request.params.requiredTagNames) ~= -1 then
    info.requiredTagNames = from_json(request.params.requiredTagNames)
  else
    for word in request.params.requiredTagNames:gmatch('%S+') do
      table.insert(info.requiredTagNames, word)
    end
  end

  if to_json(request.params.bannedTagNames) ~= -1 then
    info.bannedTagNames = from_json(request.params.bannedTagNames)
  else
    for word in request.params.bannedTagNames:gmatch('%S+') do
      table.insert(info.bannedTagNames, word)
    end
  end


  local newFilter, err = api:CreateFilter(request.session.userID, info)
  if newFilter then
    return {redirect_to = request:url_for("updatefilter",{filterlabel = newFilter.name}) }
  else
    return 'Error creating filter: '..(err or '')
  end
end


function m.CreateFilter(request)
  if not request.session.userID then
    print('no user id')
    return { render = 'pleaselogin' }
  end
  request.tags = api:GetAllTags()
  return {render = 'filter.create'}
end


function m.DisplayFilter(request)

  -- does the filter exist? if not then let them make it
  local filter = api:GetFilterByName(request.params.filterlabel)

  if not filter then
    return m.CreateFilter(request)
  end

  for _,v in pairs(filter.mods) do
    local user = api:GetUser(v.id)
    v.username = user.username
  end

  filter.ownerName = api:GetUser(filter.ownerID or filter.createdBy).username
  filter.relatedFilters = api:GetFilters(filter.relatedFilterIDs)
  request.thisfilter = filter
  if request.session.userID then
    request.isMod = api:UserCanEditFilter(request.session.userID, filter.id)
  end
  local sortBy = request.params.sortBy or 'fresh'
  request.posts = api:GetFilterPosts(userID, filter, sortBy)
  --(to_json(request.posts))
  if request.session.userID then
    for k,v in pairs(request.posts) do
      v.hash = ngx.md5(v.id..request.session.userID)
    end
  end

  return {render = 'filter.view'}

end

function m.LoadAllFilters(request)
  local user = api:GetUser(request.session.userID)
  if user and user.role == 'Admin' then
    request.isAdmin = true
  end

  --TODO: also get all user filters
  -- so we can change 'subscribe'  to 'unsubscribe'

  request.filters = api:GetFiltersBySubs()
  --print(to_json(request.filters))

  return {render = 'filter.all'}
end

function m.BanUser(request,filter)
  local userID = api:GetUserID(request.params.banuser)
  if not userID then
    ngx.log(ngx.ERR, 'attempt to ban a non-existant user: ',request.params.banuser)
    return 'user '..request.params.banuser..' does not exist'
  end
  local banInfo = {
    userID = userID,
    banReason = request.params.banUserReason or '',
    bannedBy = request.session.userID
  }
  local ok, err = api:FilterBanUser(request.session.userID, filter.id, banInfo)
  if ok then
    return 'success'
  else
    return 'fail: ',err
  end
end

function m.BanDomain(request,filter)

  local banInfo = {
    domainName = request.params.banDomain,
    banReason = request.params.banDomainReason or '',
    bannedBy = request.session.userID
  }
  local ok, err = api:FilterBanDomain(request.session.userID,filter.id, banInfo)
  if ok then
    return 'success'
  else
    return 'fail: ',err
  end
end

function m.UpdateFilterTags(request,filter)
  local requiredTagNames = from_json(request.params.requiredTagNames)
  local bannedTagNames = from_json(request.params.bannedTagNames)
  local userID = request.session.userID

  --print(to_json(filter))
  --print(filter.id)
  --print(to_json(requiredTagNames))
  --print(to_json(bannedTagNames))
  --print('tjis')
  local ok, err = api:UpdateFilterTags(userID, filter.id, requiredTagNames, bannedTagNames)
  if ok then
    print('done')
    return 'ok'
  else
    print('o shit:',err)
    return 'not ok, ',err
  end
end

function m.AddMod(request, filter)
  local modName = request.params.addmod
  local ok, err = api:AddMod(request.session.userID, filter.id, modName)
  if ok then
    return 'success'
  else
    return 'fail: ',err
  end
end

function m.DelMod(request, filter)
  local modID = request.params.delmod
  local ok, err = api:DelMod(request.session.userID, filter.id, modID)
  if ok then
    return 'success'
  else
    return 'fail: ',err
  end
end

function m.UpdateTitle(request, filter)
  local title = request.params.filtertitle

  local description = request.params.filterdescription

  local ok, err = api:UpdateFilterDescription(request.session.userID, filter.id,description)
  if not ok then
    return 'failed to update description: ',err
  end

  ok, err = api:UpdateFilterTitle(request.session.userID, filter.id, title)
  if not ok then
    return 'failed to update title: ',err
  else
    return 'success'
  end

end


function m.UpdateFilter(request)
  --print(request.params.filterlabel)
  local filter = api:GetFilterByName(request.params.filterlabel)
  if not filter then
    print('filter not found')
    return m.CreateFilter(request)
  end
  request.selectedFilter = filter

  if request.params.filtertitle then
    return m.UpdateTitle(request, filter)
  end

  if request.params.banuser then
     return m.BanUser(request, filter)
  end

  if request.params.banDomain then
    ngx.log(ngx.ERR, 'banning domain: ')
     return m.BanDomain(request,filter)
  end

  if request.params.requiredTagNames then
     return m.UpdateFilterTags(request,filter)
  end

  if request.params.addmod then
    return m.AddMod(request, filter)
  end

  if request.params.delmod then
    return m.DelMod(request, filter)
  end

  return 'not found'
end



function m.ViewFilterSettings(request)

  local filter = api:GetFilterByName(request.params.filterlabel)
  if not filter then
    ngx.log(ngx.ERR, 'no filter label found!')
    return 'error!'
  end
  print(to_json(filter))
  local user = api:GetUser(request.session.userID)

  if user.role ~= 'Admin' then
    if filter.ownerID ~= request.session.userID then
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

  request.tags = api:GetAllTags()

  -- get key indexed tags
  request.requiredTagKeys = {}
  for k, v in pairs(filter.requiredTagNames) do
    request.requiredTagKeys[v] = true
  end
  print(to_json(request.requiredTagKeys))

  request.bannedTagKeys = {}
  for k,v in pairs(filter.bannedTagNames) do
    request.bannedTagKeys[v] = true
  end

  -- add usernames to list of banned users
  request.bannedUsernames = {}
  local userInfo
  for _,v in pairs(filter.bannedUsers) do
    userInfo= api:GetUser(v.userID)
    request.bannedUsernames[v.userID] = userInfo.username
  end

  for _,v in pairs(filter.mods) do
    local user = api:GetUser(v.id)
    print(to_json(user))
    v.username = user.username
  end


  request.selectedFilter = filter
  return {render = 'filter.edit'}
end

function m.UnbanUser(request)
  local filter = api:GetFilterByName(request.params.filterlabel)
  if not filter then
    ngx.log(ngx.ERR, 'no filter label found!')
  end

  local ok, err = api:FilterUnbanUser(filter.id, request.params.userID)
  if ok then
    return 'success'
  else
    return 'fail: ',err
  end

end

function m.UnbanDomain(request)
  local filter = api:GetFilterByName(request.params.filterlabel)
  if not filter then
    ngx.log(ngx.ERR, 'no filter label found!')
  end

  local ok, err = api:FilterUnbanDomain(request.session.userID, filter.id, request.params.domainName)
  if ok then
    return 'success'
  else
    return 'fail: ',err
  end
end

function m.BanPost(request)
  local filter = api:GetFilterByName(request.params.filterlabel)
  if not filter then
    return 'filter not found'
  end

  local ok, err = api:FilterBanPost(request.session.userID, filter.id, self.params.postID)
  if ok then
    return 'ok'
  else
    return err
  end
end

function m.SearchFilters(request)

  if not request.params.searchString then
    return 'cant search blank!'
  end
  if not request.session.userID then
    return 'you must be logged in!'
  end
  local filters, err = api:SearchFilters(request.session.userID, request.params.searchString)

  if not filters then
    ngx.log(ngx.ERR, 'unable to search filters:',err)
    return 'couldnt search filters, sorry!'
  end

  request.filters = filters
  if not next(filters) then
    return 'no filters found matching '..request.params.searchString
  end
  request.searchString = request.params.searchString
  return {render = 'filter.all'}
end

function m:Register(app)
  app:match('filter','/f/:filterlabel',respond_to({GET = self.DisplayFilter,POST = self.NewFilter}))
  app:match('newfilter','/filters/create',respond_to({GET = self.CreateFilter,POST = self.NewFilter}))
  app:match('updatefilter','/filters/:filterlabel',respond_to({GET = self.ViewFilterSettings,POST = self.UpdateFilter}))
  app:get('allfilters','/f',self.LoadAllFilters)
  app:get('unbanfilteruser','/filters/:filterlabel/unbanuser/:userID',self.UnbanUser)
  app:get('unbanfilterdomain','/filters/:filterlabel/unbandomain/:domainName',self.UnbanDomain)
  app:get('banpost', '/filters/:filterlabel/banpost/:postID', self.BanPost)
  app:match('searchfilters', '/filters/search', self.SearchFilters)

end

return m
