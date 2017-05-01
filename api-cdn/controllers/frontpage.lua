

local userAPI = require 'api.users'

local m = {}





function m.FrontPage(request)
  request.pageNum = request.params.page or 1
  local range = 10*(request.pageNum-1)
  local filter = request.req.parsed_url.path:match('/(%w+)$')

  request.posts = userAPI:GetUserFrontPage(request.session.userID or 'default',filter,range, range+10)

  --print(to_json(request.posts))

  --defer until we need it
  if request:GetFilterTemplate():find('filtta') then
    for _,post in pairs(request.posts) do
      local comments =api:GetPostComments(request.session.userID, post.id, 'best')
      _, post.topComment = next(comments[post.id].children)

      if post.topComment then
        print(post.topComment.text)
      end
    end
  end

  if request.session.userID then
    for _,v in pairs(request.posts) do
      if v.id then
        v.hash = ngx.md5(v.id..request.session.userID)
      end
    end
    request.userInfo = userAPI:GetUser(request.session.userID)
  end

  -- if empty and logged in then redirect to seen posts
  if not request.posts or #request.posts == 0 then
    if filter ~= 'seen' then -- prevent loop
      --return { redirect_to = request:url_for("seen") }
    end
  end



  return {render = 'frontpage'}
end

function m:Register(app)
  app:get('home','/',self.FrontPage)
  app:get('new','/new',self.FrontPage)
  app:get('best','/best',self.FrontPage)
  app:get('seen','/seen',self.FrontPage)
end

return m
