

local m = {}


m.roles = {
  Public = 1, -- any public can do this
  User = 2, -- any user can do this
  Self = 10, -- only if the own it
  Admin = 50
}

m.routes = {}
-- admin
m.routes.deletecomment = {maxCalls = 20, duration = 300, access = m.User}
m.routes['admin.view'] = {maxCalls = 60, duration = 300, access = m.Admin}
m.routes['ele'] = {maxCalls = 60, duration = 300, access = m.Admin}
m.routes['admin.stats'] = {maxCalls = 60, duration = 300, access = m.Admin}
m.routes['score'] = {maxCalls = 60, duration = 300, access = m.Admin}
m.routes['admin.reports'] = {maxCalls = 60, duration = 300, access = m.Admin}
m.routes['admin.takedowns'] = {maxCalls = 60, duration = 300, access = m.Admin}
m.routes['confirmtakedown'] = {maxCalls = 60, duration = 300, access = m.Admin}
m.routes['canceltakedown'] = {maxCalls = 60, duration = 300, access = m.Admin}

--alerts
m.routes['alerts'] = {maxCalls = 10, duration = 60, access = m.User}

-- api
m.routes['api-subscribefilter'] = {maxCalls = 20, duration = 60, access = m.User}
m.routes['api-filtersearch'] = {maxCalls = 20, duration = 60, access = m.Public}
m.routes['api-userfilters'] = {maxCalls = 30, duration = 60, access = m.User}
m.routes['api-upvotecomment'] = {maxCalls = 30, duration = 60, access = m.User}
m.routes['api-downvotecomment'] = {maxCalls = 30, duration = 60, access = m.User}
m.routes['api-upvotepost'] = {maxCalls = 30, duration = 60, access = m.User}
m.routes['api-downvotepost'] = {maxCalls = 30, duration = 60, access = m.User}
m.routes['api-settings'] = {maxCalls = 30, duration = 60, access = m.User}
m.routes['api-frontpage'] = {maxCalls = 30, duration = 60, access = m.Public}
m.routes['api-createfilter'] = {maxCalls = 30, duration = 60, access = m.User}

m.routes['api-searchtags'] = {maxCalls = 30, duration = 60, access = m.User}
m.routes['api-uploadfile'] = {maxCalls = 40, duration = 120, access = m.User}
m.routes['api-taguser'] = {maxCalls = 40, duration = 120, access = m.User}

-- comments
m.routes['deletecomment'] = {maxCalls = 10, duration = 60, access = m.User}
m.routes['viewcommentshort'] = {maxCalls = 10, duration = 10, access = m.Public}
m.routes['subscribecomment'] = {maxCalls = 10, duration = 60, access = m.User}
m.routes['upvotecomment'] = {maxCalls = 10, duration = 60, access = m.User}
m.routes['downvotecomment'] = {maxCalls = 10, duration = 60, access = m.User}
m.routes['newcomment'] = {maxCalls = 10, duration = 60, access = m.User}
m.routes['viewcomment'] = {maxCalls = 10, duration = 10, access = m.Public}

-- filters
m.routes['subscribefilter'] = {maxCalls = 10, duration = 60, access = m.User}
m.routes['filter.view'] = {maxCalls = 10, duration = 10, access = m.Public}
m.routes['filter.create'] = {maxCalls = 10, duration = 60, access = m.User}
m.routes['filter.edit'] = {maxCalls = 10, duration = 60, access = m.User}
m.routes['filter.all'] = {maxCalls = 10, duration = 60, access = m.User}
m.routes['unbanfilteruser'] = {maxCalls = 10, duration = 60, access = m.Admin}
m.routes['unbanfilterdomain'] = {maxCalls = 10, duration = 60, access = m.Admin}
m.routes['banpost'] = {maxCalls = 10, duration = 60, access = m.Admin}
m.routes['searchfilters'] = {maxCalls = 10, duration = 60, access = m.Public}

