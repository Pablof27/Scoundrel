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
    if action.isUndo then
        if not self.gameState.canUndo then
            self.gameState.errorMsg = "Cannot undo last action"
            return
        end
        local previousState = table.remove(self.history)
        if previousState == nil then
            self.gameState.errorMsg = "No previous state to go back to"
            return
        end
        self.gameState = previousState
        self.eventBus:publish("roomChanged", self.gameState)
        self.eventBus:publish("playerChanged", self.gameState)
        return
    end

    table.insert(self.history, DeepCopy(self.gameState))
    local lifesBefore = self.gameState.player.lifes
    self.gameState:nextState(action)

    if action.eventType == "roomChanged" then
        self.eventBus:publish("roomChanged", self.gameState)
    elseif action.eventType == "cardPlayed" then
        local delta = self.gameState.player.lifes - lifesBefore  -- positive = healed, negative = damaged
        self.eventBus:publish("cardPlayed", action.card, delta)
    end

    self:checkEndGame()
end

function Game:checkEndGame()
    if self.gameState:isPlayerDead() then
        self.eventBus:publish("endGame", false)
        return
    end
    if self.gameState:isVictory() then
        self.eventBus:publish("endGame", true)
        return
    end
end

return Game