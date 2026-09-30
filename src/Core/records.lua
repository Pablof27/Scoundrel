--[[
    Records
    Lifetime statistics across runs (runs played, wins, best score), persisted between sessions.
]]

local Storage = require("src.Core.storage")

local Records = {}
Records.__index = Records

local FILENAME = "records.txt"

local DEFAULTS = {
    gamesPlayed   = 0,
    gamesWon      = 0,
    hasBestScore  = false,
    bestScore     = 0,
}

function Records:new()
    local o = setmetatable({}, self)
    o.values = Storage.load(FILENAME, DEFAULTS)
    return o
end

function Records:get(key)
    return self.values[key]
end

-- Stores the result of a finished run. Returns true when the score is a new personal best.
function Records:registerRun(didWin, score)
    local values = self.values
    values.gamesPlayed = values.gamesPlayed + 1
    if didWin then
        values.gamesWon = values.gamesWon + 1
    end
    local isBest = not values.hasBestScore or score > values.bestScore
    if isBest then
        values.hasBestScore = true
        values.bestScore = score
    end
    Storage.save(FILENAME, values)
    return isBest
end

return Records
