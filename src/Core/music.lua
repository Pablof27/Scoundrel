--[[
    Music
    A 16-bar dungeon loop in A minor: soft pad, bass, plucked arpeggio and a quiet kick.
    The second half adds a lead melody and a shaker. Rendered once into a seamless loop.
]]

local Synth = require("src.Core.synth")

local tone, noise, freq = Synth.tone, Synth.noise, Synth.freq

local Music = {}

local RATE = 22050
local BEAT = 60 / 84
local BAR  = BEAT * 4

-- One triad (MIDI notes) per bar.
local CHORDS = {
    { 57, 60, 64 }, -- Am
    { 53, 57, 60 }, -- F
    { 50, 53, 57 }, -- Dm
    { 52, 56, 59 }, -- E
    { 57, 60, 64 }, -- Am
    { 53, 57, 60 }, -- F
    { 55, 59, 62 }, -- G7
    { 52, 56, 59 }, -- E
}

-- Eighth-note arpeggio over { root, third, fifth, octave }.
local ARPEGGIO = { 1, 3, 2, 3, 4, 3, 2, 3 }

-- Lead for the second half, one line per bar: { beat, note, length in beats }.
local MELODY = {
    { { 0, 76, 1.5 }, { 1.5, 74, 0.5 }, { 2, 72, 1 }, { 3, 71, 0.5 }, { 3.5, 72, 0.5 } },
    { { 0, 69, 2 }, { 2, 72, 1 }, { 3, 77, 1 } },
    { { 0, 76, 1.5 }, { 1.5, 74, 0.5 }, { 2, 72, 0.5 }, { 2.5, 74, 0.5 }, { 3, 77, 1 } },
    { { 0, 76, 3 }, { 3, 68, 0.5 }, { 3.5, 71, 0.5 } },
    { { 0, 72, 1 }, { 1, 76, 1 }, { 2, 81, 1.5 }, { 3.5, 79, 0.5 } },
    { { 0, 77, 1 }, { 1, 76, 0.5 }, { 1.5, 74, 0.5 }, { 2, 72, 2 } },
    { { 0, 74, 1 }, { 1, 71, 1 }, { 2, 67, 1 }, { 3, 71, 1 } },
    { { 0, 68, 1 }, { 1, 71, 1 }, { 2, 76, 2 } },
}

-- Bass hits per bar: { beat, interval above the root, length in beats }.
local BASS = { { 0, 0, 1.4 }, { 1.5, 12, 0.4 }, { 2, 0, 1.9 } }

local function renderBar(buffer, bar)
    local chord = CHORDS[bar % #CHORDS + 1]
    local start = bar * BAR
    local withLead = bar >= #CHORDS

    for _, note in ipairs(chord) do
        tone(buffer, { at = start, duration = BAR + 0.3, freq = freq(note), wave = "saw", lowpass = 700,
            attack = 0.6, release = 0.5, vibrato = 0.06, vibratoRate = 0.7, volume = 0.07, wrap = true })
    end

    for _, hit in ipairs(BASS) do
        tone(buffer, { at = start + hit[1] * BEAT, duration = hit[3] * BEAT, freq = freq(chord[1] - 12 + hit[2]),
            wave = "triangle", lowpass = 600, decay = 0.6, release = 0.05, volume = 0.35, wrap = true })
    end

    local tones = { chord[1], chord[2], chord[3], chord[1] + 12 }
    for step, index in ipairs(ARPEGGIO) do
        tone(buffer, { at = start + (step - 1) * BEAT / 2, duration = 0.35, freq = freq(tones[index]),
            wave = "square", duty = 0.25, lowpass = 1600, decay = 0.09, volume = withLead and 0.14 or 0.18, wrap = true })
    end

    for beat = 0, 2, 2 do
        tone(buffer, { at = start + beat * BEAT, duration = 0.2, freq = 120, slide = 45, decay = 0.06,
            attack = 0.002, volume = 0.45, wrap = true })
    end

    if withLead then
        for _, n in ipairs(MELODY[bar % #CHORDS + 1]) do
            tone(buffer, { at = start + n[1] * BEAT, duration = n[3] * BEAT, freq = freq(n[2]), wave = "triangle",
                attack = 0.02, release = 0.08, vibrato = 0.15, vibratoRate = 5, volume = 0.22, wrap = true })
        end
        for beat = 0.5, 3.5 do
            noise(buffer, { at = start + beat * BEAT, duration = 0.04, filter = "highpass", cutoff = 3500,
                decay = 0.012, volume = 0.06, seed = bar * 8 + beat * 2, wrap = true })
        end
    end
end

function Music.generate()
    local bars = #CHORDS * 2
    local buffer = Synth.buffer(bars * BAR, RATE)
    for bar = 0, bars - 1 do
        renderBar(buffer, bar)
    end
    Synth.echo(buffer, BEAT * 0.75, 0.3)
    return Synth.toSoundData(buffer, 0.8)
end

return Music
