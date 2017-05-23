

local m = {}

local filterAPI = require 'api.filters'
local userAPI = require 'api.users'
local tagAPI = require 'api.tags'

local util = require("lapis.util")
local from_json = util.from_json
local to_json = util.to_json
local respond_to = (require 'lapis.application').respond_to


local Sanitizer = require("web_sanitize.html").Sanitizer
local whitelist = require "web_sanitize.whitelist"

local my_whitelist = whitelist:clone()

my_whitelist.tags.img = false

local sanitize_html = Sanitizer({whitelist = my_whitelist})


function m:Register(app)

  app:get('subscribefilter', '/f/:filterID/sub', self.SubscribeFilter)
  app:match('filter','/f/:filterlabel',respond_to({GET = self.DisplayFilter,POST = self.NewFilter}))
  app:match('newfilter','/filters/create',respond_to({GET = self.CreateFilter,POST = self.NewFilter}))
  app:match('updatefilter','/filters/:filterlabel',respond_to({GET = self.ViewFilterSettings,POST = self.UpdateFilter}))
  app:get('allfilters','/f',self.LoadAllFilters)
  app:get('unbanfilteruser','/filters/:filterlabel/unbanuser/:userID',self.UnbanUser)
  app:get('unbanfilterdomain','/filters/:filterlabel/unbandomain/:domainName',self.UnbanDomain)
  app:get('banpost', '/filters/:filterlabel/banpost/:postID', self.BanPost)
  app:match('searchfilters', '/filters/search', self.SearchFilters)

end

function m.SubscribeFilter(request)
  local userID = request.session.userID

  if not userID then
    return { render = 'pleaselogin' }
  end
  local filterID = request.params.filterID


  local ok, err = userAPI:ToggleFilterSubscription(userID, userID, filterID)
  if not ok then
    ngx.log(ngx.ERR, 'unable to toggle filter sub: ',err)
  end
  return {redirect_to = request:url_for("allfilters") }
end

function m.ToggleDefault(request)
  local userID = request.session.userID

  if not userID then
    return { render = 'pleaselogin' }
  end

  local filterID = request.params.filterID
  if not filterID then
    return 'no filter ID given'
  end

  if request.params.setdefault == 'true' then
    userAPI:ToggleFilterSubscription(userID, 'default', filterID)
    filterAPI:SetToggleDefault(userID,filterID)
    return {redirect_to = request:url_for("allfilters") }
  end

  local ok, err = userAPI:ToggleFilterSubscription(userID, userID,filterID)
  if not ok then
    ngx.log(ngx.ERR, 'unable to toggle filter sub: ',err)
  end
  return {redirect_to = request:url_for("allfilters") }
end

function m.NewFilter(request)

  if request.params.setdefault or request.params.subscribe then
    return m.ToggleDefault(request)
  end

  local info ={
    title = request.params.title,
    name= request.params.filterName and request.params.filterName:gsub(' ','') or '',
    description = request.params.description,
    createdAt = ngx.time(),
    createdBy = request.session.userID,
    ownerID = request.session.userID,
    bannedTagNames = {},
    requiredTagNames = {}
  }

  for word in request.params.requiredTagNames:gmatch('%S+') do
    table.insert(info.requiredTagNames, word)
  end

  for word in request.params.bannedTagNames:gmatch('%S+') do
    table.insert(info.bannedTagNames, word)
  end


  local newFilter, err = filterAPI:CreateFilter(request.session.userID, info)
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
  request.tags = tagAPI:GetAllTags()
  return {render = 'filter.create'}
end


function m.DisplayFilter(request)

  -- does the filter exist? if not then let them make it
  local filter = filterAPI:GetFilterByName(request.params.filterlabel)

  if not filter then
    return m.CreateFilter(request)
  end

  for _,v in pairs(filter.mods) do
    local user = userAPI:GetUser(v.id)
    v.username = user.username
  end

  filter.ownerName = userAPI:GetUser(filter.ownerID or filter.createdBy).username
  filter.relatedFilters = filterAPI:GetFilters(filter.relatedFilterIDs)
  filter.description = request.markdown.markdown(filter.description)
  filter.description = sanitize_html(filter.description)
  request.thisfilter = filter
  if request.session.userID then
    request.isMod = filterAPI:UserCanEditFilter(request.session.userID, filter.id)
  end
  local sortBy = request.params.sortBy or 'fresh'
  local startAt = request.params.startAt or 0
  local range = 10
  print(startAt, range)
  request.posts = filterAPI:GetFilterPosts(request.session.userID, filter, sortBy, startAt, range)
  --(to_json(request.posts))
  request.AddParams = AddParams
  if request.session.userID then
    for k,v in pairs(request.posts) do
      v.hash = ngx.md5(v.id..request.session.userID)
    end
  end

  return {render = 'filter.view'}

end

function m.LoadAllFilters(request)
  local user = request.userInfo
  if user and user.role == 'Admin' then
    request.isAdmin = true
  end
  if user then
    request.userFilterIDs = userAPI:GetIndexedUserFilterIDs(user.id)
  else
    request.userFilterIDs = {}
  end
  request.filters = filterAPI:GetFiltersBySubs()
  --print(to_json(request.filters))

  return {render = 'filter.all'}
