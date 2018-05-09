local imgurHandler = require 'handlers.imgur'

local url = 'http://imgur.com/dSWL6S1'
local postId = 'testIDs'

imgurHandler:Process(url, postId)