--[[
    Anim
    Small animation toolkit shared by the views: springs, "juice" wobbles and easing.
]]

local Anim = {}

local MAX_STEP = 1 / 120

-- Damped spring integration (semi-implicit Euler with fixed sub-steps for stability).
function Anim.spring(pos, vel, target, stiffness, damping, dt)
    local steps = math.max(1, math.ceil(dt / MAX_STEP))
    local h = dt / steps
    for _ = 1, steps do
        vel = vel + (stiffness * (target - pos) - damping * vel) * h
        pos = pos + vel * h
    end
    return pos, vel
end

-- Frame-rate independent exponential approach.
function Anim.approach(current, target, rate, dt)
    return target + (current - target) * math.exp(-rate * dt)
end

-- Linear approach with a maximum speed.
function Anim.moveTowards(current, target, maxDelta)
    if math.abs(target - current) <= maxDelta then
        return target
    end
    return current + (target > current and maxDelta or -maxDelta)
end

function Anim.clamp(value, low, high)
    return math.max(low, math.min(high, value))
end

function Anim.lerp(a, b, t)
    return a + (b - a) * t
end

--[[
    Juice: a short decaying wobble of scale and rotation, used to make things "pop".
    amount is the scale amplitude, rot the rotation amplitude (radians).
]]
function Anim.newJuice(amount, rot, duration)
    if rot == nil then
        rot = (love.math.random() < 0.5 and -1 or 1) * 0.6 * amount
    end
    return { amount = amount, rot = rot, t = 0, duration = duration or 0.4, scale = 0, r = 0 }
end

-- Advances a juice table; returns nil once it has finished.
function Anim.updateJuice(juice, dt)
    if not juice then
        return nil
    end
    juice.t = juice.t + dt
    if juice.t >= juice.duration then
        return nil
    end
    local remaining = (juice.duration - juice.t) / juice.duration
    juice.scale = juice.amount * math.sin(50.8 * juice.t) * remaining ^ 3
    juice.r = juice.rot * math.sin(40.8 * juice.t) * remaining ^ 2
    return juice
end

function Anim.easeOutBack(t)
    local c1 = 1.70158
    local c3 = c1 + 1
    return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
end

function Anim.easeOutCubic(t)
    return 1 - (1 - t) ^ 3
end

return Anim
