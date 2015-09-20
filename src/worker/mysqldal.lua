

local dal = {}
local mysql = require "resty.mysql"


local function GetMysqlConnection()
  local db, err = mysql:new()
  db:set_timeout(1000)
  local ok, err, errno, sqlstate = db:connect{
    host = "127.0.0.1",
    port = 3306,
    database = "taggr",
    user = "root",
    password = "meep",
    max_packet_size = 1024 * 1024 }
  if not ok then
    ngx.log(ngx.ERR, "failed to connect: ", err, ": ", errno, " ", sqlstate)
    return ngx.exit(500)
  end
  return db
end

local safeQuote = ngx.quote_sql_str

function dal:CreateTag(tagInfo)
  local db = GetMysqlConnection()
  local query = "REPLACE INTO tag set "..
                'id = '..safeQuote(tagInfo.id)..','..
                'name = '..safeQuote(tagInfo.name)..','..
                'createdAt = '..safeQuote(tagInfo.createdAt)..','..
                'createdBy = '..safeQuote(tagInfo.createdBy or 'default')
  local res, err = db:query(query)
  if not res then
    ngx.log(ngx.ERR, 'error writing tag to db: ',err)
    return
  end
  return res


end



return dal
