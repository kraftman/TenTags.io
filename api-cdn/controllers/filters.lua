


local filterAPI = require 'api.filters'
local userAPI = require 'api.users'
local tagAPI = require 'api.tags'

local util = require("lapis.util")
local from_json = util.from_json
local to_json = util.to_json
local respond_to = (require 'lapis.application').respond_to


local capture_errors = (require("lapis.application")).capture_errors
local app = require 'app'

local Sanitizer = require("web_sanitize.html").Sanitizer
local whitelist = require "web_sanitize.whitelist"

local my_whitelist = whitelist:clone()

my_whitelist.tags.img = false

local sanitize_html = Sanitizer({whitelist = my_whitelist})


local function BanUser(request,filter)

  if not request.session.userID then
    return {render = 'pleaselogin'}
  end

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

local function BanDomain(request,filter)

  if not request.session.userID then
    return {render = 'pleaselogin'}
  end

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

local function UpdateTitle(request, filter)

  if not request.session.userID then
    return {render = 'pleaselogin'}
  end

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



local function AddMod(request, filter)

  if not request.session.userID then
    return {render = 'pleaselogin'}
  end

  local modName = request.params.addmod
  local ok, err = filterAPI:AddMod(request.session.userID, filter.id, modName)
  if ok then
    return 'success'
  else
    return 'fail: ',err
  end
end



local function ToggleDefault(request)

  if not request.session.userID then
    return {render = 'pleaselogin'}
  end

  local userID = request.session.userID

  local filterID = request.params.filterID
  if not filterID then
    return 'no filter ID given'
  end

  if request.params.setdefault == 'true' then
    userAPI:ToggleFilterSubscription(userID, 'default', filterID)

    return {redirect_to = request:url_for("allfilters") }
  end

  local ok, err = userAPI:ToggleFilterSubscription(userID, userID,filterID)
  if not ok then
    ngx.log(ngx.ERR, 'unable to toggle filter sub: ',err)
  end
  return {redirect_to = request:url_for("allfilters") }
end


local function DelMod(request, filter)

  if not request.session.userID then
    return {render = 'pleaselogin'}
  end

  local modID = request.params.delmod
  local ok, err = filterAPI:DelMod(request.session.userID, filter.id, modID)
  if ok then
    return 'success'
  else
    return 'fail: ',err
  end
end

local function UpdateFilterTags(request,filter)

  if not request.session.userID then
    return {render = 'pleaselogin'}
  end

  local requiredTagNames = {}
  local bannedTagNames = {}

  local args = ngx.req.get_post_args()
  requiredTagNames = args.plustagselect or requiredTagNames
  bannedTagNames = args.minustagselect or bannedTagNames

  local userID = request.session.userID

  local ok, err = filterAPI:UpdateFilterTags(userID, filter.id, requiredTagNames, bannedTagNames)
  if ok then
    print('done')
    return 'ok'
  else
    print('o shit:',err)
    return 'not ok, ',err
  end
end


app:get('subscribefilter', '/f/:filterID/sub', capture_errors(function(request)

  local userID = request.session.userID

  local filterID = request.params.filterID

  local ok, err = userAPI:ToggleFilterSubscription(userID, userID, filterID)
  if not ok then
    ngx.log(ngx.ERR, 'unable to toggle filter sub: ',err)
  end
  return {redirect_to = request:url_for("allfilters") }
end))


app:match('filter.view','/f/:filterlabel',respond_to({
  GET = capture_errors(function(request)

    -- does the filter exist? if not then let them make it
    local filter = filterAPI:GetFilterByName(request.params.filterlabel)
    if not filter then
      return {redirect_to = request:url_for('filter.create', {})}
    end

    request.page_title = filter.name

    for _,v in pairs(filter.mods) do
      local user = userAPI:GetUser(v.id)
      v.username = user.username
    end

    local ownerID = filter.ownerID or filter.createdBy

    local owner = userAPI:GetUser(ownerID)

    filter.ownerName = owner.username
    filter.relatedFilters = filterAPI:GetFilters(filter.relatedFilterIDs)
    filter.description = request.markdown(filter.description or '')
    filter.description = sanitize_html(filter.description)
    request.thisfilter = filter
    if request.session.userID then
      request.isMod = filterAPI:UserCanEditFilter(request.session.userID, filter.id)
    end

    local sortBy = request.params.sortBy or 'fresh'
    local startAt = request.params.startAt or 0
    local range = 10

    request.posts = filterAPI:GetFilterPosts(request.session.userID or 'default', filter, sortBy, startAt, range)
    --(to_json(request.posts))
    --request.AddParams = AddParams
    if request.session.userID then
      for _,v in pairs(request.posts) do
        v.hash = ngx.md5(v.id..request.session.userID)
      end
    end

    if request.userInfo then
      request.showNSFL = request.userInfo.showNSFL
    else
      request.showNSFL = false
    end

    return {render = true}
  end),
  POST = function() return {redirect_to = '/filters/create'} end
}))

