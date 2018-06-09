
package.path = package.path.. "./controllers/?.lua;;./lib/?.lua;;";

local realdb = require 'redis.base'

local fakeRedis = {

}

local fakeDb = {
}
fakeDb.__index = fakeDb

function fakeDb:GetRedisReadConnection()
  return fakeRedis
end

function fakeDb:SetKeepalive()
  return true
end

function fakeDb:SplitShortURL()
  return 'test'
end

function fakeDb:from_json()
  return 'test'
end

local function createMock(name, returnValue)
  fakeRedis[name] = function(self, ...)
    self.calledWith = {...}
    return returnValue
  end
end

package.loaded['redis.base'] = fakeDb

local redisread = require 'redis.redisread'

describe('tests redisread', function()


  it('tests GetOldestJob', function()
    createMock('zrevrange', {'test'})
    local oldest = redisread:GetOldestJob('test');
    
    assert.are.equal(oldest, 'test');
    --assert.are.equal(fakeRedis.zrevrange.calledWith, 'test')
  end)

  it('tests get queue size', function()
    createMock('zcard', 'test')
    local qSize = redisread:GetQueueSize('fakeJob')
    assert.are.equal('test', qSize)
  end)

  it('test Getview', function()
    createMock('hgetall', {});
    local view = redisread:GetView('viewID')
    assert.are.same(view.filters, { })
  end)

  it('test GetBacklogStats', function()
    createMock('zrangebyscore', 'test');
    local view = redisread:GetBacklogStats('viewID')
    assert.are.same(view, 'test')
  end)

  it('test GetOldestJobs', function()
    createMock('zrange', 'test');
    local view = redisread:GetOldestJobs('viewID')
    assert.are.same(view, 'test')
  end)

  it('test GetSiteUniqueStats', function()
    createMock('zrevrange', {'test'});
    createMock('pfcount', 'test');
    local view = redisread:GetSiteUniqueStats('viewID')
    assert.are.same(view, {test = 'test'})
  end)

  it('test GetSiteStats', function()
    createMock('hgetall', {1, 'test'});
    local view = redisread:GetSiteStats('viewID')
    assert.are.same(view, {[1] = 'test'})
  end)

  it('test ConvertShortURL', function()
    createMock('hget', 'test');
    local view = redisread:ConvertShortURL('test:url')
    assert.are.same(view, 'test')
  end)

  it('test GetInvalidationRequests', function()
    createMock('zrangebyscore', 'test');
    local view = redisread:GetInvalidationRequests('test:url')
    assert.are.same(view, 'test')
  end)


  it('test GetFilterIDsByTags', function()
    createMock('init_pipeline', true);
    createMock('commit_pipeline', true);
    createMock('hgetall', true);
    local view = redisread:GetFilterIDsByTags({})
    assert.are.same(view, true)
  end)

  it('test GetReports', function()
    createMock('zrange', 'test');
    local view = redisread:GetReports(0, 10)
    assert.are.same(view, 'test')
  end)

  it('test GetRelevantFilters', function()
    createMock('hgetall', {});
    local view = redisread:GetRelevantFilters({{name = 'test', up = 1}})
    assert.are.same(view, {})
  end)

  it('test VerifyReset', function()
    createMock('get', 'test');
    local ok = redisread:VerifyReset('test', 'test')
    assert.are.same(ok, true)
  end)

  it('test GetTag', function()
    createMock('hgetall', {'name', 'test'});
    local ok, err = redisread:GetTag('test')
    assert.are.same({name = 'test'}, ok)
  end)

  it('test GetAllTags', function()
    createMock('smembers', {'tag1', 'tag2'});
    createMock('hgetall', {'name', 'test'});
    createMock('commit_pipeline', {{'name', 'test'}});
    local ok, err = redisread:GetAllTags('test')
    assert.are.same({{name = 'test'}}, ok)
  end)

  it('test GetFiltersBySubs', function()
    createMock('zrange', {'test'});
    local ok, err = redisread:GetFiltersBySubs(1, 10)
    assert.are.same({'test'}, ok)
  end)

  it('test GetUserThreads', function()
    createMock('zrevrange', {'test'});
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
    createMock('hgetall', fakeThread);
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
    createMock('get', 'filterID');
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