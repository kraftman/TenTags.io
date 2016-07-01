local resty_sha1 = require "resty.sha1"
local upload = require "resty.upload"

local chunk_size = 4096
local form = upload:new(chunk_size)
local sha1 = resty_sha1:new()
local file

local function my_get_file_name()
  return '/var/www/icons/test.jpg'
end

print('this')

while true do
    local typ, res, err = form:read()

    if not typ then
         ngx.say("failed to read: ", err)
         return
    end

    if typ == "header" then
        local file_name = my_get_file_name(res)
        if file_name then
            file = io.open(file_name, "w+")
            if not file then
                ngx.say("failed to open file ", file_name)
                return
            end
        end

     elseif typ == "body" then
        if file then
            file:write(res)
            sha1:update(res)
        end

    elseif typ == "part_end" then
        file:close()
        file = nil
        local sha1_sum = sha1:final()
        sha1:reset()
        my_save_sha1_sum(sha1_sum)

    elseif typ == "eof" then
        break

    else
        -- do nothing
    end
end
