

local userAPI = require 'api.users'
local commentAPI = require 'api.comments'

local m = {}


function m:Register(app)
  app:get('home','/',self.FrontPage)
  app:post('home', '/',self.StopIt)
  app:get('new','/new',self.FrontPage)
  app:get('best','/best',self.FrontPage)
  app:get('seen','/seen',self.FrontPage)
end


function m.FrontPage(request)
  request.pageNum = request.params.page or 1
  local startAt = 10*(request.pageNum-1)
  local sortBy = request.req.parsed_url.path:match('/(%w+)$') or 'fresh'
  request.posts = userAPI:GetUserFrontPage(request.session.userID or 'default', sortBy, startAt, startAt+10)

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
end

function m.StopIt()
  return 'stop it'
end


return m
