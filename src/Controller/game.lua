--[[
    Game (Controller)
    Runs the state of the game being played, whatever the game: performs the actions published
    on the EventBus, keeps the undo history and detects the end of the game.

    A game state provides:
      isOver(), isVictory()  end of the game, queried after every action
      canUndo                whether the last action can be taken back right now
      errorMsg               set by actions that fail, for the log
]]

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

function Game:start(gameState)
    self.gameState = gameState
    self.history = {}
end

function Game:perform(action)
    local state = self.gameState
    if state == nil or state:isOver() then
        return
    end
    if action.isUndo then
        self:undo()
        return
    end

    local snapshot = action.undoable and DeepCopy(state) or nil
    state.errorMsg = nil
    if not action:execute(state) then
        print("Action could not be executed: " .. tostring(state.errorMsg))
        return
    end

    if snapshot then
        table.insert(self.history, snapshot)
    else
        -- Undo never crosses an action that can't be undone, so older snapshots are useless.
        self.history = {}
    end
    self.eventBus:publish(action.eventType, state, action:outcome(state))

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
