local PlayerAction = {}
PlayerAction.__index = PlayerAction

function PlayerAction:new()
    return self
end
function PlayerAction.shouldChangePrev()
    return true
end

local UndoAction = setmetatable({
    shouldChangePrev = function() return false end
}, PlayerAction)
function UndoAction:execute(gameState)
    return gameState:goToPreviousStateIfPossible()
end
function UndoAction:notifyListener(listener, game)
end

local SkipRoomAction = setmetatable({}, PlayerAction)
function SkipRoomAction:execute(gameState)
    return gameState:skipRoomIfPossible()
end
function SkipRoomAction:notifyListener(listener, game)
    listener:onRoomChanged(game.gameState)
end

local NextRoomAction = setmetatable({}, PlayerAction)
function NextRoomAction:execute(gameState)
    return gameState:nextRoomIfPossible()
end
function NextRoomAction:notifyListener(listener, game)
end

local PlayCardAction = setmetatable({
    new = function (self, card, useArmor)
        self.card = card
        self.useArmor = useArmor
        return self
    end
}, PlayerAction)
function PlayCardAction:execute(gameState)
    return gameState:playCardIfPossible(self.card, self.useArmor)
end
function PlayCardAction:notifyListener(listener, game)
    listener:onRoomChanged(game.gameState)
    listener:onPlayerChanged(game.gameState)
end

return {
    UndoAction = UndoAction,
    SkipRoomAction = SkipRoomAction,
    NextRoomAction = NextRoomAction,
    PlayCardAction = PlayCardAction
}
