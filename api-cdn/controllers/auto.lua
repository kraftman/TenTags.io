
local m = {}


local respond_to = (require 'lapis.application').respond_to
local api = require 'api.api'
local tinsert = table.insert

local filters = {
  {title = 'gifs', name = 'gifs', description = 'gifs', requiredTagNames = {'gifs'}, bannedTagNames = {'meta:self'}},
  {title = 'funny', name = 'funny', description = 'funny', requiredTagNames = {'funny'}, bannedTagNames = {'nsfw'}},
  {title = 'funnynsfw', name = 'funnynsfw', description = 'funnynsfw', requiredTagNames = {'funny','nsfw'}, bannedTagNames = {'sfw'}},
  {title = 'pics', name = 'pics', description = 'pics', requiredTagNames = {'pics'}, bannedTagNames = {'nsfw'}},
}

local posts = {
  {title = 'Hockey Practise', link = 'https://i.imgur.com/zAwz5jB.gifv', text = '',tags = {'gifs', 'funny'}},
  {title = 'Funny Cat', link = 'https://i.imgur.com/IrbGz3l.gifv', text = '',tags = {'gifs', 'funny','cat'}},
  {title = 'Skrillex LOLOL', link = 'https://i.imgur.com/ve9Ilrr.jpg', text = '',tags = {'funny','pics'}},
  {title = 'Rabbit', link = 'http://i.imgur.com/XfyH2oE.gifv', text = '',tags = {'cute', 'gifs'}},
  --{title = 'Funny Cat', link = 'https://i.imgur.com/IrbGz3l.gifv', text = '',tags = {'gifs', 'funny','cat'}},
  --{title = 'Funny Cat', link = 'https://i.imgur.com/IrbGz3l.gifv', text = '',tags = {'gifs', 'funny','cat'}}
}


function m.AutoContent(request)
  local userID = request.session.userID
  if not userID then
    return 'no userID!'
  end

  ---[[
  for k,v in pairs(filters) do
    local info ={
      title = v.title,
      name= v.name ,
      description = v.description,
      createdAt = ngx.time(),
      createdBy = userID,
      ownerID = userID,
      bannedTagNames = v.bannedTagNames,
      requiredTagNames = v.requiredTagNames
    }

    local ok, err = api:CreateFilter(userID, info)
    if not ok then
      ngx.log(ngx.ERR, 'error creating filter: ',err)
      return {status = 500}
    end
  end
  --]]

  ---[[
  for k,v in pairs(posts) do

    local info = {
      title = v.title,
      link = v.link,
      text = v.text,
      createdBy = userID,
      tags = v.tags
    }

    local ok, err = api:CreatePost(userID, info)

    if not ok then
      ngx.log(ngx.ERR, 'error from api: ',err or 'none')
      return {json = err}
    end

  end
  --]]

end

function m.CreatePosts(self)
  local userID = self.session.userID

  for i = 1, 10 do
    local info = {
      title = 'post:456:'..i,
      text = 'text:'..i,
      createdBy = userID,
      tags = {'456'}
    }

    local ok, err = api:CreatePost(userID, info)

    if not ok then
      ngx.log(ngx.ERR, 'error from api: ',err or 'none')
      return {json = err}
    end
  end

end

function m:Register(app)
  app:get('/auto/all', self.AutoContent)
  app:get('/auto/posts', self.CreatePosts)
end

return m