end

function m.BanUser(request,filter)
  local userID = userAPI:GetUserID(request.params.banuser)
  if not userID then
    ngx.log(ngx.ERR, 'attempt to ban a non-existant user: ',request.params.banuser)
    return 'user '..request.params.banuser..' does not exist'
  end
  local banInfo = {
    userID = userID,
    banReason = request.params.banUserReason or '',
    bannedBy = request.session.userID
  }
  local ok, err = filterAPI:FilterBanUser(request.session.userID, filter.id, banInfo)
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
  local ok, err = filterAPI:FilterBanDomain(request.session.userID,filter.id, banInfo)
  if ok then
    return 'success'
  else
    return 'fail: ',err
  end
end

function m.UpdateFilterTags(request,filter)
  local requiredTagNames = {}
  local bannedTagNames = {}

  local args = ngx.req.get_post_args()
  requiredTagNames = args.plustagselect or requiredTagNames
  bannedTagNames = args.minustagselect or bannedTagNames

  local userID = request.session.userID

  --print(to_json(filter))
  --print(filter.id)
  --print(to_json(requiredTagNames))
  --print(to_json(bannedTagNames))
  --print('tjis')
  local ok, err = filterAPI:UpdateFilterTags(userID, filter.id, requiredTagNames, bannedTagNames)
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
  local ok, err = filterAPI:AddMod(request.session.userID, filter.id, modName)
  if ok then
    return 'success'
  else
    return 'fail: ',err
  end
end

function m.DelMod(request, filter)
  local modID = request.params.delmod
  local ok, err = filterAPI:DelMod(request.session.userID, filter.id, modID)
  if ok then
    return 'success'
  else
    return 'fail: ',err
  end
end

function m.UpdateTitle(request, filter)
  local title = request.params.filtertitle

  local description = request.params.filterdescription

  local ok, err = filterAPI:UpdateFilterDescription(request.session.userID, filter.id,description)
  if not ok then
    return 'failed to update description: ',err
  end

  ok, err = filterAPI:UpdateFilterTitle(request.session.userID, filter.id, title)
  if not ok then
    return 'failed to update title: ',err
  else
    return 'success'
  end

end


function m.UpdateFilter(request)
  --print(request.params.filterlabel)
  local filter =filterAPI:GetFilterByName(request.params.filterlabel)
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

  if request.params.plustagselect then
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

  local filter = filterAPI:GetFilterByName(request.params.filterlabel)
  if not filter then
    ngx.log(ngx.ERR, 'no filter label found!')
    return 'error!'
  end
  local user = request.userInfo

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

  request.tags = tagAPI:GetAllTags()

  -- get key indexed tags
  request.requiredTagKeys = {}
  for k, v in pairs(filter.requiredTagNames) do
    if not v:find('meta:') then
      request.requiredTagKeys[v] = true
    end
  end

  request.bannedTagKeys = {}
  for k,v in pairs(filter.bannedTagNames) do
    if not v:find('meta:') then
      request.bannedTagKeys[v] = true
    end
  end

  -- add usernames to list of banned users
  request.bannedUsernames = {}
  local userInfo
  for _,v in pairs(filter.bannedUsers) do
    userInfo= userAPI:GetUser(v.userID)
    request.bannedUsernames[v.userID] = userInfo.username
  end

  for _,v in pairs(filter.mods) do
    local user = userAPI:GetUser(v.id)
    print(to_json(user))
    v.username = user.username
  end


  request.selectedFilter = filter
  return {render = 'filter.edit'}
end

function m.UnbanUser(request)
  local filter =filterAPI:GetFilterByName(request.params.filterlabel)
  if not filter then
    ngx.log(ngx.ERR, 'no filter label found!')
  end

  local ok, err =filterAPI:FilterUnbanUser(filter.id, request.params.userID)
  if ok then
    return 'success'
  else
    return 'fail: ',err
  end

end

function m.UnbanDomain(request)
  local filter =filterAPI:GetFilterByName(request.params.filterlabel)
  if not filter then
    ngx.log(ngx.ERR, 'no filter label found!')
  end

  local ok, err =filterAPI:FilterUnbanDomain(request.session.userID, filter.id, request.params.domainName)
  if ok then
    return 'success'
  else
    return 'fail: ',err
  end
end

function m.BanPost(request)
  local filter =filterAPI:GetFilterByName(request.params.filterlabel)
  if not filter then
    return 'filter not found'
  end

  local ok, err =filterAPI:FilterBanPost(request.session.userID, filter.id, self.params.postID)
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
  local filters, err = filterAPI:SearchFilters(request.session.userID, request.params.searchString)

  if not filters then
    ngx.log(ngx.ERR, 'unable to search filters:',err)
    return 'couldnt search filters, sorry!'
  end

  request.filters = filters
  if not next(filters) then
    return 'no filters found matching '..request.params.searchString
  end

  request.userFilterIDs = userAPI:GetIndexedUserFilterIDs(request.session.userID)
  request.searchString = request.params.searchString
  return {render = 'filter.all'}
end


return m
