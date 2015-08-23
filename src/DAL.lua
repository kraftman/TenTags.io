
local db = require("lapis.db")
local DAL = {}


function DAL:GetUserFrontPage()
  local query = [[SELECT p.id,p.title,p.link,p.commentCount
    from post p]]
  local posts = db.query(query)

  for _,post in pairs(posts) do
      post.tags = {}
      query = [[SELECT t.id,t.name from tag as t
                inner join posttags as pt
                on t.id = pt.tagID
                WHERE postID = ']]..post.id.."'"
      post.tags = db.query(query)
  end

  return posts
end

function DAL:AddTagsToPosts(posts)
  local query
  for _,post in pairs(posts) do
      post.tags = {}
      query = [[SELECT t.id,t.name from tag as t
                inner join posttags as pt
                on t.id = pt.tagID
                WHERE postID = ']]..post.id.."'"
      post.tags = db.query(query)
  end
  return posts
end

function DAL:LoadUserByUsername(username)
  local res = db.select("username,passwordHash,id from user where username = ?", username)
  return res[1]
end

function DAL:ActivateUser(userID)
  local res = db.query('UPDATE user set active = true where id = ?',userID)
end

function DAL:LoadUserCredentialsByEmail(email)
  local res = db.select("username,passwordHash,id from user where email = ?", email)
  return res[1]
end

function DAL:LoadDefaults()
  local query = [[SELECT p.id,p.title,p.link,p.commentCount
    from post p]]
  local posts = db.query(query)
  DAL:AddTagsToPosts(posts)
  return posts
end

function DAL:CreateUser(userInfo)
  db.insert('user',userInfo)
end

function DAL:GetUserComments(username)

  return db.select('* from comment c inner join user u on c.createdBy = u.id where u.username = ?',username)
end

function DAL:GetPost(postID)
  return db.select('* from post where id = ?',postID)
end

function DAL:GetCommentsForPost(postID)
  return db.select([[
    c.text,c.id,u.username,c.parentID,c.up,c.down,c.createdAt from comment c
    inner join user u
    on c.createdBy = u.id
    WHERE c.postID = ?]],postID)
end

function DAL:CreatePost(postDetails,tags)
  print(postDetails.title)
  local res = db.insert('post',postDetails)

  for _,tagInfo in pairs(tags) do
    res = db.insert('posttags',tagInfo)
    -- also need to add the fact that the user submitting has upvoted theses tags
  end
end

function DAL:GetAllTags()
  return db.select('* from tag ')
end

function DAL:CreateComment(commentInfo,postID)
  local res = db.insert('comment',commentInfo)
  res = db.query('update post set commentCount = commentCount +1 where id = ?',postID)
end

return DAL
