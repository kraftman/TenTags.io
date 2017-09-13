



local postAPI = require 'api.posts'
local imageAPI = require 'api.images'
local uuid = require 'lib.uuid'


local respond_to = (require 'lapis.application').respond_to


local m = {}

-- o = orig (optimised)
-- b = big (960)
-- i = icon (100)
function m:Register(app)

  app:get('iconimage', '/i/i/:imageID', function(request) return self.GetImage(request, 'iconID') end)
  app:get('smallimage', '/i/s/:imageID', function(request) return self.GetImage(request, 'iconID') end)
  app:get('medimage', '/i/m/:imageID',function(request) return self.GetImage(request, 'bigID') end)
  app:get('bigimage', '/i/b/:imageID', function(request) return self.GetImage(request, 'imgID') end)
  app:get('previewVid', '/i/v/:imageID', function(request) return self.GetImage(request, 'previewID') end)
  app:get('gifVid', '/i/gv/:imageID', function(request) return self.GetImage(request, 'gifID') end)
  app:match('dmca','/i/dmca/:imageID', respond_to({
    GET = self.DmcaForm,
    POST = self.DmcaPost
  }))
end

function m.GetIcon(request)
  -- dont want to fallback to fullsize image if we cant find an image
end

function m.DmcaForm(request)
  if not request.params.imageID then
    return { redirect_to = '/static/icons/notfound.png' }
  end
  if not request.session.userID then
    return {render = 'pleaselogin'}
  end

  print(request.params.imageID)
  local image, err = imageAPI:GetImage( request.params.imageID)
  if not image then
    --display error page
    print(err)
    return 'couldnt find image'
  end

  request.image = image

  return {render = 'image.dmca'}
end

function m.DmcaPost(request)
  if not request.params.imageID then
    return { redirect_to = '/static/icons/notfound.png' }
  end

  if not request.session.userID then
    return {render = 'pleaselogin'}
  end

  local userID = request.session.userID or ngx.ctx.userID
  local takedownText = request.params.takedowntext


  local ok, err = imageAPI:SubmitTakedown(userID, request.params.imageID, takedownText)
  if ok then
    return 'your request has been submitted, thank you'
  else
    ngx.log(ngx.ERR, 'error submitting takedown: ',err)
    return 'there was an error with your request, please try again later'
  end

end


function m.GetImage(request,imageSize)
  if not request.params.imageID then
    return { redirect_to = '/static/icons/notfound.png' }
  end
  -- ratelimit based on session even if logged out
  local userID = request.session.userID or ngx.ctx.userID
  local imageData, err = imageAPI:GetImageData(userID, request.params.imageID, imageSize)

  if not imageData then
    return nil, 'image not found'
  end

  request.iconData = imageData.data
  if not request.iconData then
    return { redirect_to = '/static/icons/notfound.png' }
  end

  ngx.header['Content-Type'] = imageData.contentType
  ngx.header['Cache-Control'] = 'max-age=86400'
  ngx.say(request.iconData)

  return ngx.exit(ngx.HTTP_OK)
end




return m
