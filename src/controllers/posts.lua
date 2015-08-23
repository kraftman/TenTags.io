

local uuid = require 'uuid'
local DAL = require 'DAL'
local util = require("lapis.util")

local from_json = util.from_json
local to_json = util.to_json

local m = {}

local respond_to = (require 'lapis.application').respond_to
local trim = util.trim

local tinsert = table.insert

local function CreatePost(self)

  local selected = from_json(self.params.selectedtags)
  local newID =  uuid.generate_random()

  if trim(self.params.link) == '' then
    self.params.link = nil
  end


  local info ={
    id = newID,
    title = self.params.title,
    link = self.params.link or self:url_for('viewpost',{postID = newID}),
    text = self.params.text,

    createdAt = ngx.time(),
    createdBy = self.session.current_user_id
  }
  local tags = {}

  for _, tagID in pairs(selected) do
    local tagInfo = {
      postID = info.id,
      tagID = tagID,
      up = 1,
      down = 0,
      createdAt = ngx.time(),
      createdBy = self.session.current_user_id
    }
    table.insert(tags,tagInfo)
  end

  DAL:CreatePost(info,tags)

  return {json = self.req.selectedtags}
end

local function AddChildren(parentID,flat)
  local t = {}
  for k,v in pairs(flat[parentID]) do
    t[v.id] = AddChildren(v.id,flat)
  end

  return t
end

local function GetComments(postID)

  local comments = DAL:GetCommentsForPost(postID)
  print('getting comments for post ',postID,' found: ',#comments)

  for k,v in pairs(comments) do
    print(v.text)
  end
  local flat = {}
  flat[postID] = {}
  local indexedComments = {}

  for k,v in pairs(comments) do
    if not flat[v.parentID] then
      flat[v.parentID] = {}
    end
    if not flat[v.id] then
      flat[v.id] = {}
    end
    tinsert(flat[v.parentID],v)
    indexedComments[v.id] = v
  end

  for k,v in pairs(flat) do
    table.sort(v,function(a,b)
      if a.up+a.down == b.up+b.down then
        return a.date > b.date
      end
      return (a.up+a.down > b.up+b.down)
    end)
  end

  local tree = AddChildren(postID,flat)
  print(to_json(tree))
  return tree,indexedComments
end

local function RenderComment(self,comments,commentTree,text)
  local t = text or ''


  for k,v in pairs(commentTree) do
    --print(k,type(v),to_json(v))
    t = t..'<div class="comment">\n'
    t = t..'  <div class="commentinfo" >\n'..'<a href="'..
              self:url_for('viewuser',{username = comments[k].username})..'">'..comments[k].username..'</a>'..'\n  </div>\n'
    t = t..'  <div id="commentinfo" >\n'..(comments[k].text )..'\n  </div>\n'
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

  local tree,comments = GetComments(self.params.postID)
  if tree then
    print('tree found')
  end
  self.commentTree = tree
  self.comments = comments
  self.RenderComments = RenderComments

  local post = DAL:GetPost(self.params.postID)
  post = post[1]
  self.post = post
  return {render = 'post'}
end

local function CreatePostForm(self)

  self.tags = DAL:GetAllTags()

  return { render = 'createpost' }
end

local function CreateComment(self)

  local newCommentID = uuid.generate_random()

  local commentInfo = {
    id = newCommentID,
    parentID = self.params.parentID,
    postID = self.params.postID,
    createdBy = self.session.current_user_id,
    text = self.params.commentText,
    createdAt = ngx.time(),
  }
  DAL:CreateComment(commentInfo,self.params.postID)
  return 'created!'

end

function m:Register(app)
  app:match('newpost','/post/new', respond_to({
    GET = CreatePostForm,
    POST = CreatePost
  }))

  app:get('viewpost','/post/:postID',GetPost)
  app:get('/test',CreatePost)
  app:post('newcomment','/post/comment/',CreateComment)

end

return m
