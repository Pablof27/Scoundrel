--[[
    Sounds
    Recipes for every sound effect, rendered with Synth.
    Sounds.generate() returns name -> SoundData.
]]

local Synth = require("src.Core.synth")

local tone, noise, freq = Synth.tone, Synth.noise, Synth.freq

local Sounds = {}

-- name -> { duration (s), peak (relative loudness), build(buffer) }
local RECIPES = {
    -- Soft tick when the mouse enters a button or a card.
    hover = { duration = 0.05, peak = 0.22, build = function(b)
        tone(b, { duration = 0.05, freq = 1500, slide = 1800, wave = "triangle", decay = 0.012 })
    end },

    click = { duration = 0.1, peak = 0.4, build = function(b)
        tone(b, { duration = 0.04, freq = 520, wave = "square", duty = 0.25, decay = 0.02, lowpass = 3000 })
        tone(b, { at = 0.03, duration = 0.07, freq = 780, wave = "square", duty = 0.25, decay = 0.025, lowpass = 3000 })
    end },

    -- Disabled button / action not allowed.
    denied = { duration = 0.18, peak = 0.35, build = function(b)
        for i = 0, 1 do
            tone(b, { at = i * 0.09, duration = 0.07, freq = 140, wave = "square", lowpass = 900, release = 0.02 })
        end
    end },

    -- A setting value changed.
    toggle = { duration = 0.07, peak = 0.35, build = function(b)
        tone(b, { duration = 0.07, freq = 880, slide = 1320, wave = "triangle", decay = 0.03 })
    end },

    -- Card sliding over the table.
    deal = { duration = 0.1, peak = 0.3, build = function(b)
        noise(b, { duration = 0.09, filter = "bandpass", cutoff = 1800, sweep = 5000, resonance = 0.3,
            attack = 0.004, decay = 0.025 })
        tone(b, { at = 0.05, duration = 0.04, freq = 240, slide = 160, wave = "triangle", decay = 0.01, volume = 0.5 })
    end },

    -- Taking damage: a low punch with a crunchy edge.
    hit = { duration = 0.32, peak = 0.85, build = function(b)
        tone(b, { duration = 0.3, freq = 170, slide = 40, decay = 0.09 })
        tone(b, { duration = 0.12, freq = 95, slide = 60, wave = "square", duty = 0.3, decay = 0.04,
            lowpass = 900, volume = 0.5 })
        noise(b, { duration = 0.22, filter = "lowpass", cutoff = 2500, sweep = 300, decay = 0.05, volume = 0.9 })
    end },

    -- Weapon blocking a monster: metallic clang (inharmonic partials).
    block = { duration = 0.6, peak = 0.5, build = function(b)
        local partials = { { 520, 1, 0.35 }, { 1340, 0.6, 0.22 }, { 2090, 0.45, 0.15 }, { 2830, 0.3, 0.1 } }
        for _, p in ipairs(partials) do
            tone(b, { duration = 0.6, freq = p[1], volume = p[2], decay = p[3], attack = 0.001 })
        end
        noise(b, { duration = 0.04, filter = "highpass", cutoff = 3000, decay = 0.01, volume = 0.8 })
    end },

    -- Equipping a weapon: blade drawn from its sheath.
    equip = { duration = 0.55, peak = 0.5, build = function(b)
        tone(b, { duration = 0.08, freq = 600, slide = 300, wave = "triangle", decay = 0.02, volume = 0.4 })
        noise(b, { duration = 0.3, filter = "bandpass", cutoff = 1200, sweep = 6000, resonance = 0.5,
            attack = 0.06, decay = 0.08, volume = 0.6 })
        tone(b, { at = 0.05, duration = 0.5, freq = 1568, decay = 0.18, vibrato = 0.1, vibratoRate = 9, volume = 0.5 })
        tone(b, { at = 0.05, duration = 0.5, freq = 2350, decay = 0.12, volume = 0.3 })
    end },

    -- Drinking a potion: rising bells and a few bubbles.
    heal = { duration = 0.8, peak = 0.5, build = function(b)
        for i, note in ipairs({ 72, 76, 79, 84 }) do
            local at = (i - 1) * 0.07
            tone(b, { at = at, duration = 0.5, freq = freq(note), decay = 0.18, volume = 0.8 })
            tone(b, { at = at, duration = 0.3, freq = freq(note + 12), decay = 0.08, volume = 0.25 })
        end
        local random = love.math.newRandomGenerator(7)
        for _ = 1, 6 do
            local f = 500 + random:random() * 500
            tone(b, { at = random:random() * 0.4, duration = 0.06, freq = f, slide = f * 2.2, decay = 0.03,
                volume = 0.25 })
        end
    end },

    -- Card burning away: soft fire bed with crackles.
    burn = { duration = 0.8, peak = 0.4, build = function(b)
        noise(b, { duration = 0.8, filter = "lowpass", cutoff = 600, sweep = 1500, attack = 0.12, decay = 0.25,
            volume = 0.6 })
        local random = love.math.newRandomGenerator(3)
        for i = 1, 26 do
            noise(b, { at = random:random() * 0.65, duration = 0.015, filter = "highpass",
                cutoff = 1500 + random:random() * 2500, decay = 0.003, volume = 0.3 + random:random() * 0.5, seed = i })
        end
    end },

    -- Fleeing a room: whoosh.
    flee = { duration = 0.55, peak = 0.5, build = function(b)
        noise(b, { duration = 0.55, filter = "bandpass", cutoff = 250, sweep = 2500, resonance = 0.6,
            attack = 0.25, release = 0.28 })
        tone(b, { duration = 0.45, freq = 520, slide = 180, wave = "triangle", attack = 0.05, decay = 0.2, volume = 0.25 })
    end },

    -- Undo: two rising blips, like rewinding.
    undo = { duration = 0.22, peak = 0.4, build = function(b)
        tone(b, { duration = 0.1, freq = 330, slide = 660, wave = "triangle", decay = 0.05, volume = 0.8 })
        tone(b, { at = 0.08, duration = 0.14, freq = 495, slide = 990, wave = "triangle", decay = 0.06 })
    end },

    -- New room: two bell notes.
    room = { duration = 0.9, peak = 0.32, build = function(b)
        for i, note in ipairs({ 69, 76 }) do
            local at = (i - 1) * 0.1
            tone(b, { at = at, duration = 0.8, freq = freq(note), decay = 0.25, volume = 0.8 })
            tone(b, { at = at, duration = 0.5, freq = freq(note) * 3, decay = 0.08, volume = 0.15 })
        end
    end },

    -- Shuffling the deck: a riffle of card flicks, then the deck is squared up.
    shuffle = { duration = 0.7, peak = 0.35, build = function(b)
        local random = love.math.newRandomGenerator(11)
        for i = 0, 17 do
            noise(b, { at = i * 0.028 + random:random() * 0.006, duration = 0.025, filter = "bandpass",
                cutoff = 2200 + random:random() * 1500, resonance = 0.3, attack = 0.002, decay = 0.008,
                volume = 0.6 + random:random() * 0.4, seed = i + 1 })
        end
        noise(b, { at = 0.55, duration = 0.1, filter = "lowpass", cutoff = 900, decay = 0.03, volume = 0.7 })
        tone(b, { at = 0.55, duration = 0.1, freq = 150, slide = 90, decay = 0.03, volume = 0.5 })
    end },

    -- Capturing cards: a crisp snap with a low thump.
    capture = { duration = 0.35, peak = 0.5, build = function(b)
        noise(b, { duration = 0.05, filter = "highpass", cutoff = 2500, decay = 0.012, volume = 0.9 })
        tone(b, { duration = 0.3, freq = 220, slide = 110, wave = "triangle", decay = 0.07, volume = 0.8 })
        tone(b, { at = 0.02, duration = 0.25, freq = 880, slide = 1320, wave = "square", duty = 0.25,
            lowpass = 3000, decay = 0.05, volume = 0.25 })
    end },

    -- The wolf feeds: a short howl rising and falling.
    howl = { duration = 1.2, peak = 0.4, build = function(b)
        tone(b, { duration = 0.4, freq = 300, slide = 500, wave = "triangle", lowpass = 1800, attack = 0.15,
            release = 0.05, vibrato = 0.15, vibratoRate = 6, volume = 0.8 })
        tone(b, { at = 0.38, duration = 0.8, freq = 500, slide = 280, wave = "triangle", lowpass = 1800,
            attack = 0.03, release = 0.45, vibrato = 0.3, vibratoRate = 6, volume = 0.8 })
        noise(b, { duration = 1.1, filter = "bandpass", cutoff = 500, sweep = 900, resonance = 0.5,
            attack = 0.2, release = 0.5, volume = 0.12 })
    end },

    -- Escaped the dungeon: short fanfare resolving on A major.
    victory = { duration = 1.9, peak = 0.6, build = function(b)
        for i, note in ipairs({ 69, 73, 76 }) do
            tone(b, { at = (i - 1) * 0.12, duration = 0.14, freq = freq(note), wave = "square", duty = 0.25,
                lowpass = 3000, release = 0.03, volume = 0.5 })
        end
        for _, note in ipairs({ 69, 81, 85, 88 }) do
            tone(b, { at = 0.36, duration = 1.5, freq = freq(note), wave = "triangle", vibrato = 0.12, vibratoRate = 6,
                attack = 0.02, decay = 0.7, release = 0.3, volume = 0.45 })
        end
        tone(b, { at = 0.36, duration = 1.5, freq = freq(81), wave = "square", duty = 0.25, lowpass = 2500,
            decay = 0.4, release = 0.3, volume = 0.25 })
        tone(b, { at = 0.36, duration = 1.5, freq = freq(45), wave = "triangle", decay = 0.6, release = 0.3, volume = 0.6 })
    end },

    -- Slain: sad descending trombone.
    defeat = { duration = 2.3, peak = 0.55, build = function(b)
        for i, note in ipairs({ 64, 63, 62 }) do
            tone(b, { at = (i - 1) * 0.32, duration = 0.3, freq = freq(note), wave = "square", lowpass = 1400,
                vibrato = 0.1, release = 0.05, volume = 0.5 })
        end
        tone(b, { at = 0.96, duration = 1.3, freq = freq(61), slide = freq(59), wave = "square", lowpass = 1200,
            vibrato = 0.35, vibratoRate = 5, decay = 0.8, release = 0.3, volume = 0.5 })
        tone(b, { duration = 2.2, freq = 55, slide = 38, attack = 0.3, decay = 1.0, release = 0.4, volume = 0.5 })
    end },
}

function Sounds.generate()
    local data = {}
    for name, recipe in pairs(RECIPES) do
        local buffer = Synth.buffer(recipe.duration)
        recipe.build(buffer)
        data[name] = Synth.toSoundData(buffer, recipe.peak)
    end
    return data
end

return Sounds
