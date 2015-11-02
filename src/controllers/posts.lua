

local api = require 'api.api'
local util = require("lapis.util")

local from_json = util.from_json
local to_json = util.to_json

local m = {}

local respond_to = (require 'lapis.application').respond_to
local trim = util.trim


local function CreatePost(self)

  local selectedTags = from_json(self.params.selectedtags)

  if trim(self.params.link) == '' then
    self.params.link = nil
  end

  local info ={
    title = self.params.title,
    link = self.params.link,
    text = self.params.text,
    createdAt = ngx.time(),
    createdBy = self.session.userID,
    tags = selectedTags
  }

  local ok, err = api:CreatePost(info)

  if ok then
    return
  else
    ngx.log(ngx.ERR, 'error from api: ',err or 'none')
    return {status = 500}
  end

end

local function GetPost(self)
  local sortBy = self.params.sort or 'best'
  sortBy = sortBy:lower()

  local comments = api:GetPostComments(self.params.postID,sortBy)
  for _,v in pairs(comments) do
    -- one of the 'comments' is actually the postID
    -- may shift this to api later
    if v.id then
      v.commentHash = ngx.md5(v.id..self.session.userID)
    end
  end


  self.comments = comments

  local post = api:GetPost(self.params.postID)
  --print(to_json(post))
  self.filters = api:GetFilterInfo(post.filters)

  self.post = post

  return {render = true}
end

local function CreatePostForm(self)
  local tags = api.GetAllTags(api)

  self.tags = tags

  return { render = 'createpost' }
end

-- needs moving to comments controller
local function CreateComment(self)

  --local newCommentID = uuid.generate_random()

  local commentInfo = {
    --id = newCommentID,
    parentID = self.params.parentID,
    postID = self.params.postID,
    createdBy = self.session.userID,
    text = self.params.commentText,
  }
  ngx.log(ngx.ERR, to_json(self.params))
  local ok = api:CreateComment(commentInfo)
  if ok then
    return 'created!'
  else
    return 'failed!'
  end

end


local function UpvoteTag(self)

  api:VoteTag(self.params.postID, self.params.tagID, 'up')
  return 'meep'

end

local function DownvoteTag(self)

  api:VoteTag(self.params.postID, self.params.tagID, 'down')
  return 'meep'

end

local function HashIsValid(self)
  local realHash = ngx.md5(self.params.postID..self.session.userID)
  if realHash ~= self.params.hash then
    ngx.log(ngx.ERR, 'hashes dont match!')
    return false
  end
  return true
end


local function UpvotePost(self)
  if not HashIsValid(self) then
    return 'invalid hash'
  end
  local ok, err = api:VotePost(self.session.userID, self.params.postID, 'up')
  if ok then
    return 'success!'
  else
    return 'fail: ', err
  end
end



local function DownvotePost(self)
  if not HashIsValid(self) then
    return 'invalid hash'
  end
  local ok, err = api:VotePost(self.session.userID, self.params.postID,'down')
  if ok then
    return 'success!'
  else
    return 'fail: ', err
  end
end

function m:Register(app)
  app:match('newpost','/post/new', respond_to({
    GET = CreatePostForm,
    POST = CreatePost
  }))
  app:get('upvotetag','/post/upvotetag/:tagID/:postID',UpvoteTag)
  app:get('upvotetag','/post/upvotetag/:tagID/:postID',DownvoteTag)
  app:get('viewpost','/post/:postID',GetPost)
  app:get('/test',CreatePost)
  app:post('newcomment','/post/comment/',CreateComment)
  app:get('upvotepost','/post/:postID/upvote', UpvotePost)
  app:get('downvotepost','/post/:postID/downvote', DownvotePost)

end

return m
