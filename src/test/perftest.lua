--[[
100 posts with 10k comments = 240Mb in lru
100 posts with 1k comments = 24mb in lru


--]]
local tinsert, random = table.insert, math.random
local api = require 'api.api'
local redisWrite = require 'api.rediswrite'
local lru = require 'api.lrucache'

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
  for k,v in pairs(new) do
    i = i+1
  end
  ngx.say('</br> found: ',i, ' iter: ',numIt)
end

function ShowGC()
  ngx.say(string.format("Worker %d: GC size: %.3f KB", ngx.var.pid, collectgarbage("count")))
end

function m:Register(app)
  app:get('/test/posts',TestPosting)
  app:get('/test/comments',TestComments)
  app:get('/gc', ShowGC)
end

return m
