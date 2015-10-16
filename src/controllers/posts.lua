

local api = require 'api.api'
local util = require("lapis.util")

local from_json = util.from_json
local to_json = util.to_json

local m = {}

local respond_to = (require 'lapis.application').respond_to
local trim = util.trim

local tinsert = table.insert

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



local function RenderComment(self,comments,commentTree,text)
  local t = text or ''


  for k,v in pairs(commentTree) do
    --print(k,type(v),to_json(v))
    t = t..'<div class="comment">\n'
    t = t..'  <div class="commentinfo" >\n'..
    '<a href="'..self:url_for('viewuser',{username = comments[k].username})..'">'..comments[k].username..'</a>   '..
    '<a href="'..self:url_for('subscribecomment',{postID = self.params.postID, commentID = comments[k].id})..'">subscribe</a>   '..
    '<a href="'..self:url_for('viewcomment',{postID = self.params.postID, commentID = comments[k].id})..'">reply</a>'..
              '\n  </div>\n'
    t = t..'  <div id="commentinfo" >\n'..(comments[k].text )..'\n  </div>\n'
    if comments[k].filters then
      for _,filter in pairs(comments[k].filters) do
        t = t..' filter: '..(filter.title or '')
      end
    end

    if next(v) then
      t = t..'<div id="commentchildren">'
      t = t..RenderComment(self,comments,v)
      t = t..'</div>'
    end
    t = t..'</div>\n'
  end
  --print('found:',t)
  return t
end

local function RenderComments(self)
  return RenderComment(self,self.comments,self.commentTree)
end

local function GetPost(self)

  local tree,comments = api:GetPostComments(self.params.postID)
  if tree then
    --print('tree found')
  end
  self.commentTree = tree
  self.comments = comments
  self.RenderComments = RenderComments

  local post = api:GetPost(self.params.postID)

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
    --return 'failed!'
  end

end


local function UpvoteTag(self)
  local postTag = cache:GetPostTag(self.params.tagID,self.params.postID)
  -- increment the post count
  -- check if the user has already up/downvoted
  postTag.up = postTag.up + 1
  local oldScore = postTag.score or 0
  local newScore = score:BestScore(postTag.up,postTag.down)

  postTag.score = newScore
  cache:UpdatePostTag(postTag)
  print(postTag.up,postTag.down,'  ',newScore)

  --recalculate the tags score
  if postTag.score > 0.1 and postTag.active == 0 then
    --activate the tag
    -- check any filters that need it and add them
  elseif postTag.score < -5 and postTag.active == 1 then
    --deactivate the tag
    -- check any filters that need it remove and remove it
  end
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

end

return m
