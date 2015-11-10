-- Michal Kottman, 2011, public domain
local smtp = require 'resty.smtp'
local ltn12 = require 'resty.smtp.ltn12'

local m = {}

function m:sendMessage(subject, body, recipient)
    local msg = {
        headers = {
            to = '<crtanner@gmail.com>',
            subject = subject
        },
        body = body
    }

    local ok, err = smtp.send {
        from = '<admin@filtta.com>',
        rcpt = '<'..recipient..'>',
        source = smtp.message(msg),
        user = 'admin@filtta.com',
        password = '*n7NvY[Oh9K8$',
        server = 'mail.privateemail.com',
        port = 465,
        ssl = {enable = true}
    }
    if not ok then
        print("Mail send failed", err) -- better error handling required
    end
end

return m
