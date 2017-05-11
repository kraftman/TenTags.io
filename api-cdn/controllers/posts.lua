

local commentAPI = require 'api.comments'
local filterAPI = require 'api.filters'
local userAPI = require 'api.users'
local postAPI = require 'api.posts'
local tagAPI = require 'api.tags'
local util = require("lapis.util")

local from_json = util.from_json
local to_json = util.to_json

local m = {}

local respond_to = (require 'lapis.application').respond_to
local trim = util.trim


function m:Register(app)
  app:match('newpost','/p/new', respond_to({
    GET = self.CreatePostForm,
    POST = self.CreatePost
  }))
  app:match('viewpost','/p/:postID', respond_to({
    GET = self.GetPost,
    POST = self.EditPost,
  }))
  app:match('deletepost','/p/delete/:postID', respond_to({
    GET = self.DeletePost,
    POST = self.DeletePost,
  }))

  app:get('upvotetag','/post/upvotetag/:tagName/:postID',self.UpvoteTag)
  app:get('downvotetag','/post/downvotetag/:tagName/:postID',self.DownvoteTag)
  app:get('upvotepost','/post/:postID/upvote', self.UpvotePost)
  app:get('downvotepost','/post/:postID/downvote', self.DownvotePost)
  app:get('geticon', '/icon/:postID', self.GetIcon)
  app:get('subscribepost', '/post/:postID/subscribe', self.SubscribePost)

end


function m.CreatePost(request)

  if trim(request.params.link) == '' then
    request.params.link = nil
  end

  local info ={
    title = request.params.posttitle,
    link = request.params.postlink,
    text = request.params.posttext,
    createdBy = request.session.userID,
    tags = {}
  }

  if to_json(request.params.selectedtags) ~= -1 then
    info.tags = from_json(request.params.selectedtags)
  else
    --print(request.params.selectedtags)
    for word in request.params.selectedtags:gmatch('%S+') do
      table.insert(request.params.selectedtags, word)
    end
  end

  local ok, err = postAPI:CreatePost(request.session.userID, info)

  if ok then
    return {json = ok}
  else
    ngx.log(ngx.ERR, 'error from api: ',err or 'none')
    return {json = err}
  end

end

function m.GetPost(request)
  local sortBy = request.params.sort or 'best'
  sortBy = sortBy:lower()
  local userID = userID or 'default'


  local post
  local postID = request.params.postID

  -- get the post
  if #postID < 10 then
    postID = postAPI:ConvertShortURL(postID) or postID
    post = postAPI:GetPost(userID, postID)
  else
    post = postAPI:GetPost(userID, postID)

    if post.shortURL then
      return { redirect_to = request:url_for("viewpost",{postID = post.shortURL}) }
    end
  end

  if not post then
    return 'unable to find post'
  end

  print(post.createdBy)
  request.creatorName = userAPI:GetUser(post.createdBy).username

  local comments = commentAPI:GetPostComments(userID, postID,sortBy)

  for _,v in pairs(comments) do
    -- one of the 'comments' is actually the postID
    -- may shift this to api later
    if v.id and userID then
      v.commentHash = ngx.md5(v.id..userID)
    end
  end

  request.comments = comments

  --local post,err = postAPI:GetPost(request.session.userID, postID)
  --print(to_json(post))

  if not post then
    if type(err) == 'number' then
      return {status = err}
    end
    return err
  end

  for _,v in pairs(post.tags) do
    if v.name:find('^meta:sourcePost:') then
      post.containsSources = true
      local sourcePostID = v.name:match('meta:sourcePost:(%w+)')
      if sourcePostID then
        print(sourcePostID)
        local parentPost = (postAPI:GetPost(userID, sourcePostID))
        print(to_json(parentPost))
        if v.name and parentPost.title then
          v.fakeName = parentPost.title
          v.postID = sourcePostID
        end
      end
    end
  end

  request.filters = filterAPI:GetFilterInfo(post.filters)

  if request.session.userID then
    post.hash = ngx.md5(post.id..userID)
    post.userHasVoted = userAPI:UserHasVotedPost(userID, post.id)
    request.userLabels = userAPI:GetUser(userID).userLabels
  end

  request.post = post

  request.GetColorForDepth =function(_,child, depth)
    depth = depth or 1
    if not child then
      return ''
    end

    local username = child.username
    local colors = { '#ffcccc', '#ccddff', '#ccffcc', '#ffccf2','lightpink','lightblue','lightyellow','lightgreen','lightred'};
    local sum = 0

    for i = 1, #username do
      sum = sum + (username:byte(i))
    end

    sum = sum % #colors + 1

    if false then
      return 'style="background: '..colors[sum]..';"'
    end

    function DEC_HEX(IN)
      local B,K,OUT,I,D=16,"0123456789ABCDEF","",0
      while IN>0 do
          I=I+1
          IN,D=math.floor(IN/B),(IN % B)+1
          OUT=string.sub(K,D,D)..OUT
      end
      return OUT
    end

    depth = 4 + depth*2
    depth = DEC_HEX(depth)
    print(depth )
    depth = '#'..depth..depth..depth..depth..depth..depth
    return 'style="background: '..depth..';"'
  end

  request.GetColorForName = function(_,username)

    local colors = { '#992244', '#442211', '#662288','darkpink','darkblue','darkyellow','darkgreen','darkred'};
    local sum = 0

    for i = 1, #username do
      sum = sum + (username:byte(i))
    end

    sum = sum % #colors + 1

      return 'style="color: '..colors[sum]..';"'

  end

  return {render = 'post.view'}
