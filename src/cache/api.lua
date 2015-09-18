
local redis = require "resty.redis"
local cache = require 'cache'
local M = {}

local function LoadFilterList(self)
  local username = self.params.username

  local filterList= cache:LoadFilterList(username)

  if filterList then
    print('found')
    return {json = filterList}
  else
    return {status = 500}
  end

end

local function LoadFrontPage(self)
  local username = self.params.username
  local filterList = cache:LoadFilterList(username)
  local posts = cache:LoadFilterPosts(filterList, 0,50)
  return {json = posts}

end

local function SplitPosts(postsReq)
  local posts = {}
  for word in postsReq:gmatch('(%d+)') do
    table.insert(posts,word)
  end
  return posts
end

local function LoadPosts(self)
  local postsReq = self.params.posts
  if not postsReq then
    return {json = {}}
  end

  local posts = SplitPosts(postsReq)

  local postsWithInfo = cache:BatchLoadPosts(posts)
  if not postsWithInfo then
    return {status = 500}
  end
  return {json = postsWithInfo}

end

function M:Register(app)
  app:get('filterlist','/filterlist/:username',LoadFilterList)
  app:get('frontpage','/frontpage/:username',LoadFrontPage)
  app:get('getpostinfo','/posts',LoadPosts)

end

return M
