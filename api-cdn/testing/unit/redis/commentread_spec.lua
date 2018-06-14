
package.path = package.path.. "../?.lua;./testing/lib/?.lua;;./controllers/?.lua;;./lib/?.lua;;";

local redisBase = require 'fakeredis'
local redis = require 'redis.commentread'

describe('tests redisread', function()

  it('tests GetPostComments returns comments', function()
    redisBase:createMock('hgetall', {'commentID', {}})
    local ok = redis:GetPostComments('postID')
    assert.are.same({commentID = {}}, ok)
  end)

  it('tests GetPostComments errors if db fails', function()
    redisBase:createMock('hgetall', nil, 'err')
    local ok = redis:GetPostComments('postID')
    assert.are.same({}, ok)
  end)

  it('tests GetPostComments handles not found', function()
    redisBase:createMock('hgetall', ngx.null)
    local ok = redis:GetPostComments('postID')
    assert.are.same({}, ok)
  end)

  it('tests GetUserComments', function()
    redisBase:createMock('hget', {{id = 'commentID'}})
    redisBase:createMock('commit_pipeline', {{id = 'commentID'}})
    local ok = redis:GetUserComments({'postID:commentID'})
    assert.are.same({{id = 'commentID'}}, ok)
  end)

  it('tests GetUserComments', function()
    redisBase:createMock('hget', {{id = 'commentID'}})
    redisBase:createMock('commit_pipeline', nil, 'error')
    local ok = redis:GetUserComments({'postID:commentID'})
    assert.are.same({}, ok)
  end)

  it('tests GetOldestJobs', function()
    redisBase:createMock('zrange', {'jobName', {}})
    local ok = redis:GetOldestJobs('jobName', 10)
    
    assert.are.same({'jobName', {}}, ok)
  end)
  
  it('tests GetComment', function()
    redisBase:createMock('hget', {id = 'commentID'})
    function redisBase:from_json()
      return {id = 'commentID'}
    end
    local ok = redis:GetComment('postID', 'commentID')
    
    assert.are.same('default', ok.viewID)
  end)
  
  it('tests GetCommentInfos', function()
    redisBase:createMock('hgetall', {id = 'commentID'})
    redisBase:createMock('commit_pipeline', { {1, 'comment'}})
    function redisBase:from_json()
      return {id = 'commentID'}
    end
    local ok = redis:GetCommentInfos({'commentID1', 'commentID2'})
    
    assert.are.same({{'comment'}}, ok)
  end)

end)