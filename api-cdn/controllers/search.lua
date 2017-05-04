

local m = {}


local respond_to = (require 'lapis.application').respond_to

local tinsert = table.insert
local searchAPI = require 'api.search'


function m.SearchPosts(request)
  local search = request.params.searchquery or ''
  local ok, err = searchAPI:SearchPost(search)

  if not ok then
    ngx.log(ngx.ERR, err)
    return {render = 'search.failed'}
  else
    request.results = ok.hits.hits
    return {render = 'search.results'}
  end
end

function m:Register(app)
  app:match('searchposts','/search/post',respond_to({GET = self.SearchPosts, POST = self.SearchPosts}))
end

return m
