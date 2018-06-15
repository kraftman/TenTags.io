
package.path = package.path.. "../?.lua;./testing/lib/?.lua;;./controllers/?.lua;;./lib/?.lua;;";

local redisBase = require 'fakeredis'
local redisread = require 'redis.userread'

describe('tests redisread', function()

  it('tests GetNewUsers', function()
    redisBase:createMock('zrange', {1, 'test'})
    local ok = redisread:GetNewUsers('test');

    assert.are.same({'test'}, ok);
  end)
  it('tests GetUserAlerts', function()
    redisBase:createMock('zrangebyscore', {1, 'test'})
    local ok = redisread:GetUserAlerts('userID', 0, 10);

    assert.are.same({1, 'test'}, ok);
  end)

  it('tests SavedPostExists', function()
    redisBase:createMock('sismember', true)
    local ok = redisread:SavedPostExists('test');

    assert.are.same(true, ok);
  end)
  it('tests GetUserCommentVotes', function()
    redisBase:createMock('smembers', {'vote1'})
    local ok = redisread:GetUserCommentVotes('test');

    assert.are.same({'vote1'}, ok);
  end)

  it('tests GetAccount', function()
    local fakeAccount = {
      'user:kraftman', 'userID',
      'session:', 'sessionID'
    }

    function redisBase:from_json()
      return {id = 'sessionID'}
    end

    redisBase:createMock('hgetall', fakeAccount)
    local ok = redisread:GetAccount('test')

    assert.are.same({id = 'sessionID'}, ok.sessions.sessionID)
  end)

  it('tests GetUserTagVotes', function()
    redisBase:createMock('smembers', {'vote1'})
    local ok = redisread:GetUserTagVotes('test');

    assert.are.same({'vote1'}, ok);
  end)

  it('tests GetRecentPostVotes', function()
    redisBase:createMock('zrange', {'vote1'})
    local ok = redisread:GetRecentPostVotes('test', 'up');

    assert.are.same({'vote1'}, ok);
  end)

  it('tests GetUserPostVotes', function()
    redisBase:createMock('smembers', {'vote1'})
    local ok = redisread:GetUserPostVotes('test', 'up');

    assert.are.same({'vote1'}, ok);
  end)

  it('tests GetUserID', function()
    redisBase:createMock('hget', {'vote1'})
    local ok = redisread:GetUserID('test', 'up');

    assert.are.same({'vote1'}, ok);
  end)

  it('tests GetUserComments', function()
    redisBase:createMock('zrange', {'vote1'})
    local ok = redisread:GetUserComments('test', 'top', 0, 1, 2)

    assert.are.same({'vote1'}, ok);
  end)

  it('tests GetUserPosts', function()
    redisBase:createMock('zrange', {'vote1'})
    local ok = redisread:GetUserPosts('test', 0, 10)

    assert.are.same({'vote1'}, ok);
  end)

  it('tests GetUnseenParentIDs', function()
    redisBase:createMock('BF.EXISTS', {'vote1'})
    redisBase:createMock('commit_pipeline', {postID = 0})
    local ok = redisread:GetUnseenParentIDs('test', {postID = {parentID = 'parentID'}})

    assert.are.same({parentID = true}, ok);
  end)

  it('tests GetBotScore', function()
    redisBase:createMock('zscore', 10)
    local ok = redisread:GetBotScore('userID')

    assert.are.same(10, ok);
  end)

  it('tests GetTopBots', function()
    redisBase:createMock('zrevrange', {1, 'userID'})
    local ok = redisread:GetTopBots(10)

    assert.are.same({'userID'}, ok);
  end)

  it('tests GetBotComments', function()
    redisBase:createMock('smembers', 'test')
    local ok = redisread:GetBotComments(10)

    assert.are.same('test', ok);
  end)

  it('gets a user', function()
    local fakeUser = {
      'username', 'kraftman'
    }
    redisBase:createMock('hgetall', fakeUser)
    local ok = redisread:GetUser('userID')

    assert.are.same(false, ok.allowMentions);
    assert.are.same(false, ok.allowSubs);
    assert.are.same(false, ok.enablePM);
  end)

end)