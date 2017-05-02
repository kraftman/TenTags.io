

local m = {}


local respond_to = (require 'lapis.application').respond_to

local tinsert = table.insert
local elastic = require 'lib.elasticsearch'


function m.SearchPosts(request)
  local search = request.params.searchquery or ''
  local results, err = elastic:SearchWholePostFuzzy(search)
  if not results then
    ngx.log(ngx.ERR, err)
    return {render = 'search.failed'}
  else
    results = from_json(results)
    request.results = results.hits.hits
    print(to_json(results))
    return {render = 'search.results'}
  end
end

function m:Register(app)
  app:match('searchposts','/search/post',respond_to({GET = self.SearchPosts, POST = self.SearchPosts}))
end

return m
