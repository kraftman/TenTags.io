--[[
  access control
  rate limitting
  business logic
]]
local cache = require 'api.cache'
local api = {}
local to_json = (require 'lapis.util').to_json
local from_json = (require 'lapis.util').from_json
local uuid = require 'uuid'
local worker = require 'api.worker'
local tinsert = table.insert
local trim = (require 'lapis.util').trim

--self.session.current_user


function api:GetDefaultFilters()
  return cache:GetDefaultFilters()
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

  cache:AddPost(postInfo)
  worker:CreatePost(postInfo)

  return true

end

function api:CreateFilter(filterInfo)

  if not api:FilterIsValid(filterInfo) then
    return false
  end

  filterInfo.id = uuid.generate_random()

  local tags = {}


  for k,v in pairs(filterInfo.requiredTags) do
    self:CreateTag(v, filterInfo.createdBy)
  end

  for k,v in pairs(filterInfo.bannedTags) do
    self:CreateTag(v, filterInfo.createdBy)
  end

  worker:CreateFilter(filterInfo)

  return true
end

function api.GetAllTags()
  return cache:GetAllTags()
end


return api
