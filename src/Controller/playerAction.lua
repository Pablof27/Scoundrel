--[[
    PlayerAction
    Defines the different actions a player can perform.
    Each action knows how to execute itself on a GameState and declares
    its eventType so the Controller can publish the right event.
]]

local PlayerAction = {}
PlayerAction.__index = PlayerAction

function PlayerAction:new()
    self.isUndo = false
    return self
end

-- UndoAction --
local UndoAction = setmetatable({}, PlayerAction)
UndoAction.__index = UndoAction

function UndoAction:new()
    local o = setmetatable({}, self)
    o.isUndo = true
    o.eventType = nil  -- undo publishes its own events in Game:perform
    return o
end

function UndoAction:execute(gameState)
    return true  -- undo is handled entirely by the Game controller
end

-- SkipRoomAction --
local SkipRoomAction = setmetatable({}, PlayerAction)
SkipRoomAction.__index = SkipRoomAction

function SkipRoomAction:new()
    local o = setmetatable({}, self)
    o.isUndo = false
    o.eventType = "roomChanged"
    return o
end

function SkipRoomAction:execute(gameState)
    return gameState:skipRoomIfPossible()
end

-- NextRoomAction --
local NextRoomAction = setmetatable({}, PlayerAction)
NextRoomAction.__index = NextRoomAction

function NextRoomAction:new()
    local o = setmetatable({}, self)
    o.isUndo = false
    o.eventType = "roomChanged"
    return o
end

function NextRoomAction:execute(gameState)
    return gameState:nextRoomIfPossible()
end

-- PlayCardAction --
local PlayCardAction = setmetatable({}, PlayerAction)
PlayCardAction.__index = PlayCardAction

function PlayCardAction:new(card, useArmor)
    local o = setmetatable({}, self)
    o.isUndo = false
    o.card = card
    o.useArmor = useArmor
    o.eventType = "cardPlayed"
    return o
end

function PlayCardAction:execute(gameState)
    return gameState:playCardIfPossible(self.card, self.useArmor)
end

return {
    UndoAction     = UndoAction,
    SkipRoomAction = SkipRoomAction,
    NextRoomAction = NextRoomAction,
    PlayCardAction = PlayCardAction
}
