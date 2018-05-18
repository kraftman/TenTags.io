


local filterAPI = require 'api.filters'
local userAPI = require 'api.users'
local tagAPI = require 'api.tags'

local to_json = require("lapis.util").to_json
local respond_to = (require 'lapis.application').respond_to
local app_helpers = require("lapis.application")
local assert_error = app_helpers.assert_error
local yield_error = app_helpers.yield_error


local capture_errors = (require("lapis.application")).capture_errors
local app = require 'app'
local util = require 'util'

local Sanitizer = require("web_sanitize.html").Sanitizer
local whitelist = require "web_sanitize.whitelist"

local my_whitelist = whitelist:clone()

my_whitelist.tags.img = false

local sanitize_html = Sanitizer({whitelist = my_whitelist})


local function BanUser(request,filter)

  local userID = assert_error(userAPI:GetUserID(request.params.banuser))

  local banInfo = {
    userID = userID,
    banReason = request.params.banUserReason or '',
    bannedBy = request.session.userID
  }
  assert_error(filterAPI:FilterBanUser(request.session.userID, filter.id, banInfo))

end

local function BanDomain(request,filter)

  local banInfo = {
    domainName = request.params.banDomain,
    banReason = request.params.banDomainReason or '',
    bannedBy = request.session.userID
  }
  assert_error(filterAPI:FilterBanDomain(request.session.userID,filter.id, banInfo))
  
end

local function UpdateTitle(request, filter)

  local title = request.params.filtertitle

  local description = request.params.filterdescription

  assert_error(filterAPI:UpdateFilterDescription(request.session.userID, filter.id,description))
  assert_error(filterAPI:UpdateFilterTitle(request.session.userID, filter.id, title))


end

local function AddMod(request, filter)

  local modName = request.params.addmod
  assert_error(filterAPI:AddMod(request.session.userID, filter.id, modName))

end

local function ToggleDefault(request)

  local userID = request.session.userID

  local filterID = request.params.filterID
  if not filterID then
    return 'no filter ID given'
  end

  if request.params.setdefault == 'true' then
    assert_error(userAPI:ToggleFilterSubscription(userID, 'default', filterID))
    return {redirect_to = request:url_for("filter.all") }
  end

  assert_error(userAPI:ToggleFilterSubscription(userID, userID,filterID))

  return {redirect_to = request:url_for("filter.all") }
end


local function DelMod(request, filter)

  local modID = request.params.delmod
  assert_error(filterAPI:DelMod(request.session.userID, filter.id, modID))

end

local function UpdateFilterTags(request,filter)

  local requiredTagNames = {}
  local bannedTagNames = {}

  local args = ngx.req.get_post_args()
  requiredTagNames = args.plustagselect or requiredTagNames
  bannedTagNames = args.minustagselect or bannedTagNames

  local userID = request.session.userID

  assert_error(filterAPI:UpdateFilterTags(userID, filter.id, requiredTagNames, bannedTagNames))
end


app:get('subscribefilter', '/f/:filterID/sub', capture_errors(function(request)
  return ToggleDefault(request)
  -- local userID = request.session.userID
  --
  -- local filterID = request.params.filterID
  --
  -- local ok, err = userAPI:ToggleFilterSubscription(userID, userID, filterID)
  -- if not ok then
  --   ngx.log(ngx.ERR, 'unable to toggle filter sub: ',err)
  -- end
  -- return {redirect_to = request:url_for("filter.all") }
end))

local function loadMods(mods)
  for _,v in pairs(mods) do
    local user = userAPI:GetUser(v.id)
    v.username = user.username
  end
end

local function addFilterDetails(request, filter)
  local ownerID = filter.ownerID or filter.createdBy

  local owner = assert_error(userAPI:GetUser(ownerID))

  filter.ownerName = owner.username
  filter.relatedFilters = assert_error(filterAPI:GetFilters(filter.relatedFilterIDs))
  filter.description = request.markdown(filter.description or '')
  filter.description = sanitize_html(filter.description)
  request.page_title = filter.name
  request.thisfilter = filter
  if request.session.userID then
    request.isMod = assert_error(filterAPI:UserCanEditFilter(request.session.userID, filter.id))
  end

  if request.userInfo then
    request.showNSFL = request.userInfo.showNSFL
  else
    request.showNSFL = false
  end
end

local function loadFilterPosts(request, filter)

  local sortBy = request.params.sortBy or 'fresh'
  local startAt = request.params.startAt or 0
  local range = 10
  local rs = request.session

  request.posts = filterAPI:GetFilterPosts(rs.userID or 'default', filter, sortBy, startAt, range)

  if rs.userID then
    for _,v in pairs(request.posts) do
      v.hash = ngx.md5(v.id..rs.userID)
      -- TODO: why do we only get text for logged in users?
      v.text = request.markdown(v.text:sub(1,300))
    end
  end
end

app:match('filter.view','/f/:filterlabel',respond_to({
  GET = capture_errors({
    on_error = util.HandleError,
    function(request)

      -- does the filter exist? if not then let them make it
      local filter = assert_error(filterAPI:GetFilterByName(request.params.filterlabel))
      if not filter then
        return {redirect_to = request:url_for('filter.create', {})}
      end

      loadMods(filter.mods)

      addFilterDetails(request, filter)

      loadFilterPosts(request, filter)

      return {render = true}
    end
  }),
  POST = function() return {redirect_to = '/filters/create'} end
}))

app:match('filter.create','/filters/create',respond_to({
  GET = function(request)
    request.page_title = 'Create Filter'
    request.tags = tagAPI:GetAllTags()
    return {render = true}
  end,
  POST = capture_errors({
    on_error = util.HandleError,
    function(request)

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


      local newFilter = assert_error(filterAPI:CreateFilter(request.session.userID, info))

      return {redirect_to = request:url_for("filter.edit",{filterlabel = newFilter.name}) }
    end
  })
}))

