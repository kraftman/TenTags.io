--[[
100 posts with 10k comments = 240Mb in lru
100 posts with 1k comments = 24mb in lru


--]]
local tinsert, random = table.insert, math.random
local api = require 'api.api'
local redisWrite = require 'api.rediswrite'
local lru = require 'api.lrucache'
local cache = require 'api.cache'

local to_json = (require 'lapis.util').to_json
local from_json = (require 'lapis.util').from_json
local uuid = require 'lib.uuid'
local locks = ngx.shared.locks

local m = {}

local function TestPosting(self)
  local ok, err

  for j = 1, 10000 do
    if j % 1000 == 0 then
      print(j)
    end

    local selectedTags = {}
    for i = 1, random(10) do
      tinsert(selectedTags,'testtag'..i)
    end
    tinsert(selectedTags,'arst')

    self.params.link = 'http://test.com/thene some ohter long stuff'..random(1,100)

    local info ={
      id = newID,
      title = 'my fairly average post title made from normal words like maybe a twitter post or something'..ngx.time()..random(100),
      link = self.params.link,
      text = [[ an average comment lenght of maybe 200 characters an average comment lenght of maybe 200 characters
                an average comment lenght of maybe 200 characters
                an average comment lenght of maybe 200 characters
                an average comment lenght of maybe 200 characters
              ]],
      createdAt = ngx.time(),
      createdBy = 'default',
      tags = selectedTags
    }

    ok, err = api:CreatePost(self.session.userID, info)
    if not ok then
      ngx.log(ngx.ERR, 'error from api: ',err or 'none')
      return {status = 500}
    end

  end
  return string.format("</br>Worker %d: GC size: %.3f KB", ngx.var.pid, collectgarbage("count"))



end

local function TestComments()
    local comment
    -- write all the comments
  local numIt =  locks:get('pc')
  if not numIt then
    locks:set('pc',0)
  end
  locks:incr('pc',1)

  local postID = uuid.generate_random()
  local tempComments = {}
  for i = 1, 1000 do
    comment = {}
    comment.id = 'ariosetnoairsenoiarestaiorseooia'..i
    comment.text = 'aernstoiearnstioeranstioernstiearnstoiestnaioresiaorsenarsitonsrtatraernstoiearnstioeranstioernstiearnstoiestnaioresiaorsenarsitonsrtatraernstoiearnstioeranstioernstiearnstoiestnaioresiaorsenarsitonsrtatr'
    comment.up = random(1000)
    comment.down =  random(1000)
    comment.userid = 'oairestoiarsetoairoseniarestn'..i
    comment.postID = 'oairestoiarsetoairoeniarestn'..i
    tinsert(tempComments,comment)
  end

  lru:SetComments(postID,tempComments)
  ngx.say(string.format("</br>Worker %d: GC size: %.3f KB", ngx.var.pid, collectgarbage("count")))

  local new = lru:GetComments(postID)
  local i = 1
  for _,_ in pairs(new) do
    i = i+1
  end
  ngx.say('</br> found: ',i, ' iter: ',numIt)
end

function ShowGC()
  ngx.say(string.format("Worker %d: GC size: %.3f KB", ngx.var.pid, collectgarbage("count")))
end

local function TestUserSharedDict(self)
  local i  = 0
  local subUser
  local serialUser
  local succ, err, forced

  local testDict = ngx.shared.testusers

  while true do
    i = i + 1
    if i % 100 == 0 then
      print(i)
    end

    subUser = {
      id = uuid.generate(),
      username = uuid.generate(),
      filters = cache:GetUserFilterIDs('default'),
      parentID = uuid.generate(),
      enablePM = 1,
    }
    serialUser = to_json(subUser)
    succ, err, forced = testDict:set(subUser.id, serialUser)
    if forced then
      return 'max users: '..i
    end
  end
end

local function TestUserIDsSharedDict(self)
  local i  = 0
  local succ, err, forced

  local testDict = ngx.shared.testusers

  while true do
    i = i + 1
    if i % 100 == 0 then
      print(i)
    end

    succ, err, forced = testDict:set(uuid.generate_random(), uuid.generate_random())
    if forced then
      return 'max users: '..i
    end
  end
