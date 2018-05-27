

local M = {}

M.reactions = {
    thumbsup = 'thumbsup',
    thumbsdown = 'thumbsdown',
    funny = 'funny',
    sad = 'sad',
    angry = 'angry'
}

M.commentSorts = {
    top = 'Top',
    new = 'New',
    funny = 'Funny',
    angry = 'Controversial',
    sad = 'Sad',
    best = 'Best',
    thumbsup = 'Interesting'
}

M.reactionPositive = {
    thumbsup = true,
    thumbsdown = false,
    funny = true,
    sad = true,
    angry = false,
}
-- top = highest positively voted
-- best = bayesian

return M