app:match('filter.create','/filters/create',respond_to({
  GET = function(request)
    if not request.session.userID then
      return { render = 'pleaselogin' }
    end
    request.page_title = 'Create Filter'
    request.tags = tagAPI:GetAllTags()
    return {render = true}
  end,
  POST = capture_errors(function(request)

      if not request.session.userID then
        return {render = 'pleaselogin'}
      end

      if request.params.setdefault or request.params.subscribe then
        return ToggleDefault(request)
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
  end)
}))

app:match('filter.edit','/filters/:filterlabel',respond_to({
  GET = capture_errors(function(request)

      local filter = filterAPI:GetFilterByName(request.params.filterlabel)
      if not filter then
        ngx.log(ngx.ERR, 'no filter label found!')
        return 'error!'
      end
      if not request.session.userID then
        return {render = 'pleaselogin'}
      end
      local user = userAPI:GetUser(request.session.userID)

      --maybe move to api
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
      for _, v in pairs(filter.requiredTagNames) do
        if not v:find('meta:filterban') then
          request.requiredTagKeys[v] = true
        end
      end

      request.bannedTagKeys = {}
      for _,v in pairs(filter.bannedTagNames) do
        if not v:find('meta:filterban') then
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
        local newUser = userAPI:GetUser(v.id)
        print(to_json(newUser))
        v.username = newUser.username
      end


      request.selectedFilter = filter
      return {render = 'filter.edit'}
  end),

  POST = capture_errors(function(request)

      if not request.session.userID then
        return {render = 'pleaselogin'}
      end

      --print(request.params.filterlabel)
      local filter =filterAPI:GetFilterByName(request.params.filterlabel)
      if not filter then
        print('filter not found')
        return {redirect_to = '/f/'..request.params.filterlabel}
      end
      request.selectedFilter = filter

      if request.params.filtertitle then
        return UpdateTitle(request, filter)
      end

      if request.params.banuser then
         return BanUser(request, filter)
      end

      if request.params.banDomain then
        ngx.log(ngx.ERR, 'banning domain: ')
         return BanDomain(request,filter)
      end

      if request.params.plustagselect then
         return UpdateFilterTags(request,filter)
      end

      if request.params.addmod then
        return AddMod(request, filter)
      end

      if request.params.delmod then
        return DelMod(request, filter)
      end

      return 'not found'
  end)
}))

app:get('filter.all','/f',capture_errors(function(request)
  local user = request.userInfo
  if user and user.role == 'Admin' then
    request.isAdmin = true
  end
  if user then
    request.userFilterIDs = userAPI:GetIndexedViewFilterIDs(user.id)
  else
    request.userFilterIDs = {}
  end
  request.filters = filterAPI:GetFiltersBySubs()

  local defaultFilters = userAPI:GetIndexedViewFilterIDs('default')
  for k,v in pairs(request.filters) do
    if defaultFilters[k] then
      v.default = true
    else
      v.default = false
    end
  end

  return {render = true}
end))

app:get('unbanfilteruser','/filters/:filterlabel/unbanuser/:userID',capture_errors(function(request)

  if not request.session.userID then
    return {render = 'pleaselogin'}
  end

  local filter = filterAPI:GetFilterByName(request.params.filterlabel)

  filterAPI:FilterUnbanUser(filter.id, request.params.userID)

  return 'success'
end))

app:get('unbanfilterdomain','/filters/:filterlabel/unbandomain/:domainName', capture_errors(function(request)

  if not request.session.userID then
    return {render = 'pleaselogin'}
  end

  local filter = filterAPI:GetFilterByName(request.params.filterlabel)

  filterAPI:FilterUnbanDomain(request.session.userID, filter.id, request.params.domainName)

  return 'success'

end))

app:get('banpost', '/filters/:filterlabel/banpost/:postID', capture_errors(function(request)
  if not request.session.userID then
    return {render = 'pleaselogin'}
  end

  local filter = filterAPI:GetFilterByName(request.params.filterlabel)

  filterAPI:FilterBanPost(request.session.userID, filter.id, request.params.postID)

  return 'ok'

end))

app:match('searchfilters', '/filters/search', capture_errors(function(request)

  if not request.params.searchString then
    return 'cant search blank!'
  end
  if not request.session.userID then
    return 'you must be logged in!'
  end
  local filters = filterAPI:SearchFilters(request.session.userID, request.params.searchString)

  request.filters = filters
  if not next(filters) then
    return 'no filters found matching '..request.params.searchString
  end


  local user = userAPI:GetUser(request.session.userID)
  if user and user.role == 'Admin' then
    request.isAdmin = true
  end

  request.userFilterIDs = userAPI:GetIndexedViewilterIDs(user.currentView)
  request.searchString = request.params.searchString
  return {render = 'filter.all'}
end))
