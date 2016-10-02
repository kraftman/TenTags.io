local http = require("socket.http")
local ltn12 = require("ltn12")
local io = require("io")

-- connect to server "www.cs.princeton.edu" and retrieves this manual
-- file from "~diego/professional/luasocket/http.html" and print it to stdout

local url = "http://localhost:8080"


local function GetHeader()
  local t = {}
  local r, c, h = http.request(
    url.."/login?email=&password="
    )

  local cookie = h['set-cookie']
  local headers = {}
  headers['cookie'] = cookie

  local r,c,h = http.request({
    url = url,
    headers = headers,
    sink = ltn12.sink.table(t)
  })
  return cookie
end




--===================================

wrk.path = '/post/9261a692abb84924a0d9729fc6f8b887'
wrk.headers["cookie"] = GetHeader()


done = function(summary, latency, requests)
   io.write("------------------------------\n")
   io.write('non 2x 3x responses: '..summary.errors.status)
   io.write("------------------------------\n")
end
