--[[
    Game (Controller)
    Orchestrates game actions and undo history.
    Subscribes to events from the EventBus and publishes state-change events.
    Owns end-game detection (moved out of GameState).
]]

local GameState = require("src.Model.gameState")

local Game = {}
Game.__index = Game

function Game:new(eventBus)
    local o = setmetatable({}, self)
    o.gameState = nil
    o.history   = {}
    o.eventBus  = eventBus

    eventBus:subscribe("action", function(action)
        o:perform(action)
    end)

    return o
end

function Game:start()
    self.gameState = GameState:new()
    self.history = {}
end

function Game:perform(action)
    if self.gameState == nil or self.gameState:isOver() then
        return
    end
    if action.isUndo then
        self:undo()
        return
    end

    local snapshot = DeepCopy(self.gameState)
    if not self.gameState:nextState(action) then
        return
    end

    if action.eventType == "roomChanged" then
        -- Undo never crosses into a previous room, so older snapshots are useless.
        self.history = {}
        self.eventBus:publish("roomChanged", self.gameState, action.reason)
    else
        table.insert(self.history, snapshot)
        self.eventBus:publish("cardPlayed", self.gameState, self.gameState.lastOutcome)
    end

    self:checkEndGame()
end

function Game:canUndo()
    return self.gameState.canUndo and #self.history > 0
end

function Game:undo()
    if not self:canUndo() then
        return false
    end
    self.gameState = table.remove(self.history)
    self.eventBus:publish("stateRestored", self.gameState)
    return true
end

function Game:checkEndGame()
    if self.gameState:isOver() then
        self.eventBus:publish("endGame", self.gameState:isVictory(), self.gameState)
    end
end

return Game