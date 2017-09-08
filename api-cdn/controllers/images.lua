



local postAPI = require 'api.posts'
local imageAPI = require 'api.images'
local uuid = require 'lib.uuid'


local m = {}




function m:Register(app)

  app:get('geticon', '/i/:postID/bigIcon', function(request) return self.GetImage(request, 'bigIcon') end)
  app:get('geticonsmall', '/i/:postID/icon',function(request) return self.GetImage(request, 'smallIcon') end)
  app:get('getimage', '/i/:imageID', function(request) return self.GetImage(request, 'bbID') end)
end


function m.GetImage(request,imageSize)
  if not request.params.postID then
    return { redirect_to = '/static/icons/notfound.png' }
  end
  -- ratelimit based on session even if logged out
  local userID = request.session.userID or ngx.ctx.userID

  local post, err = postAPI:GetPost(userID, request.params.postID)
  if not post or not post[imageSize] then

    --ngx.header['Content-Type'] = 'image/png'
    return { redirect_to = '/static/icons/notfound.png' }
  end
  request.iconData = postAPI:GetImage(post[imageSize])
  if not request.iconData then
    return { redirect_to = '/static/icons/notfound.png' }
  end

  ngx.header['Content-Type'] = 'image/jpeg'
  ngx.header['Cache-Control'] = 'max-age=86400'
  ngx.say(request.iconData)

  return ngx.exit(ngx.HTTP_OK)
end




return m
