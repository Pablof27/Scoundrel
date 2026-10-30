--[[
    Action
    Base class of the actions a player performs. Every game defines its own actions with
    Action.extend; the Game controller runs them on the game's state.
      execute(gameState): applies the action, returns false if it isn't allowed.
      eventType:          event published on the EventBus after it succeeds, with (gameState, outcome).
      outcome(gameState): payload of that event; by default gameState.lastOutcome.
      undoable:           whether it can be undone. Any other action clears the undo history.
]]

local Action = {}
Action.__index = Action

Action.isUndo    = false
Action.undoable  = false
Action.eventType = "stateChanged"

-- Creates an action class. fields: defaults shared by its instances (eventType, undoable...).
function Action.extend(fields)
    local class = setmetatable(fields or {}, Action)
    class.__index = class
    return class
end

function Action:execute(gameState)
    return false
end

function Action:outcome(gameState)
    return gameState.lastOutcome
end

-- Takes back the last undoable action (handled entirely by the Game controller).
local UndoAction = Action.extend({ isUndo = true })

function UndoAction:new()
    return setmetatable({}, self)
end

Action.UndoAction = UndoAction

return Action
