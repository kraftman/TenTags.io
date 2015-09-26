--[[
  access control
  rate limitting
  business logic
]]
local cache = require 'api.cache'
local api = {}
local to_json = (require 'lapis.util').to_json
local from_json = (require 'lapis.util').from_json
local uuid = require 'lib.uuid'
local worker = require 'api.worker'
local tinsert = table.insert
local trim = (require 'lapis.util').trim

--self.session.current_user


function api:GetUserFilters(username)
  local filterIDs = cache:GetUserFilterIDs(username)

  return cache:GetFilterInfo(filterIDs)
end

function api:GetDefaultFrontPage(offset)
  offset = offset or 0
  return cache:GetDefaultFrontPage(offset)
end

function api:CreateTag(tagName,createdBy)
  --check if the tag already exists
  -- create it
  if tagName:gsub(' ','') == '' then
    return nil
  end

  local tag = cache:GetTag(tagName)
  if tag then
    return tag
  end

  local tagInfo = {
    id = uuid.generate_random(),
    createdAt = ngx.time(),
    createdBy = createdBy,
    name = tagName
  }

  worker:CreateTag(tagInfo)
  return tagInfo
end

function api:PostIsValid(postInfo)

  return true
end

function api:CreatePost(postInfo)
  -- rate limit
  -- basic sanity check
  -- send to worker
  if not api:PostIsValid(postInfo) then
    return false
  end

  postInfo.id = uuid.generate_random()
  postInfo.parentID = postInfo.id
  postInfo.createdBy = postInfo.createdBy or 'default'
  postInfo.commentCount = 0

  if not postInfo or trim(postInfo.link) == '' then
    tinsert(postInfo.tags,'self')
  end

  for k,v in pairs(postInfo.tags) do
    v = trim(v:lower())
    postInfo.tags[k] = self:CreateTag(v,postInfo.createdBy)
    if postInfo.tags[k] then
      postInfo.tags[k].up = 1
      postInfo.tags[k].down = 0
      postInfo.tags[k].score = 0
      postInfo.tags[k].active = true
    end
  end

  worker:CreatePost(postInfo)

  return true

end

function api:FilterIsValid(filterInfo)
  return true
end

function api:LoadFilterPosts(filter)
  return {}
end

function api:GetFilter(filterName)
  return cache:GetFilter(filterName)
end

function api:GetFiltersBySubs(offset,count)
  offset = offset or 0
  count = count or 10
  local filters = cache:GetFiltersBySubs(offset,count)
  return filters


end

function api:CreateFilter(filterInfo)

  if not api:FilterIsValid(filterInfo) then
    return false
  end

  filterInfo.id = uuid.generate_random()
  filterInfo.subscribers = 0
  filterInfo.name = filterInfo.name:lower()
  filterInfo.subs = 1

  local tags = {}

  for k,v in pairs(filterInfo.requiredTags) do
    local tag = self:CreateTag(v, filterInfo.createdBy)
    if tag then
      tag.filterID = filterInfo.id
      tag.filterType = 'required'
      tag.createdBy = filterInfo.createdBy
      tag.createdAt = filterInfo.createdAt
      tinsert(tags,tag)
      filterInfo.requiredTags[k] = tag
    end
  end

  for k,v in pairs(filterInfo.bannedTags) do
    local tag = self:CreateTag(v, filterInfo.createdBy)
    if tag then
      tag.filterID = filterInfo.id
      tag.filterType = 'banned'
      tag.createdBy = filterInfo.createdBy
      tag.createdAt = filterInfo.createdAt
      tinsert(tags,tag)
      filterInfo.bannedTags[k] = tag
    end
  end
  filterInfo.tags = tags

  worker:CreateFilter(filterInfo)

  return true
end

function api.GetAllTags()
  return cache:GetAllTags()
end


return api
