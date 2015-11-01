

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
  print(to_json(post))
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
  local postTag = api:GetPostTag(self.params.tagID,self.params.postID)
  -- increment the post count
  -- check if the user has already up/downvoted
  postTag.up = postTag.up + 1
  --local oldScore = postTag.score or 0
  local newScore = api:GetScore(postTag.up,postTag.down)

  postTag.score = newScore
  api:UpdatePostTag(postTag)
  print(postTag.up,postTag.down,'  ',newScore)

  --recalculate the tags score
  --if postTag.score > 0.1 and postTag.active == 0 then
    --activate the tag
    -- check any filters that need it and add them
  --elseif postTag.score < -5 and postTag.active == 1 then
    --deactivate the tag
    -- check any filters that need it remove and remove it
  --end
end

local function UpvotePost(self)

end

function m:Register(app)
  app:match('newpost','/post/new', respond_to({
    GET = CreatePostForm,
    POST = CreatePost
  }))
  app:get('upvotetag','/post/upvotetag/:tagID/:postID',UpvoteTag)
  app:get('viewpost','/post/:postID',GetPost)
  app:get('/test',CreatePost)
  app:post('newcomment','/post/comment/',CreateComment)
  app:get('upvotepost','/post/:postID/upvote', UpvotePost)

end

return m
