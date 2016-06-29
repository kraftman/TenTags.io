local giflib = require("giflib")

local gif = assert(giflib.load_gif("test2.gif"))
gif:write_first_frame("test-frame-1.gif")
gif:close()
