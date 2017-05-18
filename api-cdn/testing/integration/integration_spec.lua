

local http = require ('socket.http')


local paths = {
	'/',
	'/settings',
	'/sub/new',
	'/user/list',
	'/admin',
	'/admin/stats',
	'/messages/new',
	'/p/new',
	'/filters/create',
	'/about',
	'/logout',
	'/f'





}

describe('Testing logged out access',function()


	before_each(function()
	end)
	local b,c
	for k,v in pairs(paths) do
			
		it('fails to load secure uri with no auth ',function()

				b, c = http.request("http://localhost")

				assert.is_not_true(b:find('error-500'))

		end)
	end

end)
