--[[
    Settings
    User preferences, persisted between sessions.
    Publishes "settingChanged"(key, value) on the EventBus whenever a value changes.
]]

local Storage = require("src.Core.storage")

local Settings = {}
Settings.__index = Settings

local FILENAME = "settings.txt"

-- Order here is the order shown in the settings screen.
Settings.OPTIONS = {
    { key = "fullscreen",  label = "Fullscreen",      values = { false, true },  names = { "Off", "On" } },
    { key = "crt",         label = "CRT effect",      values = { true, false },  names = { "On", "Off" } },
    { key = "screenShake", label = "Screen shake",    values = { true, false },  names = { "On", "Off" } },
    { key = "animSpeed",   label = "Animation speed", values = { 1, 1.5, 2 },    names = { "Normal", "Fast", "Faster" } },
    { key = "cardBack",    label = "Card back",       values = { 1, 2, 3, 4, 5, 6, 7, 8 },
      names = { "Red", "Blue", "Orange", "Green", "Black", "Purple", "Galaxy", "Zodiac" } },
    { key = "showFps",     label = "Show FPS",        values = { false, true },  names = { "Off", "On" } },
}

local DEFAULTS = {}
for _, option in ipairs(Settings.OPTIONS) do
    DEFAULTS[option.key] = option.values[1]
end

function Settings:new(eventBus)
    local o = setmetatable({}, self)
    o.eventBus = eventBus
    o.values = Storage.load(FILENAME, DEFAULTS)
    return o
end

function Settings:get(key)
    return self.values[key]
end

function Settings:set(key, value)
    if self.values[key] == value then
        return
    end
    self.values[key] = value
    Storage.save(FILENAME, self.values)
    self.eventBus:publish("settingChanged", key, value)
end

function Settings:option(key)
    for _, option in ipairs(self.OPTIONS) do
        if option.key == key then
            return option
        end
    end
end

-- Moves the option to its next (dir = 1) or previous (dir = -1) value, wrapping around.
function Settings:cycle(key, dir)
    local option = self:option(key)
    local index = 1
    for i, value in ipairs(option.values) do
        if value == self.values[key] then
            index = i
        end
    end
    index = (index - 1 + (dir or 1)) % #option.values + 1
    self:set(key, option.values[index])
end

function Settings:displayValue(key)
    local option = self:option(key)
    for i, value in ipairs(option.values) do
        if value == self.values[key] then
            return option.names[i]
        end
    end
    return tostring(self.values[key])
end

return Settings
