local userAPI = require 'api.users'
local commentAPI = require 'api.comments'
local respond_to = require("lapis.application").respond_to

local app_helpers = require("lapis.application")
local capture_errors, assert_error = app_helpers.capture_errors, app_helpers.assert_error
local util = require 'util'

local app = require 'app'

local captured = capture_errors({
  on_error = util.HandleError,
  function(request)
    request.pageNum = request.params.page or 1
    local startAt = 20*(request.pageNum-1)
    local sortBy = request.req.parsed_url.path:match('/(%w+)$') or 'fresh'
    local userID = request.session.userID
    request.posts = assert_error(userAPI:GetUserFrontPage(userID or 'default', nil, sortBy, startAt, startAt+20))

    --print(to_json(request.posts))

    --defer until we need it
    for _, v in pairs(request.posts) do
      v.text = request.markdown(v.text)
    end

    if request:GetFilterTemplate():find('filtta') then
      for _,post in pairs(request.posts) do
        local comments = assert_error(commentAPI:GetPostComments(userID, post.id, 'best'))
        _, post.topComment = next(comments[post.id].children)

        -- if post.topComment then

        -- end
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
    -- if not request.posts or #request.posts == 0 then
    --   -- if sortBy ~= 'seen' then -- prevent loop
    --   --   --return { redirect_to = request:url_for("seen") }
    --   -- end
    -- end

    return {render = 'frontpage'}
  end
})

app:match('home', '/', respond_to({
  PROPFIND = function()
    return {render = 'errors.404'}
  end,
  GET = captured,
  POST = function()
    return 'stoppit'
  end
}))

app:get('new','/new',captured)
app:get('best','/best',captured)
app:get('seen','/seen',captured)
