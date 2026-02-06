
local GameState = require("src.Model.gameState")

local Game = {}

function Game:start(gameView)
    self.gameState = GameState:start()
    self.listener = gameView
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
        action:notifyListener(self.listener, self)
        return
    end
    table.insert(self.history, DeepCopy(self.gameState))
    self.gameState:nextState(action)
    action:notifyListener(self.listener, self)
    self.gameState:checkEndGame()
end

return Game