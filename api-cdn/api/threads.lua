
local cache = require 'api.cache'
local util = require 'api.util'
local uuid = require 'lib.uuid'
local worker = require 'api.worker'
local redisWrite = requrie 'api.rediswrite'

local api = {}

function api:GetThread(threadID)
  return cache:GetThread(threadID)
end


function api:GetThreads(userID)
  return cache:GetThreads(userID)
end




-- just checks the sender is correct
function api:VerifyMessageSender(userID, messageInfo)
	messageInfo.createdBy = messageInfo.createdBy or userID
	if userID ~= messageInfo.createdBy then
		local user = cache:GetInfo(userID)
		if not user then
			return nil, 'could not find user'
		end
    --dissallow spoofing sender unless admin
		if user.role and user.role ~= 'Admin' then
			messageInfo.createdBy = userID
		end
	end
	return true
end




function api:CreateMessageReply(userID, userMessage)
	local newMessage, ok, err

	newMessage, err = self:ConvertUserMessageToMessage(userID, userMessage)

	if not newMessage then
		return newMessage, err
	end

  ok, err = redisWrite:CreateMessage(userMessage)
	if not ok then
		return ok, err
	end

  local thread = cache:GetThread(newMessage.threadID)
  for _,viewerID in pairs(thread.viewers) do
    if viewerID ~= newMessage.createdBy then
      userWrite:AddUserAlert(viewerID, 'thread:'..thread.id..':'..newMessage.id)
    end
  end

end


function api:ConvertUserMessageToMessage(userID, userMessage)
	if not userMessage.threadID then
		return nil, 'no thread id'
	end

	if not userMessage.createdBy then
		userMessage.createdBy = userID
	end

	local newInfo = {
		threadID = util:SanitiseUserInput(userMessage.threadID, 200),
		body = util:SanitiseUserInput(userMessage.body, 2000),
		id = uuid.generate_random(),
		createdAt = ngx.time(),
		createdBy = util:SanitiseUserInput(userMessage.createdBy)
	}

	local ok, err = self:VerifyMessageSender(userID, newInfo)
	if not ok then
		return ok, err
	end

	return newInfo
end



function api:CreateThread(userID, messageInfo)


	local ok, err = util.RateLimit('CreateThread:', userID, 2, 60)
	if not ok then
		return ok, err
	end

	local ok, err = self:VerifyMessageSender(userID, messageInfo)
	if not ok then
		return nil, err
	end


	messageInfo.title = messageInfo.title or ''
	messageInfo.body = messageInfo.body or ''

	if messageInfo.title:gsub(' ','')== '' or messageInfo.body:gsub(' ','') == '' then
		return nil, 'blank message!'
	end


  local recipientID = cache:GetUserID(messageInfo.recipient)
	if not recipientID then
		ngx.log(ngx.ERR, 'user not found: ',messageInfo.recipint)
		return nil, 'couldnt find recipient user'
	end

  local thread = {
    id = uuid.generate_random(),
    createdBy = messageInfo.createdBy,
    createdAt = ngx.time(),
    title = util:SanitiseHTML(messageInfo.title),
    viewers = {messageInfo.createdBy,recipientID},
    lastUpdated = ngx.time()
  }

  local msg = {
    id = uuid.generate_random(),
    createdBy = messageInfo.createdBy,
    body = util:SanitiseHTML(messageInfo.body),
    createdAt = ngx.time(),
    threadID = thread.id
  }

  ok, err = redisWrite:CreateThread(thread)
	if not ok then
		return ok, err
	end

  ok, err = redisWrite:CreateMessage(msg)
	if not ok then
		return ok, err
	end

  ok, err = userWrite:AddUserAlert(recipientID, 'thread:'..thread.id..':'..msg.id)
	return ok, err
end

return api
