--[[
    Settings
    User preferences, persisted between sessions.
    The general options below apply to every game; each game can declare its own options
    (e.g. Scoundrel's difficulty), which are stored in the same file.
    Publishes "settingChanged"(key, value) on the EventBus whenever a value changes.
]]

local Storage = require("src.Core.storage")

local Settings = {}
Settings.__index = Settings

local FILENAME = "settings.txt"

local VOLUMES      = { 0, 0.25, 0.5, 0.75, 1 }
local VOLUME_NAMES = { "Off", "25%", "50%", "75%", "100%" }

local CARD_BACKS = { 1, 2, 3, 4, 5, 6, 7, 8 }
local CARD_BACK_NAMES = { "Red", "Blue", "Orange", "Green", "Black", "Purple", "Galaxy", "Zodiac" }

--[[
    Options of every game, in the order shown in the settings screen. Each option has a unique `key`,
    a `label`, its `values` and their `names`. `default` falls back to the first value.
    Optional `details` (one per value) and `note` explain the current value next to the settings panel.
]]
Settings.OPTIONS = {
    { key = "music",       label = "Music",           values = VOLUMES,          names = VOLUME_NAMES, default = 0.5 },
    { key = "sound",       label = "Sound effects",   values = VOLUMES,          names = VOLUME_NAMES, default = 0.75 },
    { key = "fullscreen",  label = "Fullscreen",      values = { false, true },  names = { "Off", "On" } },
    { key = "crt",         label = "CRT effect",      values = { true, false },  names = { "On", "Off" } },
    { key = "screenShake", label = "Screen shake",    values = { true, false },  names = { "On", "Off" } },
    { key = "animSpeed",   label = "Animation speed", values = { 1, 1.5, 2 },    names = { "Normal", "Fast", "Faster" } },
    { key = "cardBack",    label = "Card back",       values = CARD_BACKS,       names = CARD_BACK_NAMES },
    { key = "showFps",     label = "Show FPS",        values = { false, true },  names = { "Off", "On" } },
}

-- Browsers only allow fullscreen from a click on the page, so the web page has its own button instead.
if Constants.IS_WEB then
    for i, option in ipairs(Settings.OPTIONS) do
        if option.key == "fullscreen" then
            table.remove(Settings.OPTIONS, i)
            break
        end
    end
end

-- gameOptions: the options declared by the games, with the same fields as Settings.OPTIONS.
function Settings:new(eventBus, gameOptions)
    local o = setmetatable({}, self)
    o.eventBus = eventBus
    o.byKey = {}
    local defaults = {}
    local function register(option)
        o.byKey[option.key] = option
        if option.default ~= nil then
            defaults[option.key] = option.default
        else
            defaults[option.key] = option.values[1]
        end
    end
    for _, option in ipairs(Settings.OPTIONS) do
        register(option)
    end
    for _, option in ipairs(gameOptions or {}) do
        register(option)
    end
    o.values = Storage.load(FILENAME, defaults)
    return o
end

-- Options listed by the settings screen: the game's own options first (when opened from a game),
-- then the general ones.
function Settings:screenOptions(game)
    local list = {}
    for _, option in ipairs(game and game.options or {}) do
        table.insert(list, option)
    end
    for _, option in ipairs(Settings.OPTIONS) do
        table.insert(list, option)
    end
    return list
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
    return self.byKey[key]
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

-- Explanation of the current value, for options that have `details`.
function Settings:details(key)
    local option = self:option(key)
    if not option.details then
        return nil
    end
    for i, value in ipairs(option.values) do
        if value == self.values[key] then
            return option.details[i]
        end
    end
    return nil
end

return Settings
