


local m = {}
m.__index = m


local function CreateFilter()

end

function m:Register(app)

  app:post('createfilter','/api/filter',CreateFilter)

end
