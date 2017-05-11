
local http = require 'lib.http'
local to_json = (require 'lapis.util').to_json
local from_json = (require 'lapis.util').from_json
local M = {}

local index = 'testindex'

function M:CreateIndex()

  local httpc = http.new()

  local path = "http://elasticsearch1:9200"..'/'..index
  local res, err = httpc:request_uri(path, {
        method = "DELETE",
        body = to_json(data),
        headers = {
          ["Content-Type"] = "application/json"
        }
      })

  if not res or res.status > 300 and res.status ~= 404 then
    --print(res.status)
    return nil, res.body
  end
  path = "http://elasticsearch1:9200"..'/'..index
  res, err = httpc:request_uri(path, {
        method = "PUT",
        body = to_json({
          mappings = {
            post = {
              properties = {
                url ={
                  type = 'string',
                  index = 'not_analyzed'
                }
              }
            }
          }
        }),
        headers = {
          ["Content-Type"] = "application/json"
        }
      })

  if not res or res.status > 300 then
    print(res.status)
    return nil, res.body
  end

  return true
end

function M:Index(indexType, data)
  local httpc = http.new()

  local path = "http://elasticsearch1:9200"..'/'..index..'/'..indexType
  local res, err = httpc:request_uri(path, {
        method = "POST",
        body = to_json(data),
        headers = {
          ["Content-Type"] = "application/json"
        }
      })
  if not res then
    return nil, err
  end
  --print(res.status)
  if err then
    return nil, err
  end

  if res.status > 300 then
    --print(res.status)
    return nil, res.body
  end

  return true
end


function M:SearchPostTitle(searchString)
  local httpc = http.new()
  local path = "http://elasticsearch1:9200"..'/_search'
  local res, err = httpc:request_uri(path, {
        method = "GET",
        body = to_json({
          query = {
            match = {
              title = searchString
            }
          }
        }),
        headers = {
          ["Content-Type"] = "application/json",
        }
      })
  if err then
    return nil, err
  end
  if res.status > 300 then
    return nil, res.body
  end

  return res.body
end

function M:SearchPostBody(searchString)
  local httpc = http.new()
  local path = "http://elasticsearch1:9200"..'/_search'
  local res, err = httpc:request_uri(path, {
        method = "GET",
        body = to_json({
          query = {
            match = {
              text = searchString
            }
          }
        }),
        headers = {
          ["Content-Type"] = "application/json",
        }
      })
  if err then
    return nil, err
  end
  if res.status > 300 then
    return nil, res.body
  end

  return res.body
end


function M:SearchURL(searchString)
  local httpc = http.new()
  local path = "http://elasticsearch1:9200"..'/_search'
  local res, err = httpc:request_uri(path, {
        method = "GET",
        body = to_json({
          query = {
            constant_score = {
              filter = {
                term = {
                  url = searchString
                }
              }
            }
          }
        }),
        headers = {
          ["Content-Type"] = "application/json",
        }
      })
  if err then
    return nil, err
  end
  if res.status > 300 then
    return nil, res.body
  end

  return res.body
end


function M:SearchWholePostFuzzy(searchString)
  local httpc = http.new()
  local path = "http://elasticsearch1:9200"..'/_search'
  local res, err = httpc:request_uri(path, {
        method = "GET",
        body = to_json({
          query = {
            multi_match = {

              fields = {'text', 'title'},
              query =  searchString,
              fuzziness =  'AUTO'

            }
          },
          highlight = {
            pre_tags = {"<b>"},
            post_tags = {"</b>"},
            fields =  {text = {}}
          }
        }),
        headers = {
          ["Content-Type"] = "application/json",
        }
      })
  if err then
    return nil, err
  end
  if res.status > 300 then
    return nil, res.body
  end

  return res.body
end

function M:SearchPostTitleFuzzy(searchString)
  local httpc = http.new()
  local path = "http://elasticsearch1:9200"..'/_search'
  local res, err = httpc:request_uri(path, {
        method = "GET",
        body = to_json({
          query = {
            match = {
              title = {
                query = searchString,
                fuzziness = 'AUTO'
              }
            }
          },
        }),
        headers = {
          ["Content-Type"] = "application/json",
        }
      })
  if err then
    return nil, err
  end
  if res.status > 300 then
    return nil, res.body
  end

  return res.body
end

return M
