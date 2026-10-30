--[[
    Scoundrel actions
    Resolving a card can be undone until the room changes; fleeing and dealing the next room can't.
]]

local Action = require("src.Controller.action")

-- Flee the room: its cards go to the bottom of the dungeon and a new room is dealt.
local SkipRoomAction = Action.extend({ eventType = "roomChanged", reason = "flee" })

function SkipRoomAction:new()
    return setmetatable({}, self)
end

function SkipRoomAction:execute(gameState)
    return gameState:skipRoomIfPossible()
end

function SkipRoomAction:outcome()
    return self.reason
end

-- Deal the next room around the card that stayed.
local NextRoomAction = Action.extend({ eventType = "roomChanged", reason = "next" })

function NextRoomAction:new()
    return setmetatable({}, self)
end

function NextRoomAction:execute(gameState)
    return gameState:nextRoomIfPossible()
end

function NextRoomAction:outcome()
    return self.reason
end

-- Resolve a card of the room (useArmor: fight a monster with the weapon when possible).
local PlayCardAction = Action.extend({ eventType = "cardPlayed", undoable = true })

function PlayCardAction:new(card, useArmor)
    local o = setmetatable({}, self)
    o.card = card
    o.useArmor = useArmor
    return o
end

function PlayCardAction:execute(gameState)
    return gameState:playCardIfPossible(self.card, self.useArmor)
end

return {
    UndoAction     = Action.UndoAction,
    SkipRoomAction = SkipRoomAction,
    NextRoomAction = NextRoomAction,
    PlayCardAction = PlayCardAction,
}
