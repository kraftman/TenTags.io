local M = {}
math.randomseed(ngx.time())
math.random() math.random() math.random()
local reserved = { 'about', 'access', 'account', 'accounts', 'add', 'address', 'adm', 'admin', 'administration', 'adult', 'advertising', 'affiliate', 'affiliates', 'ajax', 'analytics', 'android', 'anon', 'anonymous', 'api', 'app', 'apps', 'archive', 'atom', 'auth', 'authentication', 'avatar', 'backup', 'banner', 'banners', 'bin', 'billing', 'blog', 'blogs', 'board', 'bot', 'bots', 'business', 'chat', 'cache', 'cadastro', 'calendar', 'campaign', 'careers', 'cgi', 'client', 'cliente', 'code', 'comercial', 'compare', 'config', 'connect', 'contact', 'contest', 'create', 'code', 'compras', 'css', 'dashboard', 'data', 'db', 'design', 'delete', 'demo', 'design', 'designer', 'dev', 'devel', 'dir', 'directory', 'doc', 'docs', 'domain', 'download', 'downloads', 'edit', 'editor', 'email', 'ecommerce', 'forum', 'forums', 'faq', 'favorite', 'feed', 'feedback', 'flog', 'follow', 'file', 'files', 'free', 'ftp', 'gadget', 'gadgets', 'games', 'guest', 'group', 'groups', 'help', 'home', 'homepage', 'host', 'hosting', 'hostname', 'html', 'http', 'httpd', 'https', 'hpg', 'info', 'information', 'image', 'img', 'images', 'imap', 'index', 'invite', 'intranet', 'indice', 'ipad', 'iphone', 'irc', 'java', 'javascript', 'job', 'jobs', 'js', 'knowledgebase', 'log', 'login', 'logs', 'logout', 'list', 'lists', 'mail', 'mail1', 'mail2', 'mail3', 'mail4', 'mail5', 'mailer', 'mailing', 'mx', 'manager', 'marketing', 'master', 'me', 'media', 'message', 'microblog', 'microblogs', 'mine', 'mp3', 'msg', 'msn', 'mysql', 'messenger', 'mob', 'mobile', 'movie', 'movies', 'music', 'musicas', 'my', 'name', 'named', 'net', 'network', 'new', 'news', 'newsletter', 'nick', 'nickname', 'notes', 'noticias', 'ns', 'ns1', 'ns2', 'ns3', 'ns4', 'old', 'online', 'operator', 'order', 'orders', 'page', 'pager', 'pages', 'panel', 'password', 'perl', 'pic', 'pics', 'photo', 'photos', 'photoalbum', 'php', 'plugin', 'plugins', 'pop', 'pop3', 'post', 'postmaster', 'postfix', 'posts', 'profile', 'project', 'projects', 'promo', 'pub', 'public', 'python', 'random', 'register', 'registration', 'root', 'ruby', 'rss', 'sale', 'sales', 'sample', 'samples', 'script', 'scripts', 'secure', 'send', 'service', 'shop', 'sql', 'signup', 'signin', 'search', 'security', 'settings', 'setting', 'setup', 'site', 'sites', 'sitemap', 'smtp', 'soporte', 'ssh', 'stage', 'staging', 'start', 'subscribe', 'subdomain', 'suporte', 'support', 'stat', 'static', 'stats', 'status', 'store', 'stores', 'system', 'tablet', 'tablets', 'tech', 'telnet', 'test', 'test1', 'test2', 'test3', 'teste', 'tests', 'theme', 'themes', 'tmp', 'todo', 'task', 'tasks', 'tools', 'tv', 'talk', 'update', 'upload', 'url', 'user', 'username', 'usuario', 'usage', 'vendas', 'video', 'videos', 'visitor', 'win', 'ww', 'www', 'www1', 'www2', 'www3', 'www4', 'www5', 'www6', 'www7', 'wwww', 'wws', 'wwws', 'web', 'webmail', 'website', 'websites', 'webmaster', 'workshop', 'xxx', 'xpg', 'you', 'yourname', 'yourusername', 'yoursite', 'yourdomain'}




