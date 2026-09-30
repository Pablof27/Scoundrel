--[[
    CardView
    A single animated card sprite, Balatro style:
    - the visual transform (VT) springs towards a target transform (T) and leans with its velocity
    - "juice" pops, idle sway and a fake 3D tilt (towards the mouse when hovered) via the card shader
    - face up/down flips, dissolve/burn when destroyed, white flash when hit, drop shadow
    Positions are card centers. The owner decides targets, hover state and draw order.
]]

local Anim = require("src.View.anim")

local CardView = {}
CardView.__index = CardView

CardView.BURN = {
    fire = { { 1, 0.66, 0.24, 1 }, { 0.86, 0.2, 0.12, 1 } },
    heal = { { 0.6, 1, 0.66, 1 }, { 0.18, 0.72, 0.45, 1 } },
    ash  = { { 0.92, 0.9, 0.84, 1 }, { 0.45, 0.47, 0.47, 1 } },
}

local POSITION_STIFFNESS, POSITION_DAMPING = 200, 22
local ROTATION_STIFFNESS, ROTATION_DAMPING = 300, 16
local SCALE_STIFFNESS, SCALE_DAMPING = 400, 20
local HOVER_SCALE = 0.07
local LEAN_PER_SPEED, MAX_LEAN = 0.00025, 0.3
local FLIP_SPEED = 6

function CardView:new(card, assets, x, y, opts)
    opts = opts or {}
    local o = setmetatable({}, self)
    local size = assets:getCardSize()

    o.card     = card
    o.assets   = assets
    o.width    = size.width
    o.height   = size.height
    o.T        = { x = x, y = y, r = opts.r or 0, s = opts.s or 1 }
    o.VT       = { x = x, y = y, r = opts.r or 0, s = opts.s or 1 }
    o.vel      = { x = 0, y = 0, r = 0, s = 0 }
    o.faceUp   = opts.faceUp ~= false
    o.flip     = o.faceUp and 1 or -1
    o.hovered  = false
    o.idle     = opts.idle ~= false
    o.delay    = 0
    o.juice    = nil
    o.dissolve = 0
    o.dissolveTarget = 0
    o.dissolveSpeed  = 1.5
    o.burn     = CardView.BURN.fire
    o.flash    = 0
    o.alpha    = 1
    o.tint     = 1
    o.tilt     = { x = 0, y = 0 }
    o.phase    = love.math.random() * 100
    o.time     = 0

    return o
end

function CardView:setTarget(x, y, r, s)
    self.T.x, self.T.y = x, y
    self.T.r = r or 0
    self.T.s = s or 1
end

function CardView:snapTo(x, y, r, s)
    self:setTarget(x, y, r, s)
    self.VT.x, self.VT.y, self.VT.r, self.VT.s = self.T.x, self.T.y, self.T.r, self.T.s
    self.vel.x, self.vel.y, self.vel.r, self.vel.s = 0, 0, 0, 0
end

-- Quick squash-and-wobble, like Balatro's juice_up.
function CardView:juiceUp(amount, rot)
    amount = amount or 0.25
    self.juice = Anim.newJuice(amount, rot)
    self.VT.s = self.VT.s - 0.4 * amount
end

function CardView:flashWhite(amount)
    self.flash = amount or 0.8
end

function CardView:burnAway(kind, speed)
    self.burn = CardView.BURN[kind] or CardView.BURN.fire
    self.dissolveTarget = 1
    self.dissolveSpeed = speed or 1.4
end

function CardView:restore()
    self.dissolveTarget = 0
    self.dissolveSpeed = 2.5
end

function CardView:isBurnt()
    return self.dissolve >= 1
end

function CardView:distanceToTarget()
    local dx, dy = self.T.x - self.VT.x, self.T.y - self.VT.y
    return math.sqrt(dx * dx + dy * dy)
end

-- Hit test against the resting (target) rectangle so hover animations don't cause flicker.
function CardView:contains(x, y)
    local halfW, halfH = self.width / 2 * self.T.s, self.height / 2 * self.T.s
    return math.abs(x - self.T.x) <= halfW and math.abs(y - self.T.y) <= halfH
end

