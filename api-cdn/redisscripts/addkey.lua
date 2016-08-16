local addKey = [[
-- Check And Set
-- Check if the item is already present in one of the layers and
-- only add the item if it wasn't.
-- Returns 1 if the item was added.
--
-- If only this script is used to add items to the filter the :count
-- key will accurately indicate the number of unique items added to
-- the filter.
local baseName = ARGV[1]
local entries   = ARGV[2]
local precision = ARGV[3]
local hash      = redis.sha1hex(ARGV[4])
local countkey  = baseName .. ':count'
local count     = redis.call('GET', countkey)
if not count then
  count = 1
else
  count = count + 1
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

local factor = ceil((entries + count) / entries)

local index = ceil(math.log(factor) / 0.69314718055995)
local scale = pow(2, index - 1) * entries

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

-- Only do this if we have data already.
if index > 1 then
  -- The last fiter will be handled below.
  for n=1, index-1 do
    local key   = baseName .. ':' .. n
    local scale = pow(2, n - 1) * entries


    local bits = floor((scale * log(precision * pow(0.5, n))) / ln2by2)


    local k = floor(ln2 * bits / scale)

    local found = true
    for i=1, k do
      if redis.call('GETBIT', key, b[i] % bits) == 0 then
        found = false
        break
      end
    end

    if found then
      return 1
    end
  end
end

-- For the last filter we do a SETBIT where we check the result value.
local key = baseName .. ':' .. index

local found = 1
for i=1, maxk do
  if redis.call('SETBIT', key, b[i] % maxbits, 1) == 0 then
    found = 0
  end
end

if found == 0 then
  -- INCR is a little bit faster than SET.
  redis.call('INCR', countkey)
end

return found
]]

local m = {}
local str = require 'resty.string'

function m:GetScript()
  return addKey
end

function m:GetSHA1()
  return str.to_hex(ngx.sha1_bin(addKey))
end


return m
