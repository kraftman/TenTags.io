

local uuid = require 'uuid'
local util = require("lapis.util")
local api = require 'api.api'

local m = {}


local function FrontPage(self)
  self.pageNum = self.params.page or 1
  print(self.pageNum)
  self.posts = api:GetDefaultFrontPage(10*(self.pageNum-1)) or {}
  return {render = 'frontpage'}
end

local function FrontPageNew(self)
  self.pageNum = self.params.page or 1
  print(self.pageNum)
  self.posts = api:GetDefaultFrontPage(10*(self.pageNum-1),'new') or {}
  return {render = 'frontpage'}
end

local function FrontPageBest(self)
  self.pageNum = self.params.page or 1
  print(self.pageNum)
  self.posts = api:GetDefaultFrontPage(10*(self.pageNum-1),'best') or {}
  return {render = 'frontpage'}
end

function m:Register(app)
  app:get('home','/',FrontPage)
  app:get('new','/new',FrontPageNew)
  app:get('best','/best',FrontPageBest)
end

return m
