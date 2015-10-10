local checkKey = [[
local entries   = ARGV[2]
local precision = ARGV[3]
local inputElement = ARGV[4]
local count     = redis.call('GET', ARGV[1] .. ':count')

if not count then
  return inputElement
end
local ceil = math.ceil
local tonumber= tonumber
local pow = math.pow
local sub = string.sub
local floor = math.floor
local factor = ceil((entries + count) / entries)
local tinsert = table.insert
local log = math.log

local ln2 = 0.69314718055995 -- 0.69314718055995 = ln(2)
local ln2by2 = -0.4804530139182 -- 0.4804530139182 = ln(2)^2
local index = ceil(log(factor) / ln2)
local scale = pow(2, index - 1) * entries

local hash = redis.sha1hex(ARGV[4])

-- This uses a variation on:
-- 'Less Hashing, Same Performance: Building a Better Bloom Filter'
-- http://www.eecs.harvard.edu/~kirsch/pubs/bbbf/esa06.pdf
local h = { }
h[0] = tonumber(sub(hash, 1 , 8 ), 16)
h[1] = tonumber(sub(hash, 9 , 16), 16)
h[2] = tonumber(sub(hash, 17, 24), 16)
h[3] = tonumber(sub(hash, 25, 32), 16)

-- Based on the math from: http://en.wikipedia.org/wiki/Bloom_filter#Probability_of_false_positives
-- Combined with: http://www.sciencedirect.com/science/article/pii/S0020019006003127

local maxbits = floor((scale * log(precision * pow(0.5, index))) / ln2by2)


local maxk = floor(ln2 * maxbits / scale)
local b    = { }

for i=1, maxk do
  tinsert(b, h[i % 2] + i * h[2 + (((i + (i % 2)) % 4) / 2)])
end

for n=1, index do
  local key    = ARGV[1] .. ':' .. n
  local found  = true
  local scalen = pow(2, n - 1) * entries

  -- 0.4804530139182 = ln(2)^2
  local bits = floor((scalen * log(precision * pow(0.5, n))) / ln2by2)


  local k = floor(ln2 * bits / scalen)

  for i=1, k do
    if redis.call('GETBIT', key, b[i] % bits) == 0 then
      found = false
      break
    end
  end

  if found then
    return nil
  end
end

return inputElement
]]

local m = {}
local str = require 'resty.string'

function m:GetScript()
  return checkKey
end

function m:GetSHA1()
  return str.to_hex(ngx.sha1_bin(checkKey))
end


return m