end

local function TestPosting(self)

  local count = 0
  local info, serialInfo
  local selectedTags


  local testDict = ngx.shared.testusers
  local succ, err, forced

  while true do
    count = count +1
    if count % 100 == 0 then
      print(count)
    end

    selectedTags = {}
    for i = 1, random(10) do
      tinsert(selectedTags,'testtag'..i)
    end

    tinsert(selectedTags,'arst')

    self.params.link = 'http://test.com/thene some other long stuff'..random(1,100)

    info ={
      id = uuid.generate_random(),
      parentID = uuid.generate_random(),
      title = 'my fairly average post title made from normal words like maybe a twitter post or something'..ngx.time()..random(100),
      link = self.params.link,
      text = [[ an average comment lenght of maybe 200 characters an average comment lenght of maybe 200 characters
                an average comment lenght of maybe 200 characters
                an average comment lenght of maybe 200 characters
                an average comment lenght of maybe 200 characters
              ]],
      createdAt = ngx.time(),
      createdBy = uuid.generate_random(),
      tags = selectedTags,
      commentCount = 1000;
    }

    serialInfo = to_json(info)
    succ, err, forced = testDict:set(info.id, serialInfo)
    if forced then
      return 'max posts: '..count
    end
  end
end

local function TestCommentDict()
  local i  = 0
  local comment
  local serialComment
  local succ, err, forced

  local testDict = ngx.shared.testusers

  while true do
    i = i + 1
    if i % 100 == 0 then
      print(i)
    end

    comment = {
      id = 'ariosetnoairsenoiarestaiorseooia'..i,
      text = 'aernstoiearnstioeranstioernstiearnstoiestnaioresiaorsenarsitonsrtatraernstoiearnstioeranstioernstiearnstoiestnaioresiaorsenarsitonsrtatraernstoiearnstioeranstioernstiearnstoiestnaioresiaorsenarsitonsrtatr',
      up = random(1000),
      down =  random(1000),
      score = random(1000),
      userid = uuid.generate_random(),
      postID = uuid.generate_random(),
      createdAt = 1447001826,
      createdBy = uuid.generate_random(),
      viewers = {},
      parentID = uuid.generate_random(),

    }
    for _ = 1, random(4) do
      tinsert(comment.viewers, 'aroisetoiarsetoairestoairseaeiorsn')
    end

    serialComment = to_json(comment)
    succ, err, forced = testDict:set(comment.id, serialComment)
    if forced then
      return 'max users: '..i
    end
  end

end

local function TestRate()
  local rate = ngx.shared.ratelimit
  local count = 0
  local ok, err, forced

  while true do
    count = count + 1
    if count % 100 == 0 then
      print(count)
    end

    ok, err,forced = rate:set('userupdateten:'..uuid.generate_random(), random (5, 10))
    if forced then
      return 'max rate keys: '..count
    end

  end
end


local function TestGenerate(self)
  for i = 1, 100 do
    local info ={
      title = 'test title'..i,
      name= 'testname'..i ,
      description = 'testdescription'..i,
      createdAt = ngx.time(),
      ownerID = self.session.userID,
      createdBy = self.session.userID,
    }
    info.bannedTagNames = {}
    info.requiredTagNames = {}
    for j = 1, 30 do
      info.requiredTagNames[j] = 'requiredtag'..j
      info.bannedTagNames[j] = 'bannedtag'..j
    end


    local ok, err = api:CreateFilter(self.session.userID, info)
    print(ok, err)
  end

  for i = 1, 100 do
    local info ={
      title = 'newpost'..i,
      text = 'newpostbody'..i,
      createdBy = self.session.userID,
      tags = {}
    }
    for j = 1, 30 do
      info.tags[j] = 'requiredtag'..j
    end
    local ok, err = api:CreatePost(self.session.userID, info)
  end


end

function m:Register(app)

  app:get('/test/generaterandom', TestGenerate)
  app:get('/test/rate',TestRate)
  app:get('/test/posts',TestPosting)
  app:get('/test/comments',TestComments)
  app:get('/test/users',TestUserIDsSharedDict)
  app:get('/gc', ShowGC)
end

return m
