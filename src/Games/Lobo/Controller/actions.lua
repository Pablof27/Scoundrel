--[[
    Lobo actions
    None of them can be undone: taking back a capture would reveal the cards it drew.
]]

local Action = require("src.Controller.action")

-- Capture Wolf cards (`theirs`) with cards of your hand (`mine`).
local CaptureAction = Action.extend({ eventType = "captured" })

function CaptureAction:new(mine, theirs)
    local o = setmetatable({}, self)
    o.mine = mine
    o.theirs = theirs
    return o
end

function CaptureAction:execute(gameState)
    return gameState:capture(self.mine, self.theirs)
end

-- Stop fighting this hand: the Wolf scores its cards.
local FoldAction = Action.extend({ eventType = "folded" })

function FoldAction:new()
    return setmetatable({}, self)
end

function FoldAction:execute(gameState)
    return gameState:fold()
end

-- Clear the table and deal the next hand of the match.
local NextHandAction = Action.extend({ eventType = "handDealt" })

function NextHandAction:new()
    return setmetatable({}, self)
end

function NextHandAction:execute(gameState)
    return gameState:nextHand()
end

return {
    CaptureAction  = CaptureAction,
    FoldAction     = FoldAction,
    NextHandAction = NextHandAction,
}
