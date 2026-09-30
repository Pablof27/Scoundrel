--[[
    Effects
    Short-lived visual feedback: popping floating texts and small particle bursts.
]]

local Anim = require("src.View.anim")
local UI   = require("src.View.ui")

local Effects = {}
Effects.__index = Effects

local GRAVITY = 260

function Effects:new(assets)
    local o = setmetatable({}, self)
    o.assets    = assets
    o.texts     = {}
    o.particles = {}
    return o
end

-- Label that pops in, rises and fades out.
function Effects:floatText(text, x, y, color, opts)
    opts = opts or {}
    table.insert(self.texts, {
        text     = text,
        x        = x,
        y        = y,
        color    = color,
        font     = opts.font or self.assets.fonts.large,
        t        = 0,
        delay    = opts.delay or 0,
        duration = opts.duration or 1.1,
        rise     = opts.rise or 26,
        rot      = (love.math.random() - 0.5) * 0.3,
    })
end

function Effects:burst(x, y, color, count, opts)
    opts = opts or {}
    for _ = 1, count do
        local angle = love.math.random() * math.pi * 2
        local speed = (opts.speed or 90) * (0.4 + love.math.random() * 0.8)
        table.insert(self.particles, {
            x        = x + (love.math.random() - 0.5) * (opts.spread or 0),
            y        = y + (love.math.random() - 0.5) * (opts.spread or 0),
            vx       = math.cos(angle) * speed,
            vy       = math.sin(angle) * speed - (opts.up or 40),
            size     = (opts.size or 3) * (0.6 + love.math.random() * 0.8),
            color    = color,
            t        = 0,
            duration = (opts.duration or 0.6) * (0.7 + love.math.random() * 0.6),
            r        = love.math.random() * math.pi,
            vr       = (love.math.random() - 0.5) * 10,
        })
    end
end

function Effects:update(dt)
    for i = #self.texts, 1, -1 do
        local ft = self.texts[i]
        if ft.delay > 0 then
            ft.delay = ft.delay - dt
        else
            ft.t = ft.t + dt
            if ft.t >= ft.duration then
                table.remove(self.texts, i)
            end
        end
    end
    for i = #self.particles, 1, -1 do
        local p = self.particles[i]
        p.t = p.t + dt
        p.vy = p.vy + GRAVITY * dt
        p.vx = p.vx * math.exp(-2 * dt)
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.r = p.r + p.vr * dt
        if p.t >= p.duration then
            table.remove(self.particles, i)
        end
    end
end

function Effects:draw()
    for _, p in ipairs(self.particles) do
        local k = 1 - p.t / p.duration
        local size = p.size * (0.5 + 0.5 * k)
        UI.setColor(p.color, k)
        love.graphics.push()
        love.graphics.translate(p.x, p.y)
        love.graphics.rotate(p.r)
        love.graphics.rectangle("fill", -size / 2, -size / 2, size, size)
        love.graphics.pop()
    end
    for _, ft in ipairs(self.texts) do
        if ft.delay <= 0 then
            local progress = ft.t / ft.duration
            local pop = ft.t < 0.18 and Anim.easeOutBack(ft.t / 0.18) or 1
            local alpha = progress > 0.6 and (1 - (progress - 0.6) / 0.4) or 1
            local y = ft.y - ft.rise * Anim.easeOutCubic(progress)
            local r = ft.rot * math.max(0, 1 - ft.t / 0.4)
            UI.textCentered(ft.text, ft.x, y, ft.font, ft.color,
                { scale = pop, r = r, alpha = alpha, shadowDepth = 2, outline = true })
        end
    end
end

return Effects
