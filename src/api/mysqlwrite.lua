

local dal = {}
local mysql = require "resty.mysql"


local function GetMysqlConnection()
  local db, err = mysql:new()
  db:set_timeout(1000)
  local ok, err, errno, sqlstate = db:connect{
    host = "127.0.0.1",
    port = 3306,
    database = "taggr",
    user = "root",
    password = "meep",
    max_packet_size = 1024 * 1024 }
  if not ok then
    ngx.log(ngx.ERR, "failed to connect: ", err, ": ", errno, " ", sqlstate)
    return ngx.exit(500)
  end
  return db
end

local safeQuote = ngx.quote_sql_str

function dal:CreateTag(tagInfo)
  local db = GetMysqlConnection()
  local query = "REPLACE INTO tag set "..
                'id = '..safeQuote(tagInfo.id)..','..
                'name = '..safeQuote(tagInfo.name)..','..
                'createdAt = '..safeQuote(tagInfo.createdAt)..','..
                'createdBy = '..safeQuote(tagInfo.createdBy or 'default')
  local res, err = db:query(query)
  if not res then
    ngx.log(ngx.ERR, 'error writing tag to db: ',err)
    return
  end
  return res
end

function dal:CreatePost(postInfo)
  local db = GetMysqlConnection()
  local query = 'REPLACE INTO post set '..
              'id = '..safeQuote(postInfo.id)..
              ',parentID = '..safeQuote(postInfo.parentID)..
              ', title = '..safeQuote(postInfo.title)..
              ', link = '..safeQuote(postInfo.link)..
              ', text = '..safeQuote(postInfo.text)..
              ', createdAt = '..safeQuote(postInfo.createdAt)..
              ', createdBy = '..safeQuote(postInfo.createdBy)
  local ok, err = db:query(query)
  if not ok then
    ngx.log(ngx.ERR, 'unable to create post in mysql: ',err)
  end

  self:CreatePostTags(postInfo.id, postInfo.tags, postInfo.createdBy)
end

function dal:CreatePostTags(postID, tags, createdBy)
  local db = GetMysqlConnection()
  for k,v in pairs(tags) do
    local query = 'REPLACE INTO posttags set '..
                'postID = '..safeQuote(postID)..
                ', tagID = '..safeQuote(v.id)..
                ', up = '..safeQuote(v.up)..
                ', down = '..safeQuote(v.down)..
                ', score = '..safeQuote(v.score)..
                ', active = '..safeQuote(v.active and '1' or '0')..
                ', createdAt = '..safeQuote(ngx.time())..
                ', createdBy = '..safeQuote(createdBy)
    local ok, err = db:query(query)
    if not ok then
      ngx.log(ngx.ERR, 'unable to write posttag: ',err)
    end
  end
end

function dal:CreateFilter(filterInfo)
  local db = GetMysqlConnection()
  local query = 'REPLACE INTO post set'..
              ' id = '..safeQuote(filterInfo.id)..
              ', label = '..safeQuote(filterInfo.label)..
              ', description = '..safeQuote(filterInfo.description)..
              ', ownerID = '..safeQuote(filterInfo.ownerID)..
              ', createdAt = '..safeQuote(filterInfo.createdAt)..
              ', createdBy = '..safeQuote(filterInfo.createdBy)
  local ok, err = db.query(query)
  if not ok then
    ngx.log(ngx.ERR, 'unable to create post in mysql: ',err)
  end
end

function dal:CreateFilterTags(tags)
  local db = GetMysqlConnection()
  for k,v in pairs(tags) do

  end

end



return dal

--[=[

local db = require("lapis.db")
local DAL = {}


function DAL:GetUserFrontPage()

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

function DAL:LoadDefaultFilters()
  local query = 'select * from filter'
  return db.query(query)
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
  local res = db.select("* from user where username = ?", username)
  return res[1]
end

function DAL:LoadFilter(filterlabel)
  local res = db.select('* from filter where label = ?',filterlabel)
  return res[1]
end

function DAL:LoadUserByEmail(email)
  local res = db.select("* from user where email = ?", email)
  return res[1]
end

function DAL:ActivateUser(userID)
  print('activating user')
  local res = db.query('UPDATE user set active = 1 where id = ?',userID)
end

function DAL:LoadUserCredentialsByEmail(email)
  local res = db.select("* from user where email = ?", email)
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

function DAL:GetPostTags(postID)
  local query = [[select t.id, t.name,pt.up,pt.down from posttags pt
      inner join tag t
      on t.id = pt.tagID
      where pt.postID = ']]..postID.."'"
  local res = db.query(query)

  return res
end

function DAL:GetPost(postID)
  return db.select('* from post where id = ?',postID)
end

function DAL:GetPostTag(tagID,postID)
  local query = "select * from posttags where tagID = '"..tagID..
  "' and postID = '"..postID.."'"
  local res = db.query(query)
  return res[1]
end

function DAL:GetCommentsForPost(postID)
  return db.select([[
    c.text,c.id,u.username,c.parentID,c.up,c.down,c.createdAt from comment c
    inner join user u
    on c.createdBy = u.id
    WHERE c.postID = ?]],postID)
end

function DAL:CreatePost(postDetails,tags)

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

function DAL:CreateFilter(filterInfo,tags)
  local res = db.insert('filter',filterInfo)

  for _,tagInfo in pairs(tags) do
    res = db.insert('filtertags',tagInfo)
  end
end

function DAL:UpdatePostTag(postTag)
  local query = [[
    update posttags set
    up = ']]..postTag.up..[[',
    down = ']]..postTag.down..[[',
    score = ']]..postTag.score..[['
    where postID = ']]..postTag.postID..[['
    and tagID = ']]..postTag.tagID..[['

    ]]

  db.query(query)
end

function DAL:LoadAllFilters()
  return db.select('* from filter')
end

function DAL:LoadFilterTags(filterLabel)
  return db.select([[
    t.id, t.name,ft.filterType from filter f
    inner join filtertags ft
    on ft.filterID = f.id
    inner join tag t
    on t.id = ft.tagID
    where f.label = ?
  ]],filterLabel)
end

function DAL:LoadFilteredPosts(requiredTags,bannedTags)
    local required = "'"..table.concat(requiredTags,"','").."'"
    local banned = "'"..table.concat(bannedTags,"','").."'"

    local query = [[
    select p.id,p.title from post p
    where p.id in
    	( SELECT  postID from posttags
    	where tagID in (]]..required..[[)
    	group by postID
    	having count(DISTINCT tagID) = ]]..#requiredTags..[[)
    and p.id not in (
  		SELECT postID from posttags
  		where tagID in (]]..banned..[[)
  		group by postID
      )
    ]]
    print(query)
    local res = db.query(query)
    return res

end

return DAL


--]=]
