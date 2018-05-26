
local app = require 'app'
local commentAPI = require 'api.comments'
local filterAPI = require 'api.filters'
local userAPI = require 'api.users'
local postAPI = require 'api.posts'
local tagAPI = require 'api.tags'
local imageAPI = require 'api.images'
local lapisUtil = require("lapis.util")
local app_helpers = require("lapis.application")
local csrf = require("lapis.csrf")
local util = require 'util'

local capture_errors = app_helpers.capture_errors
local yield_error = app_helpers.yield_error
local assert_error = app_helpers.assert_error

local Sanitizer = require("web_sanitize.html").Sanitizer
local whitelist = require "web_sanitize.whitelist"

local my_whitelist = whitelist:clone()

my_whitelist.tags.img = false

local sanitize_html = Sanitizer({whitelist = my_whitelist})

local from_json = lapisUtil.from_json

local respond_to = (require 'lapis.application').respond_to
local trim = lapisUtil.trim

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
    return yield_error('no url given!')
  elseif not userID then
    return yield_error( 'you must be logged in to do that!')
  end

  assert_error(postAPI:AddSource(userID, request.params.postID, sourceURL))


end

local function GetColorForDepth(_,child, depth)
  depth = depth or 1
  depth = (depth % 7) +1
  if not child then
    return ''
  end

  -- local username = child.username
  -- local colors = { '#ffcccc',
  -- '#ccddff', '#ccffcc', '#ffccf2',
  -- 'lightpink','lightblue','lightyellow','lightgreen','lightred'};
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


  local tagName = request.params.addtag
  local userID = request.session.userID
  local postID = request.params.postID

  assert_error(postAPI:AddPostTag(userID, postID, tagName))
 
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

