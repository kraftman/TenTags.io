

local m = {}


local respond_to = (require 'lapis.application').respond_to

local tinsert = table.insert
local searchAPI = require 'api.search'
local trim = (require 'lapis.util').trim


function m.SearchPosts(request)
  local search = trim(request.params.searchquery or '')
  if search == '' then
    return {redirect_to = request:url_for("newpost")}
  end

  local ok, err = searchAPI:SearchPost(search)

  if not ok then
    ngx.log(ngx.ERR, err)
    return {render = 'search.failed'}
  end
  
  if search:find('^http') and ok.hits.total == 0 then

    request.postLink = search
    return {redirect_to = request:url_for("newpost",{postLink = search })..'?postLink='..search}
  else
    request.results = ok.hits.hits
    return {render = 'search.results'}
  end

end

function m:Register(app)
  app:match('searchposts','/search/post',respond_to({GET = self.SearchPosts, POST = self.SearchPosts}))
end

return m
