--[[
  access control
  rate limitting
  business logic
]]
local cache = require 'api.cache'
local api = {}
local to_json = (require 'lapis.util').to_json
local from_json = (require 'lapis.util').from_json
--self.session.current_user


function api:GetUserFilters(username)
  return cache:GetUserFilters(username)
end

function api:GetDefaultFrontPage(offset)
  offset = offset or 0
  return cache:GetDefaultFrontPage(offset)
end

function api:CreateTag(tagInfo)
  --check if the tag already exists
  -- create it
  if tagInfo.name:gsub(' ','') == '' then
    return false, 'tag cannot be blank'
  end

  local tag = cache:GetTag(tagInfo.name)
  if tag then
    return false, 'tag already exists'
  end

  local ok, err = worker:CreateTag(tagInfo)
  return ok,err

end

function api:CreatePost(postInfo)
  -- rate limit
  -- basic sanity check
  -- send to worker
  return worker:CreatePost(postInfo)

end

function api:GetAllTags()

  return cache:GetAllTags()
end


return api
