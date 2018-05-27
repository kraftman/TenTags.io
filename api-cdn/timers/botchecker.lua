
local CONFIG_CHECK_INTERVAL = 5

local config = {}
config.__index = config
config.http = require 'lib.http'
config.cjson = require 'cjson'

local userAPI = require 'api.users'
local tagAPI = require 'api.tags'
local cache = require 'api.cache'

local updateDict = ngx.shared.updateQueue
local tinsert = table.insert
local to_json = (require 'lapis.util').to_json
local from_json = (require 'lapis.util').from_json
local BOT_SCORE_THRESHOLD = 2


local common = require 'timers.common'
setmetatable(config, common)


function config:New(util)
  local c = setmetatable({},self)
  c.util = util
	c.common = common
	math.randomseed(ngx.now()+ngx.worker.pid())
	math.random() math.random() math.random()

  return c
end

function config.Run(_,self)
  local ok, err = ngx.timer.at(CONFIG_CHECK_INTERVAL, self.Run, self)
  if not ok then
    if not err:find('process exiting') then
      ngx.log(ngx.ERR, 'WARNING: unable to reschedule postupdater: '..err)
    end
  end

  -- no need to lock since we should be grabbing a different one each time anyway
	self.startTime = ngx.now()
  self:ProcessJob('CheckSpam:Comment', 'CheckCommentSpam')


end

function config:CheckCommentSpam(commentJob)
  local unique, comment, err
  local postID, commentID = commentJob.id:match('(%w+):(%w+)')
  if not postID or not commentID then
    return true
  end
  comment, err = self.commentRead:GetComment(postID, commentID)
  if not comment then
    return comment, err
  end

  unique, err = self.commentWrite:IsUnique('bloom:comment:body', comment.text)
  if err then
    return nil, err
  end
  if unique then
    print('comment is unique: ', comment.text)
    return true
  end

  local userBotScore, err = self.userRead:GetBotScore(comment.createdBy)
  if err then
    return userBotScore, err
  end
  
  userBotScore = userBotScore + 1
  print('bot score:', userBotScore)
  local ok, err = self.userWrite:SetBotScore(comment.createdBy, userBotScore)
  if not ok then
    return ok, err
  end

  if userBotScore > BOT_SCORE_THRESHOLD then
    ok, err = self.userWrite:AddBotComments(comment)
    if not ok then
      return ok, err
    end
  end


  return true

end








return config