-- frontpage
m.routes['home'] = {maxCalls = 10, duration = 60, access = m.Public}
m.routes['new'] = {maxCalls = 10, duration = 10, access = m.Public}
m.routes['best'] = {maxCalls = 10, duration = 10, access = m.Public}
m.routes['seen'] = {maxCalls = 10, duration = 10, access = m.Public}

-- images
m.routes['postIcon'] = {maxCalls = 100, duration = 20, access = m.Public}
m.routes['imagereload'] = {maxCalls = 10, duration = 10, access = m.Admin}
m.routes['smallimage'] = {maxCalls = 100, duration = 20, access = m.Public}
m.routes['medimage'] = {maxCalls = 100, duration = 20, access = m.Public}
m.routes['bigimage'] = {maxCalls = 100, duration = 20, access = m.Public}
m.routes['previewVid'] = {maxCalls = 100, duration = 20, access = m.Public}
m.routes['dmca'] = {maxCalls = 100, duration = 20, access = m.User}

-- messages
m.routes['message.view'] = {maxCalls = 5, duration = 10, access = m.User}
m.routes['message.create'] = {maxCalls = 5, duration = 10, access = m.User}
m.routes['message.reply'] = {maxCalls = 5, duration = 10, access = m.User}

--posts
m.routes['post.create'] = {maxCalls = 3, duration = 600, access = m.User}
m.routes['post.view'] = {maxCalls = 10, duration = 10, access = m.Public}
m.routes['deletepost'] = {maxCalls = 10, duration = 10, access = m.Self}
m.routes['post.report'] = {maxCalls = 10, duration = 60, access = m.User}
m.routes['upvotetag'] = {maxCalls = 10, duration = 60, access = m.User}
m.routes['downvotetag'] = {maxCalls = 10, duration = 60, access = m.User}
m.routes['upvotepost'] = {maxCalls = 10, duration = 60, access = m.User}
m.routes['downvotepost'] = {maxCalls = 10, duration = 60, access = m.User}
m.routes['subscribepost'] = {maxCalls = 10, duration = 60, access = m.User}
m.routes['savepost'] = {maxCalls = 10, duration = 60, access = m.User}
m.routes['reloadimage'] = {maxCalls = 10, duration = 60, access = m.Admin}

--search
m.routes['search.results'] = {maxCalls = 10, duration = 60, access = m.Admin}

--settings

m.routes['user.subsettings'] = {maxCalls = 10, duration = 60, access = m.Self}
m.routes['killsession'] = {maxCalls = 10, duration = 60, access = m.Self}

--user

m.routes['newsubuser'] = {maxCalls = 10, duration = 60, access = m.Public}
m.routes['login'] = {maxCalls = 10, duration = 60, access = m.Public}
m.routes['user.viewsub'] = {maxCalls = 10, duration = 60, access = m.User}
m.routes['deleteuser'] = {maxCalls = 10, duration = 60, access = m.Self}
m.routes['confirmLogin'] = {maxCalls = 10, duration = 60, access = m.Public}
m.routes['user.viewsubcomments'] = {maxCalls = 10, duration = 60, access = m.User}
m.routes['user.viewsubposts'] = {maxCalls = 10, duration = 60, access = m.User}
m.routes['user.viewsubupvotes'] = {maxCalls = 10, duration = 60, access = m.User}
m.routes['logout'] = {maxCalls = 10, duration = 60, access = m.User}
m.routes['switchuser'] = {maxCalls = 10, duration = 60, access = m.User}
m.routes['listusers'] = {maxCalls = 10, duration = 60, access = m.Self}
m.routes['subscribeusercomment'] = {maxCalls = 10, duration = 60, access = m.User}
m.routes['subscribeuserpost'] = {maxCalls = 10, duration = 60, access = m.User}
m.routes['blockuser'] = {maxCalls = 10, duration = 60, access = m.User}




return m