local fakeName = {
  '2cuterner',   'BomberAholic',   'Breezelogy',   'BuggyProud',   'BurkeForum',   'Cahracine',   'Calpcath',   'Capoggerix',   'Cashawno',   'Charmstemp',   'Chilledib',   'Conspiracy',   'Deanally',   'Doorpaxse',   'Echoire',   'Egullst',   'Ellessel',   'Equitie',   'ExoticJide',   'Featuregi',   'Flashawayer',   'FriendLime',   'Gutsy2freeEye',   'Heapharo',   'Iffymelivi',   'Integri',   'KidIwant',   'LaoCrashActually',   'Lovictus',   'Manitelfa',   'Mannisti',   'Marcleje',   'MarsWel',   'Massuest',   'MasterHeadlines',   'Metrosswa',   'MountainDubya',   'NozyBooshPuppy',   'Peugepo',   'Portote',   'Practurni',   'Quebril',   'Resslist',   'Royalexan',   'SmugPlayYounger',   'Snerfini',   'Speediall',   'Spindali',   'SpyderFallen',   'Starthrie',   'Alisoner',   'Angurisyner',   'Announcerwo',   'Arergina',   'Atmometry',   'Autoeuvil',   'Baseableiq',   'Bigdomon',   'Complimo',   'Comveral',   'Corsited',   'CoverageInspiring',   'Cowbreno',   'Curepars',   'Extraingbow',   'Gradhunk',   'Heraldwood',   'Hinkerer',   'InteriorEats',   'Kmerious',   'Kweziba',   'Landsma',   'Littlenati',   'MegsScree',   'Oribism',   'Ovoloca',   'Podagoglism',   'Pumarzoi',   'Ralconder',   'Stunnansol', 'Aeracare',   'Aeroperce',   'Ainsakal',   'Amanzati',   'Aniseaw',   'Annoniagers',   'AwareCy',   'BalWiz',   'Bauerbeak',   'BuggySee',   'ChickIdol',   'Clubergo',   'Cytostong',   'Eincenet',   'Evelevisi',   'Faceedev',   'Fieditox',   'Greathell',   'Guidevel',   'Inergough',   'Keatilleu',   'Kenjimanshi',   'LucyToxic',   'Nomentan',   'Nylstware',   'OneRocksPhobic',   'Pharisol',   'Pinoveno',   'Priderstn',   'Rechrema',   'Armhotp',   'Assemul',   'Autehing',   'Barbaire',   'Biogate',   'Blicewor',   'BradleyAlpha',   'CountryTheborg',   'Custoysan',   'Cybetter',   'Donald2cool',   'Eatsyouse',   'Ecesingui',   'Fieldexce',   'Fusterat',   'Horraybrid',   'Lifevemak',   'Linkstersk',   'MrChikk',   'Obliger',   'Orariward',   'Permona',   'Phantech',   'Psychosonse',   'Racingesia',   'Signskin',   'SubjectInvent',   'Treburg',   'TwistFinalCampy',   'TwitJuz',   'Ativarra',   'Banorch',   'Bigglewite',   'ChattyRoses',   'Confluest',   'Culetse',   'Dallumen',   'EatsIntcatRap',   'Galeryte',   'GrantPsych',   'Greatedinba',   'Humancessai',   'JimCommunique',   'Kadroni',   'Leninera',   'Magazinete',   'Neporemi',   'Nurseyf',   'Ortholewe',   'Oxinture',   'PitcherFairy',   'Popularisca',   'Puressahan',   'Quickerea',   'Rebanica',   'Rederesyste',   'Rushopau',   'Sandield',   'Scriosco',   'Senderfo'
}

M.reserved = {}
M.fakeName = {}

for _,v in pairs(reserved) do
  M.reserved[v] = v
end

for _,v in pairs(fakeName) do
  M.fakeName[v] = v
end

function M:IsReserved(name)
  if self.reserved[name] or self.fakeName[name] then
    return true
  end
end

function M:GetRandom()
  return fakeName[math.random(1, #fakeName)]
end

-- local short = ''
-- for word in fakeName:gmatch('(%w+)') do
--   short = short.."'"..word.."',   "
-- end


return M
