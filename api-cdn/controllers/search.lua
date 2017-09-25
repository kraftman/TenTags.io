

local app = require 'app'
local app_helpers = require("lapis.application")
local capture_errors, assert_error = app_helpers.capture_errors, app_helpers.assert_error

local searchAPI = require 'api.search'
local trim = (require 'lapis.util').trim

app:match('search.results','/search/post',capture_errors(function(request)
  local search = trim(request.params.searchquery or '')
  if search == '' then
    return {redirect_to = request:url_for("post.create")}
  end

  local ok = assert_error(searchAPI:SearchPost(search))

  if search:find('^http') and ok.hits.total == 0 then

    request.postLink = search
    return {redirect_to = request:url_for("newpost",{postLink = search })..'?postLink='..search}
  else
    request.results = ok.hits.hits
    return {render = 'search.results'}
  end
end))