local function processImageUpload(request, info)
  -- if no js handle one image
  local fileData = request.params.upload_file
  local ok, err

  if request.params.upload_file and (fileData.content ~= '') then
    ok = imageAPI:CreateImage(fileData)
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
          return nil, err
        end
        info.images[#info.images+1] =  v.id
      end
    end
  end
end

--========== requests

app:match('post.create','/p/new', respond_to({
  GET = capture_errors({
    on_error = util.HandleError,
    function(request)
      local tags = tagAPI:GetAllTags()
      request.tags = tags

      return { render = true }
    end
  }),

  POST = capture_errors({
    on_error = util.HandleError,
    function(request)
      csrf.assert_token(request)
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

      request.params.selectedtags = request.params.selectedtags:match('"(.+)"')
      for word in request.params.selectedtags:gmatch('%S+') do
        table.insert(info.tags, word)
      end

      -- if they have no js let them form upload one image
      local ok, err = processImageUpload(request, info)
      if not ok then
        return {json = {error = true, data = {err}}}
      end

      local newPost, err = postAPI:CreatePost(request.session.userID, info)

      if newPost then
        return {json = {error = false, data = newPost}}
        --return {redirect_to = request:url_for("post.view",{postID = newPost.id})}
      else
        ngx.log(ngx.ERR, 'error from api: ',err or 'none')
        return {json = {error = true, data = {err}}}
      end

    end
  })
}))

local function AddLinks(comment)
	comment.text = comment.text:gsub('@(%S%S%S+)', '<a href = "/u/%1">@%1</a>')
  comment.text = comment.text:gsub('/f/(%S%S%S+)', '<a href = "/f/%1">/f/%1</a>')
end

local permittedSorts = {
  best = 'best',
  new = 'new',
  top = 'top',
  funny = 'funny',
}

local function parseSortBy(sortBy)
  if not sortBy then
    return 'best'
  end
  sortBy = sortBy:lower();
  return permittedSorts[sortBy] or 'best'
end

local function getPostComments(request, postID)
  -- add comments to post

  local sortBy = parseSortBy(request.params.sort)

  local userID = request.session.userID or 'default'
  local comments = commentAPI:GetPostComments(userID, postID, sortBy) or {}
  --print(to_json(comments))

  for _,comment in pairs(comments) do
    -- one of the 'comments' is actually the postID
    -- may shift this to api later
    if comment.text then
      comment.text = request.markdown(comment.text or '')
      comment.text = sanitize_html(comment.text)
      AddLinks(comment)
    end
    if comment.id and userID then
      comment.commentHash = ngx.md5(comment.id..userID)
    end
  end
  return comments
end

local function isUserSubbed(userID, subscribers)
  for _,v in pairs(subscribers) do
    if v == userID then
      return true
    end
  end
end

local function processPostImages(request, post)
  for k,v in pairs(post.images) do
    post.images[k] = imageAPI:GetImage(v)
    post.images[k].text = request.markdown(post.images[k].text)
  end
end

local function addPostSource(post, userID)
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
end

local function loadFilters(filterIDs)
  local filters = filterAPI:GetFilterInfo(filterIDs)
  local loadedFilters = {}
  for i = 0, math.min(10, #filters) do
    if filters[i] then
      loadedFilters[i] = filters[i]
    end
  end
  return loadedFilters
end

local function addLoggedInDetails(request, post, userID)
  if not request.session.userID then
    return
  end
  post.hash = ngx.md5(post.id..userID)
  post.userHasVoted = userAPI:UserHasVotedPost(userID, post.id)
  request.userLabels = userAPI:GetUser(userID).userLabels
end

local function addEdittable(request, post, userID)
  local user = request.userInfo

  if userID == post.createdBy or (user and user.role == 'Admin') then
    request.userCanEdit = true
    post.editText = post.text
  end
end

app:match('post.view','/p/:postID', respond_to({
  GET = capture_errors({
    on_error = util.HandleError,
    function(request)

      local userID = request.session.userID or 'default'
      local postID = request.params.postID

      local post = postAPI:GetPost(userID, postID)
      if not post then
        return request.app.handle_404(request)
      end

      request.page_title = post.title

      --redirect to shorturl
      if (#postID > 10) and post.shortURL then
        return { redirect_to = request:url_for("post.view",{postID = post.shortURL}) }
      end
      postID = post.id

      request.comments = getPostComments(request, postID)
      request.userSubbed = isUserSubbed(userID, post.viewers)
      request.filters = loadFilters(post.filters)

      post.text = request.markdown(post.text)

      -- get images
      processPostImages(request, post)
      addPostSource(post, userID)
      addLoggedInDetails(request, post, userID)
      addEdittable(request, post, userID)

      request.post = post
      request.GetColorForDepth = GetColorForDepth
      request.GetColorForName = GetColorForName

      return {render = true}
    end
  }),

  POST = capture_errors({
    on_error = util.HandleError,
    function(request)

      if request.params.sourceurl then
        AddSource(request)
      elseif request.params.addtag then
        AddTag(request)
      else
        -- edit the post
        local post = {
          id = request.params.postID,
          title = request.params.posttitle,
          text = request.params.posttext
        }
        assert_error(postAPI:EditPost(request.session.userID, post))
      end

      return { redirect_to = request:url_for("post.view",{postID = request.params.postID}) }
    end
  })
}))


app:match('deletepost','/p/delete/:postID', capture_errors({
  on_error = util.HandleError,
  function(request)

    local confirmed = request.params.confirmdelete

    if not confirmed then
      return {render = 'post.confirmdelete'}
    end

    local postID = request.params.postID
    local userID = request.params.userID

    assert_error(postAPI:DeletePost(userID, postID))

    return { redirect_to = request:url_for("frontpage") }

  end
}))

app:match('post.report', '/p/report/:postID', respond_to({
  GET = capture_errors({
    on_error = util.HandleError,
    function(request)
      request.post = assert_error(postAPI:GetPost(request.session.userID, request.params.postID))
      return {render = true}
    end
  }),
  POST = capture_errors({
    on_error = util.HandleError,
    function(request)
      assert_error(postAPI:ReportPost(request.session.userID, request.params.postID, request.params.reportreason))
      return 'thanks, this post has been reported'
    end
  })
}))


app:get('upvotetag','/p/upvotetag/:tagName/:postID',capture_errors({
  on_error = util.HandleError,
  function(request)

    assert_error(tagAPI:VoteTag(request.session.userID, request.params.postID, request.params.tagName, 'up'))
    return true

  end
}))

app:get('downvotetag','/p/downvotetag/:tagName/:postID',capture_errors({
  on_error = util.HandleError,
  function(request)

    assert_error(tagAPI:VoteTag(request.session.userID, request.params.postID, request.params.tagName, 'down'))
    return 'meep'

  end
}))

app:get('upvotepost','/p/upvote/:postID', capture_errors({
  on_error = util.HandleError,
  function(request)

    if not HashIsValid(request) then
      return yield_error('invalid hash')
    end
    assert_error(postAPI:VotePost(request.session.userID, request.params.postID, 'up'))

    return { redirect_to = request:url_for("home") }

  end
}))

app:get('downvotepost','/p/downvote/:postID', capture_errors({
  on_error = util.HandleError,
  function(request)

    if not HashIsValid(request) then
      return yield_error('invalid hash')
    end
    assert_error(postAPI:VotePost(request.session.userID, request.params.postID, 'down'))

    return { redirect_to = request:url_for("home") }

  end
}))

app:get('subscribepost', '/p/subscribe/:postID', capture_errors({
  on_error = util.HandleError,
  function(request)
    assert_error(postAPI:SubscribePost(request.session.userID,request.params.postID))
    return { redirect_to = request:url_for("post.view",{postID = request.params.postID}) }
  end
}))

app:get('savepost','/p/save/:postID',capture_errors({
  on_error = util.HandleError,
  function(request)
    local userID = request.session.userID
    local postID = request.params.postID
    assert_error(userAPI:ToggleSavePost(userID, postID))
    return { redirect_to = request:url_for("post.view",{postID = postID}) }
  end
}))

app:get('reloadimage','/p/reloadimage/:postID', capture_errors({
  on_error = util.HandleError,
  function(request)

    local userID = request.session.userID
    local postID = request.params.postID

    assert_error(postAPI:ReloadImage(userID, postID))
    return { redirect_to = request:url_for("post.view",{postID = postID}) }
  end
}))
