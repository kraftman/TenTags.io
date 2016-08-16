

local handle = io.popen('python test.py')
local result = handle:read("*a")
handle:close()
print(result)
