-- Michal Kottman, 2011, public domain
local smtp = require 'resty.smtp'
local ltn12 = require 'resty.smtp.ltn12'

local m = {}

function m:SendMessage(subject, body, recipient)
  local password =os.getenv('EMAIL_CREDENTIALS')
    local msg = {
        headers = {
            to = '<'..recipient..'>',
            from = '<admin@filtta.com>',
            subject = subject
        },
        body = body
    }
    print('sending email')
    local ok, err = smtp.send {
        from = '<admin@filtta.com>',
        rcpt = '<'..recipient..'>',
        source = smtp.message(msg),
        user = 'admin@filtta.com',
        password = password,
        server = 'mail.privateemail.com',
        port = 465,
        ssl = {enable = true}
    }
    if not ok then
        print("Mail send failed", err) -- better error handling required
    end
    return ok, err
end

function m:IsValidEmail(str)
  if str == nil then return nil, 'no email' end
  if (type(str) ~= 'string') then
    error("Expected string")
    return nil, 'no email'
  end
  str = str:gsub(' ','')
  if str == '' then
    return nil, 'blank email'
  end
  local lastAt = str:find("[^%@]+$")
  local localPart = str:sub(1, (lastAt - 2)) -- Returns the substring before '@' symbol
  local domainPart = str:sub(lastAt, #str) -- Returns the substring after '@' symbol
  -- we werent able to split the email properly
  if localPart == nil then
    return nil, "Local name is invalid"
  end

  if domainPart == nil then
    return nil, "Domain is invalid"
  end
  -- local part is maxed at 64 characters
  if #localPart > 64 then
    return nil, "Local name must be less than 64 characters"
  end
  -- domains are maxed at 253 characters
  if #domainPart > 253 then
    return nil, "Domain must be less than 253 characters"
  end
  -- somthing is wrong
  if lastAt >= 65 then
    return nil, "Invalid @ symbol usage"
  end
  -- quotes are only allowed at the beginning of a the local name
  local quotes = localPart:find("[\"]")
  if type(quotes) == 'number' and quotes > 1 then
    return nil, "Invalid usage of quotes"
  end
  -- no @ symbols allowed outside quotes
  if localPart:find("%@+") and quotes == nil then
    return nil, "Invalid @ symbol usage in local part"
  end
  -- only 1 period in succession allowed
  if domainPart:find("%.%.") then
    return nil, "Too many periods in domain"
  end
  -- just a general match
  if not str:match('[%w]*[%p]*%@+[%w]*[%.]?[%w]*') then
    return nil, "Email pattern test failed"
  end
  -- all our tests passed, so we are ok
  return true
end

return m
