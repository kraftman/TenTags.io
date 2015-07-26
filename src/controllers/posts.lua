

local uuid = require 'uuid'
local db = require("lapis.db")
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
    text = self.params.text
  }
  local res = db.insert('post', info)

  for _, tagID in pairs(selected) do
    local postTagInfo = {
      itemID = info.id,
      tagID = tagID,
      up = 0,
      down = 0,
      date = ngx.time()
    }
    local res = db.insert('itemtags', postTagInfo)
  end


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

    local comments = db.select([[
      c.text,c.id,u.username,c.parentID,c.up,c.down from comment c
      inner join user u
      on c.userID = u.id
      WHERE c.postID = ?]],postID)
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
      return (a.up+a.down > b.up+b.down)
    end)
  end

  local tree = AddChildren(postID,flat)
  print(to_json(tree))
  return tree,indexedComments
end

local function RenderComment(comments,commentTree,text)
  local t = text or ''


  for k,v in pairs(commentTree) do
    --print(k,type(v),to_json(v))
    t = t..'<div id="comment">\n'
    t = t..'  <div id="commentinfo" >\n'..(comments[k].text or 'no text')..'\n  </div>\n'
    if next(v) then
      t = t..'<div id="commentchildren">'
      t = t..RenderComment(comments,v)
      t = t..'</div>'
    end
    t = t..'</div>\n'
  end
  --print('found:',t)
  return t
end

local function RenderComments(self)
  return RenderComment(self.comments,self.commentTree)
end

local function GetPost(self)

  local tree,comments = GetComments(self.params.postID)
  if tree then
    print('tree found')
  end
  self.commentTree = tree
  self.comments = comments
  self.RenderComments = RenderComments

  local post = db.select('* from post where id = ?',self.params.postID)
  post = post[1]
  self.post = post
  return {render = 'post'}
end

local function CreatePostForm(self)
  local res = db.select('* from tag ')

  self.tags = res

  return { render = 'createpost' }
end

local function CreateComment(self)

  local newCommentID = uuid.generate_random()

  local commentInfo = {
    id = newCommentID,
    parentID = self.params.parentID,
    postID = self.params.postID,
    userID = self.session.current_user_id,
    text = self.params.commentText,
    date = ngx.time(),
  }
  local res = db.insert('comment',commentInfo)
  res = db.query('update post set commentCount = commentCount +1 where id = ?',self.params.postID)

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
