

local app = require 'app'
local commentAPI = require 'api.comments'
local filterAPI = require 'api.filters'
local userAPI = require 'api.users'
local postAPI = require 'api.posts'
local tagAPI = require 'api.tags'
local imageAPI = require 'api.images'
local util = require("lapis.util")
local app_helpers = require("lapis.application")

local capture_errors, assert_error = app_helpers.capture_errors, app_helpers.assert_error

local Sanitizer = require("web_sanitize.html").Sanitizer
local whitelist = require "web_sanitize.whitelist"

local my_whitelist = whitelist:clone()

my_whitelist.tags.img = false

local sanitize_html = Sanitizer({whitelist = my_whitelist})

local from_json = util.from_json


local respond_to = (require 'lapis.application').respond_to
local trim = util.trim

--======== local utils

local function DEC_HEX(IN)
  local B,K,OUT,I,D=16,"0123456789ABCDEF","",0
  while IN>0 do
      I=I+1
      IN,D=math.floor(IN/B),(IN % B)+1
      OUT=string.sub(K,D,D)..OUT
  end
  return OUT
end


local function AddSource(request)

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

local function GetColorForDepth(_,child, depth)
  depth = depth or 1
  depth = (depth % 7) +1
  if not child then
    return ''
  end

  -- local username = child.username
  -- local colors = { '#ffcccc', '#ccddff', '#ccffcc', '#ffccf2','lightpink','lightblue','lightyellow','lightgreen','lightred'};
  -- local sum = 0
  --
  -- for i = 1, #username do
  --   sum = sum + (username:byte(i))
  -- end
  --
  -- sum = sum % #colors + 1
  --
  -- if false then
  --   return 'style="background: '..colors[sum]..';"'
  -- end

  depth = 4 + depth*2
  depth = DEC_HEX(depth)
  depth = '#'..depth..depth..depth..depth..depth..depth
  return 'style="background: '..depth..';"'
end

local function GetColorForName(_,username)

  local colors = { '#992244', '#442211', '#662288','darkpink','darkblue','darkyellow','darkgreen','darkred'};
  local sum = 0

  for i = 1, #username do
    sum = sum + (username:byte(i))
  end

  sum = sum % #colors + 1

  return 'style="color: '..colors[sum]..';"'

end

local function AddTag(request)

  if not request.session.userID then
    return {render = 'pleaselogin'}
  end

  local tagName = request.params.addtag
  local userID = request.session.userID
  local postID = request.params.postID

  local ok, err = postAPI:AddPostTag(userID, postID, tagName)
  if ok then
    return { redirect_to = request:url_for("post.view",{postID = request.params.postID}) }
  else
    print('failed: ',err)
    return 'failed: '..err
  end

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



--========== requests

