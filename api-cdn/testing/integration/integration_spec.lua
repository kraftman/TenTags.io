

--need some way of ensuring that a default post is always present
--[[
  could use the existing redisread module to create a post
  if it doesnt already exist, then perform tests on that

]]

local url = 'http://localhost'
local http = require 'socket.http'

local postID = '19f7416f947a439a9c4011cc6aa3524f'
local commentID = '7213c71259584a1e980d9d2fd14e6304'


local routes = {
	['/admin'] = {public = 401, user = 401, admin = 200},
	['/ele'] = {public = 401, user = 401, admin = 200},
	['/admin/stats'] = {public = 401, user = 401, admin = 200},
	['/admin/score/1/0'] = {public = 401, user = 401, admin = 200},
	['/admin/reports'] = {public = 401, user = 401, admin = 200},
	['/admin/takedowns'] = {public = 401, user = 401, admin = 200},
	['/admin/takedown/aristen/confirm'] = {public = 401, user = 401, admin = 200},
	['/admin/takedown/aristen/cancel'] = {public = 401, user = 401, admin = 200},


	['/alerts/view'] = {public = 401, user = 200, admin = 200},


	['/c/delete/'..postID..'/'..commentID] = {public = 401, user = 401, admin = 200},
	['/c/aristn'] = {public = 200, user = 200, admin = 200},
	['/comment/subscribe/'..postID..'/'..commentID] = {public = 401, user = 200, admin = 200},
	['/comment/upvote/'..postID..'/'..commentID..'/arst'] = {public = 401, user = 200, admin = 200},
	['/comment/downvote/'..postID..'/'..commentID..'/rstien'] = {public = 401, user = 200, admin = 200},
	
	['/c/comment/'..postID..'/'..commentID] = {public = 200, user = 200, admin = 200},


}


describe('basic access for logged out user', function()
	local b,c,h
	for k,v in pairs(routes) do
	  it('can load '..k, function()

	    	b,c,h = http.request(url..k)
	    	assert.are.equal( v.public,c)

	  end)
	end

end)

describe('basic api access for logged out user', function()

	  it('can load ', function()


	  end)


end)
