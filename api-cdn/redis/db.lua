

local db = {}

db.redisRead = require 'redis.redisread'
db.redisWrite = require 'redis.rediswrite'
db.userRead = require 'redis.userread'
db.userWrite = require 'redis.userwrite'
db.commentRead = require 'redis.commentread'
db.commentWrite = require 'redis.commentwrite'


return db
