

local M = {}

local api = require 'api.api'
local uuid = require 'uuid'


local util = require("lapis.util")
local from_json = util.from_json
local to_json = util.to_json
local respond_to = (require 'lapis.application').respond_to


local function NewFilter(self)
  local newID =  uuid.generate_random()
  local requiredTags = from_json(self.params.requiredTags)
  local bannedTags = from_json(self.params.bannedTags)

  local info ={
    title = self.params.title,
    label= self.params.label ,
    description = self.params.description,
    createdAt = ngx.time(),
    createdBy = self.session.current_user_id,
    ownerID = self.session.current_user_id
  }
  local tags = {}

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
  print(to_json(self.tags))
  return {render = 'createfilter'}
end

local function DisplayFilter(self)
  -- does the filter exist? if not then lets make it

  local filter = cache:LoadFilter(self.params.filterlabel)
  if not filter then
    return CreateFilter(self)
  end


  local tags = cache:LoadFilterTags(self.params.filterlabel)
  print(to_json(tags))
  local requiredTagID = {}
  local bannedTagID = {}

  for _,tag in pairs(tags) do
    if tag.filterType == 'required' then
      table.insert(requiredTagID,tag.id)
    elseif tag.filterType == 'banned' then
      table.insert(bannedTagID,tag.id)
    end
  end

  self.posts = cache:LoadFilteredPosts(requiredTagID,bannedTagID)

  DAL:AddTagsToPosts(self.posts)

  return {render = 'viewfilter'}

end

local function LoadAllFilters(self)

  self.filters = cache:LoadAllFilters()

  return {render = 'allfilters'}
end

function M:Register(app)
  app:match('filter','/f/:filterlabel',respond_to({GET = DisplayFilter,POST = NewFilter}))
  app:match('newfilter','/filters/create',respond_to({GET = CreateFilter,POST = NewFilter}))
  app:get('allfilters','/f',LoadAllFilters)

end

return M
