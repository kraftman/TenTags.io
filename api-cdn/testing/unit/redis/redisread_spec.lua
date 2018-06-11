
package.path = package.path.. "../?.lua;./testing/lib/?.lua;;./controllers/?.lua;;./lib/?.lua;;";

local redisBase = require 'fakeredis'
local redisread = require 'redis.redisread'

describe('tests redisread', function()

  it('tests GetOldestJob', function()
    redisBase:createMock('zrevrange', {'test'})
    local oldest = redisread:GetOldestJob('test');
    
    assert.are.equal(oldest, 'test');
    --assert.are.equal(fakeRedis.zrevrange.calledWith, 'test')
  end)

  it('tests get queue size', function()
    redisBase:createMock('zcard', 'test')
    local qSize = redisread:GetQueueSize('fakeJob')
    assert.are.equal('test', qSize)
  end)

  it('test Getview', function()
    redisBase:createMock('hgetall', {});
    local view = redisread:GetView('viewID')
    assert.are.same(view.filters, { })
  end)

  it('test GetBacklogStats', function()
    redisBase:createMock('zrangebyscore', 'test');
    local view = redisread:GetBacklogStats('viewID')
    assert.are.same(view, 'test')
  end)

  it('test GetOldestJobs', function()
    redisBase:createMock('zrange', 'test');
    local view = redisread:GetOldestJobs('viewID')
    assert.are.same(view, 'test')
  end)

  it('test GetSiteUniqueStats', function()
    redisBase:createMock('zrevrange', {'test'});
    redisBase:createMock('pfcount', 'test');
    local view = redisread:GetSiteUniqueStats('viewID')
    assert.are.same(view, {test = 'test'})
  end)

  it('test GetSiteStats', function()
    redisBase:createMock('hgetall', {1, 'test'});
    local view = redisread:GetSiteStats('viewID')
    assert.are.same(view, {[1] = 'test'})
  end)

  it('test ConvertShortURL', function()
    redisBase:createMock('hget', 'test');
    local view = redisread:ConvertShortURL('test:url')
    assert.are.same(view, 'test')
  end)

  it('test GetInvalidationRequests', function()
    redisBase:createMock('zrangebyscore', 'test');
    local view = redisread:GetInvalidationRequests('test:url')
    assert.are.same(view, 'test')
  end)


  it('test GetFilterIDsByTags', function()
    redisBase:createMock('init_pipeline', true);
    redisBase:createMock('commit_pipeline', true);
    redisBase:createMock('hgetall', true);
    local view = redisread:GetFilterIDsByTags({})
    assert.are.same(view, true)
  end)

  it('test GetReports', function()
    redisBase:createMock('zrange', 'test');
    local view = redisread:GetReports(0, 10)
    assert.are.same(view, 'test')
  end)

  it('test GetRelevantFilters', function()
    redisBase:createMock('hgetall', {});
    local view = redisread:GetRelevantFilters({{name = 'test', up = 1}})
    assert.are.same(view, {})
  end)

  it('test VerifyReset', function()
    redisBase:createMock('get', 'test');
    local ok = redisread:VerifyReset('test', 'test')
    assert.are.same(ok, true)
  end)

  it('test GetTag', function()
    redisBase:createMock('hgetall', {'name', 'test'});
    local ok, err = redisread:GetTag('test')
    assert.are.same({name = 'test'}, ok)
  end)

  it('test GetAllTags', function()
    redisBase:createMock('smembers', {'tag1', 'tag2'});
    redisBase:createMock('hgetall', {'name', 'test'});
    redisBase:createMock('commit_pipeline', {{'name', 'test'}});
    local ok, err = redisread:GetAllTags('test')
    assert.are.same({{name = 'test'}}, ok)
  end)

  it('test GetFiltersBySubs', function()
    redisBase:createMock('zrange', {'test'});
    local ok, err = redisread:GetFiltersBySubs(1, 10)
    assert.are.same({'test'}, ok)
  end)

  it('test GetUserThreads', function()
    redisBase:createMock('zrevrange', {'test'});
    local ok, err = redisread:GetUserThreads('userID', 1, 10)
    assert.are.same({'test'}, ok)
  end)

  it('test ConvertThreadFromRedis', function()
    local fakeThread = {
      'viewer:viewerID', 'viewer'
    }
    local ok, err = redisread:ConvertThreadFromRedis(fakeThread)
    assert.are.same({viewers = {'viewerID'}}, ok)
  end)

  it('test GetThreadInfo', function()
    local fakeThread = {
      'viewer:viewerID', 'viewer'
    }
    redisBase:createMock('hgetall', fakeThread);
    local ok, err = redisread:GetThreadInfo('threadID')
    local expected = {
      messages = {
        ['viewer:viewerID'] = 'test'
      },
      viewers = {
        'viewerID'
      }
    }
    assert.are.same(expected, ok)
  end)

  it('test GetFilterID', function()
    redisBase:createMock('get', 'filterID');
    local ok, err = redisread:GetFilterID('userID')
    assert.are.same('filterID', ok)
  end)



  -- it('tests redis q size', function()
  --   local oldest = redisread:GetQueueSize('test');

  --   assert.are.equal(oldest, 'test')
  -- end)
  -- it('tests redis q size', function()
  --   local oldest = redisread:GetBacklogStats('test');

    -- 36b8954b-c8d2-451a-b8ac-a8bc9ab5ebe5

end)