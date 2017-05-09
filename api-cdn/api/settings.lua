--[[
APi settings need to be moved to one location
and changeable
requirements
- must be kept up to date
- must be rapidly accessed

solutions:
- store in redis
- use background worker to pull at intervals
- update only when settings have changed
- use shdict/LRU for fast access

]]
