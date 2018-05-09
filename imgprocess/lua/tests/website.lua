local websiteHandler = require 'handlers.website'

local url = 'https://techcrunch.com/2018/05/08/you-can-now-run-linux-apps-on-chrome-os/'
local postId = 'testIDs'

websiteHandler:Process(url, postId)