local function getRequiredTags(requiredTagNames)
  -- get key indexed tags
  local requiredTags = {}
  for _, v in pairs(requiredTagNames) do
    if not v:find('meta:filterban') then
      requiredTags[v] = true
    end
  end
  return requiredTags
end

local function getBannedTags(bannedTagNames)
  local bannedTagKeys = {}
  for _,v in pairs(bannedTagNames) do
    if not v:find('meta:filterban') then
      bannedTagKeys[v] = true
    end
  end
  return bannedTagKeys
end

local function loadBannedUsers(bannedUsers)
  local bannedUsernames = {}
  local userInfo

  for _,v in pairs(bannedUsers) do
    userInfo = userAPI:GetUser(v.userID)
    bannedUsernames[v.userID] = userInfo.username
  end
  return bannedUsernames
end

local function canEdit(request, filter, user)
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
        return yield_error('Not allowed')
      end
    end
  end
end

app:match('filter.edit','/filters/:filterlabel',respond_to({
  GET = capture_errors({
    on_error = util.HandleError,
    function(request)

      local filter = assert_error(filterAPI:GetFilterByName(request.params.filterlabel))

      local user = assert_error(userAPI:GetUser(request.session.userID))

      --maybe move to api
      assert_error(canEdit(request, filter, user))

      request.tags = tagAPI:GetAllTags()

      request.requiredTagKeys = getRequiredTags(filter.requiredTagNames)
      request.bannedTagKeys = getBannedTags(filter.bannedTagNames)
      request.bannedUsernames = loadBannedUsers(filter.bannedUsers)

      loadMods(filter.mods)

      request.selectedFilter = filter
      return {render = 'filter.edit'}
    end
  }),

  POST = capture_errors(function(request)

    --print(request.params.filterlabel)
    local filter = filterAPI:GetFilterByName(request.params.filterlabel)
    if not filter then
      return {redirect_to = '/f/'..request.params.filterlabel}
    end

    request.selectedFilter = filter

    if request.params.filtertitle then
      UpdateTitle(request, filter)
    end

    if request.params.banuser then
      BanUser(request, filter)
    end

    if request.params.banDomain then
      BanDomain(request,filter)
    end

    if request.params.plustagselect then
      UpdateFilterTags(request,filter)
    end

    if request.params.addmod then
      AddMod(request, filter)
    end

    if request.params.delmod then
      DelMod(request, filter)
    end

    return {redirect_to = request:url_for("filter.edit",{filterlabel = request.params.filterlabel}) }
  end)
}))

app:get('filter.all','/f',capture_errors({
  on_error = util.HandleError,
  function(request)

    local user = userAPI:GetUser(request.session.userID)

    if user and user.role == 'Admin' then
      request.isAdmin = true
    end
    if user then
      request.userFilterIDs = assert_error(userAPI:GetIndexedViewFilterIDs(user.id))
    else
      request.userFilterIDs = {}
    end
    request.filters = assert_error(filterAPI:GetFiltersBySubs())

    local defaultFilters = assert_error(userAPI:GetIndexedViewFilterIDs('default'))

    for _,v in pairs(request.filters) do
      v.timeAgo = request:TimeAgo(ngx.time() - (tonumber(v.createdAt) or 0))
      if defaultFilters[v.id] then
        v.default = true
      else
        v.default = false
      end
    end

    return {render = true}
  end
}))

app:get('filter.unbanuser','/filters/:filterlabel/unbanuser/:userID',capture_errors({
  on_error = util.HandleError,
  function(request)

    local filter = assert_error(filterAPI:GetFilterByName(request.params.filterlabel))

    assert_error(filterAPI:FilterUnbanUser(request.session.userID, filter.id, request.params.userID))

    return {redirect_to = request:url_for("filter.edit",{filterlabel = request.params.filterlabel}) }
  end
}))

app:get('unbanfilterdomain','/filters/:filterlabel/unbandomain/:domainName', capture_errors({
  on_error = util.HandleError,
  function(request)

    local filter = assert_error(filterAPI:GetFilterByName(request.params.filterlabel))
    assert_error(filterAPI:FilterUnbanDomain(request.session.userID, filter.id, request.params.domainName))

    return {redirect_to = request:url_for("filter.edit",{filterlabel = request.params.filterlabel}) }

  end
}))

app:get('banpost', '/filters/:filterlabel/banpost/:postID', capture_errors(function(request)

  local filter = assert_error(filterAPI:GetFilterByName(request.params.filterlabel))

  assert_error(filterAPI:FilterBanPost(request.session.userID, filter.id, request.params.postID))

  return {redirect_to = request:url_for("filter.edit",{filterlabel = request.params.filterlabel}) }

end))

app:match('searchfilters', '/filters/search', capture_errors({
  on_error = util.HandleError,
  function(request)

    if not request.params.searchString then
      yield_error('cant search blank!')
    end
    if not request.session.userID then
      yield_error( 'you must be logged in!')
    end
    local filters = assert_error(filterAPI:SearchFilters(request.session.userID, request.params.searchString))

    request.filters = filters
    if not next(filters) then
      return 'no filters found matching '..request.params.searchString
    end


    local user = assert_error(userAPI:GetUser(request.session.userID))
    if user and user.role == 'Admin' then
      request.isAdmin = true
    end

    request.userFilterIDs = assert_error(userAPI:GetIndexedViewFilterIDs(user.id))
    request.searchString = request.params.searchString
    return {render = 'filter.all'}
  end
}))
