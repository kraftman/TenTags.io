

local userAPI = require 'api.users'
local commentAPI = require 'api.comments'

local app_helpers = require("lapis.application")
local capture_errors, assert_error, yield_error = app_helpers.capture_errors, app_helpers.assert_error, app_helpers.yield_error


local m = {}
local app = require 'app'




local captured = capture_errors(function(request)
  request.pageNum = request.params.page or 1
  local startAt = 20*(request.pageNum-1)
  local sortBy = request.req.parsed_url.path:match('/(%w+)$') or 'fresh'
  request.posts = userAPI:GetUserFrontPage(request.session.userID or 'default', nil, sortBy, startAt, startAt+20)

  --print(to_json(request.posts))

  --defer until we need it

  if request:GetFilterTemplate():find('filtta') then
    for _,post in pairs(request.posts) do
      local comments = commentAPI:GetPostComments(request.session.userID, post.id, 'best')
      _, post.topComment = next(comments[post.id].children)

      if post.topComment then
      end
    end
  end

  if request.session.userID then
    for _,v in pairs(request.posts) do
      if v.id then
        v.hash = ngx.md5(v.id..request.session.userID)
      end
    end
  end

  -- if empty and logged in then redirect to seen posts
  if not request.posts or #request.posts == 0 then
    if sortBy ~= 'seen' then -- prevent loop
      --return { redirect_to = request:url_for("seen") }
    end
  end

  return {render = 'frontpage'}
end)

app:get('home','/',captured)
app:post('home', '/',function() return 'stopit' end)
app:get('new','/new',captured)
app:get('best','/best',captured)
app:get('seen','/seen',captured)
