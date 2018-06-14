package.path = package.path.. "../?.lua;./testing/lib/?.lua;;./controllers/?.lua;;./lib/?.lua;;";


local mocker = require 'mocker'
local mockBase  = mocker:CreateMock('api.base')
local mockRedis = mocker:CreateMock('redis.redisread')
local mockCache = mocker:CreateMock('api.cache')
local mockLapis = mocker:CreateMock('lapis.application')

mockLapis:Mock('assert_error', function(self, ...)
  return self
end)

local comment = require 'api.comments'

mockBase:Mock('QueueUpdate', true);
mockBase.redisWrite = {
  QueueJob = function()
    return true
  end
}
mockBase.userWrite = {
  AddUserAlert = function()
    return true
  end
}

describe('tests comment api', function() 

  -- before_each(function()
    
  --   mockBase  = mocker:CreateMock('api.base')
  --   mockRedis = mocker:CreateMock('redis.redisread')
  --   mockCache = mocker:CreateMock('api.cache')
  --   mockLapis = mocker:CreateMock('lapis.application')
  -- end)

  it('tests VoteComment', function()
    mockCache:Mock('GetUser', {role = 'Admin'})
    mockCache:Mock('GetUserCommentVotes', {})
    local ok = comment:VoteComment('userID', 'postID', 'commentID', 'funny')
    assert.are.same('commentID', ok.commentID)
    assert.are.same('userID:commentID', ok.id)  
    assert.are.same('postID', ok.postID)
    assert.are.same('funny', ok.tag)
    assert.are.same('userID', ok.userID)

    
    local ok, err = comment:VoteComment('userID', 'postID', 'commentID', 'invalid')
    assert.are.equal(err, 'invalid tag')
  end)

  
  it('tests SubscribeComment', function()
    local ok = comment:SubscribeComment('userID', 'postID', 'commentID')
    assert.are.same(true, ok)
  end)

  it('gets bot comments', function()
    mockCache:Mock('GetBotComments', {})
    local ok = comment:GetBotComments('userID')
    assert.are.same({}, ok)
  end)

  it('Processes mentions', function()
    mockCache:Mock('GetUserByName', 'kraftman')
    local ok = comment:ProcessMentions({text = 'old comment'},{text = 'new @kraftman'})
    assert.are.same(nil, ok)
  end)


  it('Get Comment', function()
    mockCache:Mock('ConvertShortURL', 'commentID:postID')
    mockCache:Mock('GetComment', 'myComment')
    local ok = comment:GetComment('postID', 'commentID')
    assert.are.same('myComment', ok)
  end)
end)