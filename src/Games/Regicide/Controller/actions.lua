--[[
    Regicide actions
    None of them can be undone: taking back a turn would reveal Tavern draws, Heart shuffles or
    the next Royal waiting in the Castle deck.
]]

local Action = require("src.Controller.action")

-- Attack the current Royal with one card, an Animal Companion pair or an equal-rank combo.
---@class RegicidePlayCardAction
---@field cards table
local PlayCardAction = Action.extend({ eventType = "attacked" })

function PlayCardAction:new(cards)
    local o = setmetatable({}, self)
    o.cards = cards
    return o
end

function PlayCardAction:execute(gameState)
    return gameState:playCards(self.cards)
end

-- Discard cards from hand to absorb the Royal's counterattack.
---@class RegicideDefendAction
---@field cards table
local DefendAction = Action.extend({ eventType = "defended" })

function DefendAction:new(cards)
    local o = setmetatable({}, self)
    o.cards = cards
    return o
end

function DefendAction:execute(gameState)
    return gameState:defend(self.cards)
end

-- Flip a Solo Jester: discard your hand and refill to 8 cards.
---@class RegicidePlayJokerAction
local PlayJokerAction = Action.extend({ eventType = "jokerPlayed" })

function PlayJokerAction:new()
    return setmetatable({}, self)
end

function PlayJokerAction:execute(gameState)
    return gameState:playJoker()
end

return {
    PlayCardAction  = PlayCardAction,
    DefendAction    = DefendAction,
    PlayJokerAction = PlayJokerAction,
}

