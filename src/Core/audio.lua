--[[
    Audio
    Owns the generated sound effects and music loop, and plays them at the volumes
    chosen in the settings.
]]

local Sounds = require("src.Core.sounds")

local Audio = {}
Audio.__index = Audio

local MAX_VOICES = 6    -- simultaneous copies of the same effect
local MUSIC_GAIN = 0.55 -- keeps the loop under the effects

-- Rendering the music takes most of a second, so it happens off the main thread.
local MUSIC_THREAD = [[
require("love.sound")
require("love.math")
love.thread.getChannel("music"):push(require("src.Core.music").generate())
]]

function Audio:new()
    local o = setmetatable({}, self)
    o.pools       = {}  -- name -> list of Sources
    o.music       = nil -- Source, once the background render is done
    o.musicVolume = 1
    o.soundVolume = 1
    return o
end

function Audio:load()
    for name, data in pairs(Sounds.generate()) do
        self.pools[name] = { love.audio.newSource(data, "static") }
    end
    love.thread.newThread(MUSIC_THREAD):start()
end

function Audio:update()
    if self.music then
        return
    end
    local data = love.thread.getChannel("music"):pop()
    if data then
        self.music = love.audio.newSource(data, "static")
        self.music:setLooping(true)
        self:setMusicVolume(self.musicVolume)
    end
end

function Audio:freeSource(name)
    local pool = self.pools[name]
    for _, source in ipairs(pool) do
        if not source:isPlaying() then
            return source
        end
    end
    if #pool < MAX_VOICES then
        local source = pool[1]:clone()
        table.insert(pool, source)
        return source
    end
    return nil
end

-- opts: volume, pitch, variation (random pitch spread, 0.1 = +-5%)
function Audio:play(name, opts)
    if self.soundVolume <= 0 then
        return
    end
    opts = opts or {}
    local source = self:freeSource(name)
    if not source then
        return
    end
    source:setVolume(self.soundVolume * (opts.volume or 1))
    source:setPitch((opts.pitch or 1) * (1 + (love.math.random() - 0.5) * (opts.variation or 0)))
    source:play()
end

function Audio:setSoundVolume(volume)
    self.soundVolume = volume
end

function Audio:setMusicVolume(volume)
    self.musicVolume = volume
    if not self.music then
        return
    end
    self.music:setVolume(volume * MUSIC_GAIN)
    if volume <= 0 then
        self.music:pause()
    elseif not self.music:isPlaying() then
        self.music:play()
    end
end

return Audio