end

function m.CreatePostForm(request)
  if not request.session.userID then
    return { render = 'pleaselogin' }
  end


  local tags = tagAPI:GetAllTags(api)

  request.tags = tags

  return { render = 'post.create' }
end




function m.UpvoteTag(request)

  tagAPI:VoteTag(request.session.userID, request.params.postID, request.params.tagName, 'up')
  return 'meep'

end

function m.DownvoteTag(request)
  tagAPI:VoteTag(request.session.userID, request.params.postID, request.params.tagName, 'down')
  return 'meep'

end

local function HashIsValid(request)
  --print(request.params.postID, request.session.userID)

  local realHash = ngx.md5(request.params.postID..request.session.userID)
  if realHash ~= request.params.hash then
    ngx.log(ngx.ERR, 'hashes dont match!')
    return false
  end
  return true
end


function m.UpvotePost(request)
  if not request.session.userID then
    return 'You must be logged in to vote'
  end
  if not HashIsValid(request) then
    return 'invalid hash'
  end
  local ok, err = postAPI:VotePost(request.session.userID, request.params.postID, 'up')
  if ok then
    return { redirect_to = request:url_for("home") }
  else
    return 'fail: ', err
  end
end



function m.DownvotePost(request)
  if not request.session.userID then
    return 'You must be logged in to vote'
  end
  if not HashIsValid(request) then
    return 'invalid hash'
  end
  local ok, err = postAPI:VotePost(request.session.userID, request.params.postID,'down')
  if ok then
    return { redirect_to = request:url_for("home") }
  else
    return 'fail: ', err
  end
end

function m.GetIcon(request)
  if not request.params.postID then
    return 'nil'
  end

  local post = postAPI:GetPost(request.params.postID)
  if not post.icon then
    return ''
  end
  request.post = post
  if not type(post.icon) == 'string' then
    return ''
  end
  print(post.icon)

  request.iconData = ngx.decode_base64(post.icon)

  return {layout = 'layout.blanklayout',content_type = 'image'}


end

function m.AddSource(request)
  print('adding source')
  local sourceURL = request.params.sourceurl
  local userID = request.session.userID
  if not sourceURL then
    return 'no url given!'
  elseif not userID then
    return 'you must be logged in to do that!'
  end

  local ok, err = postAPI:AddSource(userID, request.params.postID, sourceURL)
  if ok then
    return 'success!'
  else
    return 'error: '..err
  end

end

function m.AddTag(request)
  local tagName = request.params.addtag
  local userID = request.session.userID
  local postID = request.params.postID

  local ok, err = postAPI:AddPostTag(userID, postID, tagName)
  if ok then
    return { redirect_to = request:url_for("viewpost",{postID = request.params.postID}) }
  else
    print('failed: ',err)
    return 'failed: '..err
  end

end

function m.EditPost(request)

  if request.params.sourceurl then
    return m.AddSource(request)
  end

  if request.params.addtag then
    return m.AddTag(request)
  end

  local post = {
    id = request.params.postID,
    title = request.params.posttitle,
    text = request.params.posttext
  }

  local ok,err = postAPI:EditPost(request.session.userID, post)
  if ok then
    return { redirect_to = request:url_for("viewpost",{postID = request.params.postID}) }
  else
    return 'fail: '..err
  end


end

function m.DeletePost(request)
  local confirmed = request.params.confirmdelete

  if not confirmed then
    return {render = 'post.confirmdelete'}
  end

  local postID = request.params.postID
  local userID = request.params.userID

  local ok, err = postAPI:DeletePost(userID, postID)

  if ok then
    return 'success'
  else
    return 'failed: '..err
  end

end

function m.SubscribePost(request)
  local ok, err = postAPI:SubscribePost(request.session.userID,request.params.postID)
  if ok then
    return { redirect_to = request:url_for("viewpost",{postID = request.params.postID}) }
  else
    return 'error subscribing: '..err
  end
end


return m
