



local postAPI = require 'api.posts'
local imageAPI = require 'api.images'
local userAPI = require 'api.users'
local uuid = require 'lib.uuid'


local app = require 'app'
local app_helpers = require("lapis.application")
local capture_errors, assert_error = app_helpers.capture_errors, app_helpers.assert_error

local respond_to = (require 'lapis.application').respond_to


-- o = orig (optimised)
-- b = big (960)
-- i = icon (100)

app:get('postIcon', '/p/i/:postID', capture_errors(function(request)
  local userID = request.session.userID or ngx.ctx.userID

  local post = assert_error(postAPI:GetPost(userID, request.params.postID))

  local user = userAPI:GetUser(userID)
  if not user then
    -- panic
    user = {
      showNSFL = false,
      nsfwLevel = 1
    }
  end

  if post.postType == 'self' then
    return {redirect_to = '/static/icons/self.svg'}
  end

  if post.nsfl and not user.showNSFL then
    return {redirect_to = '/static/icons/nsfw.jpg'}
  end

  if post.nsfwLevel and user.nsfwLevel < post.nsfwLevel then
    return {redirect_to = '/static/icons/nsfw.jpg'}
  end

  if #post.images > 0 then
    request.params.imageID = post.images[1]
    print(post.images[1])
    return m.GetImage(request, 'iconID')
  end

  -- need to handle icons now
  if post.bigIcon or post.smallIcon then

    local size = request.params.size == 'small' and 'smallIcon' or 'bigIcon'
    print('getting icon: ', size, post[size])
    local imageData = assert_error(imageAPI:GetImageDataByBBID(userID, post[size]))

    ngx.header['Content-Type'] = imageData.contentType
    ngx.header['Cache-Control'] = 'max-age=86400'
    ngx.say(imageData.data)
    return ngx.exit(ngx.HTTP_OK)
  end

  return { redirect_to = '/static/icons/notfound.png' }

end))

app:get('imagereload', '/i/:imageID/reload', capture_errors(function(request)

  if not request.session.userID then
    return {render = 'pleaselogin'}
  end

  assert_error(imageAPI:ReloadImage(request.session.userID, request.params.imageID))

  return 'reloading!'
end))


local function GetImage(request,imageSize)
  if not request.params.imageID then
    return { redirect_to = '/static/icons/notfound.png' }
  end
  -- ratelimit based on session even if logged out
  local userID = request.session.userID or ngx.ctx.userID
  local imageData = assert_error(imageAPI:GetImageData(userID, request.params.imageID, imageSize))


  request.iconData = imageData.data
  if not request.iconData then
    return { redirect_to = '/static/icons/notfound.png' }
  end

  ngx.header['Content-Type'] = imageData.contentType
  ngx.header['Cache-Control'] = 'max-age=86400'
  ngx.say(request.iconData)

  return ngx.exit(ngx.HTTP_OK)
end

app:get('smallimage', '/i/s/:imageID', capture_errors(function(request) return GetImage(request, 'iconID') end))
app:get('medimage', '/i/m/:imageID', capture_errors(function(request) return GetImage(request, 'bigID') end))
app:get('bigimage', '/i/b/:imageID', capture_errors(function(request) return GetImage(request, 'imgID') end))
app:get('previewVid', '/i/v/:imageID', capture_errors(function(request) return GetImage(request, 'previewID') end))
app:get('gifVid', '/i/gv/:imageID', capture_errors(function(request) return GetImage(request, 'gifID') end))

app:match('dmca','/i/dmca/:imageID', respond_to({
  GET = capture_errors(function(request)
    if not request.params.imageID then
      return { redirect_to = '/static/icons/notfound.png' }
    end
    if not request.session.userID then
      return {render = 'pleaselogin'}
    end

    print(request.params.imageID)
    local image = imageAPI:GetImage( request.params.imageID)
    if not image then
      return { redirect_to = '/static/icons/notfound.png' }
    end

    request.image = image

    return {render = 'image.dmca'}
  end),
  POST = capture_errors(function(request)
    if not request.params.imageID then
      return { redirect_to = '/static/icons/notfound.png' }
    end

    if not request.session.userID then
      return {render = 'pleaselogin'}
    end

    local userID = request.session.userID or ngx.ctx.userID
    local takedownText = request.params.takedowntext


    assert_error(imageAPI:SubmitTakedown(userID, request.params.imageID, takedownText))

    return 'your request has been submitted, thank you'

  end)
}))
