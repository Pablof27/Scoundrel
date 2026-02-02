
local GameState = require("src.Model.gameState")

local Game = {}

function Game:start(gameView)
    self.gameState = GameState:start()
    self.listener = gameView
end

function Game:perform(action)
    self.gameState:nextState(action)
    action:notifyListener(self.listener, self)
    self.gameState:checkEndGame()
end

return Game