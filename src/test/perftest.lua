
local tinsert, random = table.insert, math.random
local api = require 'api.api'

local m = {}

local function TestPosting(self)
  local ok, err
  for j = 1, 9000 do
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

    ok, err = api:CreatePost(info)
    if not ok then
      ngx.log(ngx.ERR, 'error from api: ',err or 'none')
      return {status = 500}
    end

  end

  return 'done'

end

function m:Register(app)
  app:get('/test/posts',TestPosting)
end

return m