app:match('post.create','/p/new', respond_to({
  GET = function(request)
    if not request.session.userID then
      return { render = 'pleaselogin' }
    end

    local tags = tagAPI:GetAllTags()

    request.tags = tags

    return { render = true }
  end,

  POST = function(request)

      if not request.session.userID then
        return {render = 'pleaselogin'}
      end

      if trim(request.params.link) == '' then
        request.params.link = nil
      end

      local info ={
        title = request.params.posttitle,
        link = request.params.postlink,
        text = request.params.posttext,
        createdBy = request.session.userID,
        tags = {},
        images = {}
      }

      for word in request.params.selectedtags:gmatch('%S+') do
        table.insert(info.tags, word)
      end
      local ok, err

      -- if they have no js let them form upload one image
      local fileData = request.params.upload_file

      if request.params.upload_file and (fileData.content ~= '') then
        ok, err = imageAPI:CreateImage(fileData)
        if ok then
          info.images = { ok.id}
        end
      end
      -- otherwise let them assign multiple preuploaded images
      if request.params.postimages then
        for _, v in pairs(from_json(request.params.postimages)) do
          if v.text then
            ok, err = imageAPI:AddText(request.session.userID, v.id, v.text)
            if not ok then
              return {json = {error = true, data = {err}}}
            end
            info.images[#info.images+1] =  v.id
          end
        end
      end

      local newPost, err = postAPI:CreatePost(request.session.userID, info)

      if newPost then
        print('returning new post')
        return {json = {error = false, data = newPost}}
        --return {redirect_to = request:url_for("post.view",{postID = newPost.id})}
      else
        ngx.log(ngx.ERR, 'error from api: ',err or 'none')
        return 'error creating post: '.. err
      end

  end
}))

local function AddLinks(comment)
	comment.text = comment.text:gsub('@(%S%S%S+)', '<a href = "/u/%1">@%1</a>')
  comment.text = comment.text:gsub('/f/(%S%S%S+)', '<a href = "/f/%1">/f/%1</a>')
end

app:match('post.view','/p/:postID', respond_to({
  GET = capture_errors(function(request)
    local sortBy = request.params.sort or 'best'
    sortBy = sortBy:lower()
    local userID = request.session.userID or 'default'
    local postID = request.params.postID

    local post = postAPI:GetPost(userID, postID)

    request.page_title = post.title

    if (#postID > 10) and post.shortURL then
      return { redirect_to = request:url_for("post.view",{postID = post.shortURL}) }
    end
    postID = post.id
    local comments = commentAPI:GetPostComments(userID, postID, sortBy)

    -- add comments to post
    for _,v in pairs(comments) do
      -- one of the 'comments' is actually the postID
      -- may shift this to api later
      if v.text then
        v.text = request.markdown(v.text or '')
        print('ran discount')
        print(v.text)
        v.text = sanitize_html(v.text)
        AddLinks(v)
      end
      if v.id and userID then
        v.commentHash = ngx.md5(v.id..userID)
      end
    end

    request.comments = comments

    -- get usernames
    for _,v in pairs(post.viewers) do
      if v == userID then
        request.userSubbed = true
        break
      end
    end

    -- get images
    for k,v in pairs(post.images) do
      post.images[k] = imageAPI:GetImage( v)
      post.images[k].text = request.markdown(post.images[k].text)
    end


    for _,v in pairs(post.tags) do
      if v.name:find('^meta:sourcePost:') then

        post.containsSources = true
        local sourcePostID = v.name:match('meta:sourcePost:(%w+)')

        if sourcePostID then

          local parentPost = postAPI:GetPost(userID, sourcePostID)

          if v.name and parentPost and parentPost.title then
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
    local user = userAPI:GetUser(userID)

    if userID == post.createdBy or (user and user.role == 'Admin') then
      request.userCanEdit = true
    else
      post.text = request.markdown(post.text)
    end
    request.post = post
    request.GetColorForDepth = GetColorForDepth
    request.GetColorForName = GetColorForName

    return {render = true}
  end),

  POST = function(request)

    if not request.session.userID then
      return {render = 'pleaselogin'}
    end

    if request.params.sourceurl then
      return AddSource(request)
    end

    if request.params.addtag then
      return AddTag(request)
    end

    local post = {
      id = request.params.postID,
      title = request.params.posttitle,
      text = request.params.posttext
    }

    local ok,err = postAPI:EditPost(request.session.userID, post)
    if ok then
      return { redirect_to = request:url_for("post.view",{postID = request.params.postID}) }
    else
      return 'fail: '..err
    end
  end
}))


app:match('deletepost','/p/delete/:postID', function(request)

  if not request.session.userID then
    return {render = 'pleaselogin'}
  end

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

end)

app:match('post.report', '/p/:postID/report', respond_to({
  GET = function(request)
    if not request.session.userID then
      return {render = 'pleaselogin'}
    end

    local ok = postAPI:GetPost(request.session.userID, request.params.postID)
    request.post = ok
    return {render = 'post.report'}
  end,
  POST = function(request)
    if not request.session.userID then
      return {render = 'pleaselogin'}
    end
    local ok, err = postAPI:ReportPost(request.session.userID, request.params.postID, request.params.reportreason)
    if ok then
      return 'reported!'
    else
      return err
    end
  end
}))


app:get('upvotetag','/post/upvotetag/:tagName/:postID',function(request)
  if not request.session.userID then
    return {render = 'pleaselogin'}
  end

  tagAPI:VoteTag(request.session.userID, request.params.postID, request.params.tagName, 'up')
  return 'meep'

end)

app:get('downvotetag','/post/downvotetag/:tagName/:postID',function(request)

  if not request.session.userID then
    return {render = 'pleaselogin'}
  end
  tagAPI:VoteTag(request.session.userID, request.params.postID, request.params.tagName, 'down')
  return 'meep'

end)

app:get('upvotepost','/post/:postID/upvote', function(request)
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
end)

app:get('downvotepost','/post/:postID/downvote', function(request)
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
end)

app:get('subscribepost', '/post/:postID/subscribe', function(request)

  if not request.session.userID then
    return {render = 'pleaselogin'}
  end
  local ok, err = postAPI:SubscribePost(request.session.userID,request.params.postID)
  if ok then
    return { redirect_to = request:url_for("post.view",{postID = request.params.postID}) }
  else
    return 'error subscribing: '..err
  end
end)

app:get('savepost','/post/:postID/save',function(request)
  local userID = request.session.userID
  if not userID then
    return {render = 'pleaselogin'}
  end
  local postID =  request.params.postID
  local ok, err = userAPI:ToggleSavePost(userID, postID)
  if not ok then
    print('error saving post, ',err)
    return 'error saving post'
  end
  return 'succes'
end)

app:get('reloadimage','/post/:postID/reloadimage', function(request)

  if not request.session.userID then
    return {render = 'pleaselogin'}
  end

  local userID = request.session.userID
  local postID = request.params.postID
  if not userID then
    return {render = 'pleaselogin'}
  end
  local ok, err = postAPI:ReloadImage(userID, postID)
  if ok then
    return 'success'
  else
    return err
  end
end)
