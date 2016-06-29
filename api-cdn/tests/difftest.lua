

local diff = require 'diff'

local oldMessage = 'this is a post title and ive changed a word'
local newMessage = 'this is a post title and ive change a word'

for _, token in ipairs(diff.diff(oldMessage, newMessage)) do
  print(token[1],token[2])
end
