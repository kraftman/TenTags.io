package.path = package.path.. "../?.lua;./testing/lib/?.lua;;./controllers/?.lua;;./lib/?.lua;;";


-- local redis = require 'redis.redisread'
 local cache = require 'api.cache'
-- local lapis = require 'lapis.application'
-- local userLib = require 'lib.userlib'
-- local userAPI = require 'api.users'
 local mockuna = require 'mockuna'
-- local mockBase  = require 'api.base

local comment = require 'api.comments'


describe('test VoteComment', function()
  before_each(function() 
    mockuna:stub(cache, 'GetUser', function() return {role = 'Admin'} end)
    mockuna:stub(cache, 'GetUserCommentVotes', function() return {} end)
    mockuna:stub(comment, 'QueueUpdate', function() return true end)
  end)

  after_each(function() 
    cache.GetUser:restore()
    cache.GetUserCommentVotes:restore()
    comment.QueueUpdate:restore()
  end)

  it('tests valid tag', function() 
    local ok = comment:VoteComment('userID', 'postID', 'commentID', 'funny')
    assert.are.same('commentID', ok.commentID)
    assert.are.same('userID:commentID', ok.id)  
    assert.are.same('postID', ok.postID)
    assert.are.same('funny', ok.tag)
    assert.are.same('userID', ok.userID)
    assert.True(comment.QueueUpdate.calledOnce)
  end)

  it('tests an invalid tag', function()
    local ok, err = comment:VoteComment('userID', 'postID', 'commentID', 'invalid')
    assert.are.equal(err, 'invalid tag')
    assert.False(comment.QueueUpdate.called)
  end)
end)

describe('test SubscribeComment', function() 
  before_each(function() 
    mockuna:stub(comment.redisWrite, 'QueueJob', function() return true end)
  end)

  after_each(function() 
    comment.redisWrite.QueueJob:restore()
  end)

  it('tests SubscribeComment', function() 
    local ok = comment:SubscribeComment('userID', 'postID', 'commentID')
    assert.are.same(true, ok)
  end)
end)

describe('test getbotcomments', function() 
  before_each(function() 
    mockuna:stub(cache, 'GetBotComments', function() return true end)
  end)

  after_each(function() 
   cache.GetBotComments:restore()
  end)

  it('tests GetBotComments', function() 
    local ok = comment:GetBotComments('userID', 'postID', 'commentID')
    assert.are.same(true, ok)
  end)
end)

describe('test getbotcomments', function() 
  before_each(function() 
    local fakeUser = {allowMentions = true, id = 1}
    mockuna:stub(cache, 'GetUserByName', function() return {'kraftman', allowMentions = true} end)
    mockuna:stub(comment.userWrite, 'AddUserAlert', function() return true end)
  end)

  after_each(function() 
   cache.GetUserByName:restore()
   comment.userWrite.AddUserAlert:restore()
  end)

  it('tests process mentions', function() 
    local oldComment = {text = 'old comment', id = 3}
    local newCommment = {text = 'new @kraftman', id = 4, postID = 'postID'}
    local ok = comment:ProcessMentions(oldComment, newCommment)
    assert.are.same(nil, ok)
    assert.True(comment.userWrite.AddUserAlert.calledOnce)
  end)
end)

describe('test GetComment', function() 
  before_each(function() 
    mockuna:stub(cache, 'ConvertShortURL', function() return 'commentID:postID' end)
    mockuna:stub(cache, 'GetComment', function() return 'myComment' end)
  end)

  after_each(function() 
    cache.ConvertShortURL:restore()
    cache.GetComment:restore()
  end)

  it('tests process mentions', function() 
    local ok = comment:GetComment('postID', 'commentID')
    assert.are.same('myComment', ok)
  end)
end)
