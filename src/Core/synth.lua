--[[
    Synth
    Tiny offline synthesizer. Every sound effect and the music loop are rendered into
    SoundData when the game starts, so the game ships without audio files.
    A buffer is a plain Lua array of float samples with `n` (length) and `rate` fields.
]]

local Synth = {}

local TAU = math.pi * 2
local sin, abs, exp, floor, min = math.sin, math.abs, math.exp, math.floor, math.min

Synth.waves = {
    sine     = function(p) return sin(TAU * p) end,
    triangle = function(p) return 1 - 4 * abs(p % 1 - 0.5) end,
    saw      = function(p) return 2 * (p % 1) - 1 end,
    square   = function(p, duty) return p % 1 < duty and 1 or -1 end,
}

-- MIDI note number (A4 = 69) to frequency in Hz.
function Synth.freq(note)
    return 440 * 2 ^ ((note - 69) / 12)
end

function Synth.buffer(seconds, rate)
    rate = rate or 44100
    local n = floor(seconds * rate)
    local buffer = { n = n, rate = rate }
    for i = 1, n do
        buffer[i] = 0
    end
    return buffer
end

-- Linear attack, exponential decay (time constant `decay`, none if nil), linear release at the end.
local function envelope(t, duration, attack, decay, release)
    local e = 1
    if t < attack then
        e = t / attack
    elseif decay then
        e = exp(-(t - attack) / decay)
    end
    local left = duration - t
    if left < release then
        e = e * left / release
    end
    return e
end

-- Sample index for offset k of a sound starting at `start`, or nil once past a non-looping buffer.
local function indexAt(buffer, start, k, wrap)
    local index = start + k
    if wrap then
        return index % buffer.n + 1
    end
    if index >= buffer.n then
        return nil
    end
    return index + 1
end

--[[
    Adds a note to the buffer. Options:
      at, duration (seconds)       freq, slide (end frequency, exponential glide)
      wave, duty, volume           attack, decay, release (envelope, seconds)
      vibrato, vibratoRate         depth in semitones, speed in Hz
      lowpass                      one-pole cutoff in Hz
      wrap                         samples past the end wrap to the start (seamless loops)
]]
function Synth.tone(buffer, o)
    local rate = buffer.rate
    local wave = Synth.waves[o.wave or "sine"]
    local duty = o.duty or 0.5
    local volume = o.volume or 1
    local attack, decay, release = o.attack or 0.005, o.decay, o.release or 0.01
    local duration = o.duration
    local f0 = o.freq
    local ratio = (o.slide or f0) / f0
    local vibrato, vibratoRate = o.vibrato or 0, o.vibratoRate or 5
    local alpha = o.lowpass and (1 - exp(-TAU * o.lowpass / rate))
    local start = floor((o.at or 0) * rate)
    local phase, filtered = 0, 0

    for k = 0, floor(duration * rate) - 1 do
        local index = indexAt(buffer, start, k, o.wrap)
        if not index then
            break
        end
        local t = k / rate
        local f = ratio == 1 and f0 or f0 * ratio ^ (t / duration)
        if vibrato ~= 0 then
            -- 2^(x/12) ~ 1 + 0.0578x for the fraction-of-a-semitone depths used here.
            f = f * (1 + 0.0578 * vibrato * sin(TAU * vibratoRate * t))
        end
        phase = phase + f / rate
        local s = wave(phase, duty)
        if alpha then
            filtered = filtered + alpha * (s - filtered)
            s = filtered
        end
        buffer[index] = buffer[index] + s * volume * envelope(t, duration, attack, decay, release)
    end
end

--[[
    Adds filtered white noise. Same timing/envelope options as tone, plus:
      filter ("lowpass", "bandpass" or "highpass"), cutoff, sweep (end cutoff), resonance (0..0.95), seed
]]
function Synth.noise(buffer, o)
    local rate = buffer.rate
    local random = love.math.newRandomGenerator(o.seed or 1)
    local volume = o.volume or 1
    local attack, decay, release = o.attack or 0.002, o.decay, o.release or 0.01
    local duration = o.duration
    local mode = o.filter or "lowpass"
    local c0 = o.cutoff or 4000
    local ratio = (o.sweep or c0) / c0
    local k = 2 - 2 * min(o.resonance or 0, 0.95)
    local maxCutoff = rate * 0.45
    local start = floor((o.at or 0) * rate)
    local ic1, ic2 = 0, 0

    -- Zero-delay-feedback state-variable filter (stable at any cutoff).
    for step = 0, floor(duration * rate) - 1 do
        local index = indexAt(buffer, start, step, o.wrap)
        if not index then
            break
        end
        local t = step / rate
        local g = math.tan(math.pi * min(c0 * ratio ^ (t / duration), maxCutoff) / rate)
        local a1 = 1 / (1 + g * (g + k))
        local a2 = g * a1
        local input = random:random() * 2 - 1
        local v3 = input - ic2
        local band = a1 * ic1 + a2 * v3
        local low = ic2 + a2 * ic1 + g * a2 * v3
        ic1 = 2 * band - ic1
        ic2 = 2 * low - ic2
        local s = band
        if mode == "lowpass" then
            s = low
        elseif mode == "highpass" then
            s = input - k * band - low
        end
        buffer[index] = buffer[index] + s * volume * envelope(t, duration, attack, decay, release)
    end
end

-- Feedback delay that wraps around the buffer, so a looping track keeps its echoes across the seam.
function Synth.echo(buffer, delay, feedback)
    local n = buffer.n
    local d = floor(delay * buffer.rate)
    local dry = {}
    for i = 1, n do
        dry[i] = buffer[i]
    end
    -- Second pass picks up the echoes of the loop's tail at its start.
    for _ = 1, 2 do
        for i = 1, n do
            local j = i - d
            if j < 1 then
                j = j + n
            end
            buffer[i] = dry[i] + feedback * buffer[j]
        end
    end
end

-- Normalizes the buffer to `peak` and converts it to 16-bit mono SoundData.
function Synth.toSoundData(buffer, peak)
    local loudest = 0
    for i = 1, buffer.n do
        loudest = math.max(loudest, abs(buffer[i]))
    end
    local gain = loudest > 0 and peak / loudest or 0
    local data = love.sound.newSoundData(buffer.n, buffer.rate, 16, 1)
    for i = 1, buffer.n do
        data:setSample(i - 1, buffer[i] * gain)
    end
    return data
end

return Synth