function CardView:update(dt, mouseX, mouseY)
    self.time = self.time + dt
    self.juice = Anim.updateJuice(self.juice, dt)
    self.flash = math.max(0, self.flash - dt * 3)
    self.dissolve = Anim.moveTowards(self.dissolve, self.dissolveTarget, dt * self.dissolveSpeed)

    if self.delay > 0 then
        self.delay = self.delay - dt
        return
    end

    local wasFaceUp = self.flip > 0
    self.flip = Anim.moveTowards(self.flip, self.faceUp and 1 or -1, dt * FLIP_SPEED)
    if self.flip > 0 and not wasFaceUp then
        self:juiceUp(0.12, 0.04)
    end

    local T, VT, vel = self.T, self.VT, self.vel
    VT.x, vel.x = Anim.spring(VT.x, vel.x, T.x, POSITION_STIFFNESS, POSITION_DAMPING, dt)
    VT.y, vel.y = Anim.spring(VT.y, vel.y, T.y, POSITION_STIFFNESS, POSITION_DAMPING, dt)
    local targetR = T.r + Anim.clamp(vel.x * LEAN_PER_SPEED, -MAX_LEAN, MAX_LEAN)
    VT.r, vel.r = Anim.spring(VT.r, vel.r, targetR, ROTATION_STIFFNESS, ROTATION_DAMPING, dt)
    local targetS = T.s + (self.hovered and HOVER_SCALE or 0)
    VT.s, vel.s = Anim.spring(VT.s, vel.s, targetS, SCALE_STIFFNESS, SCALE_DAMPING, dt)

    local tiltX, tiltY = 0, 0
    if self.hovered and mouseX then
        tiltX = Anim.clamp((mouseX - VT.x) / (self.width / 2), -1, 1)
        tiltY = Anim.clamp((mouseY - VT.y) / (self.height / 2), -1, 1)
    elseif self.idle then
        tiltX = math.cos(self.time * 0.9 + self.phase) * 0.35
        tiltY = math.sin(self.time * 0.7 + self.phase * 1.3) * 0.35
    end
    self.tilt.x = Anim.approach(self.tilt.x, tiltX, 10, dt)
    self.tilt.y = Anim.approach(self.tilt.y, tiltY, 10, dt)
end

function CardView:draw()
    if self.alpha <= 0 or self.dissolve >= 1 then
        return
    end

    local assets = self.assets
    local shader = assets.shaders.card
    local idle = self.idle and 1 or 0
    local x = self.VT.x
    local y = self.VT.y + idle * math.sin(self.time * 1.6 + self.phase)
    local r = self.VT.r + (self.juice and self.juice.r or 0) + idle * 0.012 * math.sin(self.time * 1.1 + self.phase * 1.3)
    local s = self.VT.s + (self.juice and self.juice.scale or 0)
    local sx = s * math.max(0.03, math.abs(self.flip))
    local position = (self.flip > 0 and self.card) and self.card.position or nil
    local quad = assets:cardQuad(position)
    local col, row = assets:cardCell(position)
    local w, h = self.width, self.height

    love.graphics.setShader(shader)
    shader:send("texture_details", { col, row, w, h })
    shader:send("card_half", { w / 2 * s, h / 2 * s })
    shader:send("tilt", { self.tilt.x, self.tilt.y })
    shader:send("dissolve", self.dissolve)
    shader:send("burn_colour_1", self.burn[1])
    shader:send("burn_colour_2", self.burn[2])

    -- Drop shadow: slight parallax away from the screen center, further away when lifted.
    local lift = math.max(0, s - 1) * 30
    local shadowX = x + (x - assets.WIDTH / 2) / (assets.WIDTH / 2) * 3
    local shadowY = y + 4 + lift
    shader:send("card_center", { love.graphics.transformPoint(shadowX, shadowY) })
    shader:send("shadow", 1)
    shader:send("flash", 0)
    love.graphics.setColor(1, 1, 1, self.alpha)
    love.graphics.draw(assets.textures.cards, quad, shadowX, shadowY, r, sx, s, w / 2, h / 2)

    shader:send("card_center", { love.graphics.transformPoint(x, y) })
    shader:send("shadow", 0)
    shader:send("flash", self.flash)
    love.graphics.setColor(self.tint, self.tint, self.tint, self.alpha)
    love.graphics.draw(assets.textures.cards, quad, x, y, r, sx, s, w / 2, h / 2)

    love.graphics.setShader()
end

return CardView