--[[
    Records
    Lifetime statistics of one game (games played, wins, best scores...), persisted between sessions
    in the game's own file. Each game decides what it records (see `registerResult` in src/Games).
]]

local Storage = require("src.Core.storage")

local Records = {}
Records.__index = Records

-- defaults: every key the game records, with its initial value (booleans, numbers or strings).
function Records:new(filename, defaults)
    local o = setmetatable({}, self)
    o.filename = filename
    o.values = Storage.load(filename, defaults)
    return o
end

function Records:get(key)
    return self.values[key]
end

function Records:set(key, value)
    self.values[key] = value
end

function Records:add(key, amount)
    self.values[key] = self.values[key] + (amount or 1)
end

function Records:save()
    Storage.save(self.filename, self.values)
end

return Records
