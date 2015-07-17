-- Michal Kottman, 2011, public domain
local socket = require 'socket'
local smtp = require 'socket.smtp'
local ssl = require 'ssl'
local https = require 'ssl.https'
local ltn12 = require 'ltn12'

local m = {}

function m:sslCreate()
    local sock = socket.tcp()
    return setmetatable({
        connect = function(_, host, port)
            local r, e = sock:connect(host, port)
            if not r then return r, e end
            sock = ssl.wrap(sock, {mode='client', protocol='tlsv1'})
            return sock:dohandshake()
        end
    }, {
        __index = function(t,n)
            return function(_, ...)
                return sock[n](sock, ...)
            end
        end
    })
end

function m:sendMessage(subject, body)
    local msg = {
        headers = {
            to = '<crtanner@gmail.com>',
            subject = subject
        },
        body = body
    }

    local ok, err = smtp.send {
        from = '<me@itschr.is>',
        rcpt = '<crtanner@gmail.com>',
        source = smtp.message(msg),
        user = 'me@itschr.is',
        password = 'rimhgxozkljiozbf',
        server = 'smtp.gmail.com',
        port = 465,
        create = sslCreate
    }
    if not ok then
        print("Mail send failed", err) -- better error handling required
    end
end

return m
