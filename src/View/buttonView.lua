--[[
    ButtonView
    Chunky raised button with hover "juice", press feedback and an optional hotkey badge.
    Receives assets via constructor — no globals.
]]

local Anim = require("src.View.anim")
local UI   = require("src.View.ui")

local Button = {}
Button.__index = Button

local EDGE = 3

function Button:new(params, assets, mouseProvider)
    local o = setmetatable({}, self)

    o.pos       = { x = params.x, y = params.y }
    o.size      = { width = params.width, height = params.height }
    o.text      = params.text or ""
    o.color     = params.color or UI.colors.blue
    o.font      = params.font or assets.fonts.medium
    o.hotkey    = params.hotkey
    o.onClick   = params.onClick or function() end
    o.hoovered  = false
    o.visible   = params.visible ~= false
    o.disabled  = params.disabled or false
    o.assets    = assets
    o.mouseProvider = mouseProvider  -- function that returns mouseX, mouseY
    o.press     = 0
    o.juice     = nil

    return o
end

function Button:render()
    if not self.visible then
        return
    end

    local x, y, w, h = self.pos.x, self.pos.y, self.size.width, self.size.height
    local color = self.disabled and UI.colors.grey or self.color
    if self.hoovered and not self.disabled then
        color = UI.mix(color, UI.colors.white, 0.18)
    end

    local lift = 0
    if self.disabled then
        lift = 2
    elseif self.press > 0 then
        lift = 2 * self.press
    elseif self.hoovered then
        lift = -1
    end

    local cx, cy = x + w / 2, y + h / 2
    local juiceScale = self.juice and self.juice.scale or 0
    local juiceRot = self.juice and self.juice.r or 0
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.rotate(juiceRot)
    love.graphics.scale(1 + juiceScale, 1 + juiceScale)
    love.graphics.translate(-cx, -cy)

    UI.setColor(UI.shade(color, 0.55))
    love.graphics.rectangle("fill", x, y + EDGE, w, h, 5, 5)
    UI.setColor(color)
    love.graphics.rectangle("fill", x, y + lift, w, h, 5, 5)

    UI.textCentered(self.text, cx, cy + lift, self.font, UI.colors.text, { alpha = self.disabled and 0.55 or 1 })

    if self.hotkey then
        local font = self.assets.fonts.tiny
        local badgeW = font:getWidth(self.hotkey) + 6
        UI.box(x + w - badgeW - 2, y + lift + 2, badgeW, 10, UI.colors.panelDark, { radius = 3, alpha = 0.55 })
        UI.text(self.hotkey, x + w - badgeW + 1, y + lift + 3, font, UI.colors.textDim, { shadow = false })
    end

    love.graphics.pop()
end

function Button:isInside(mouseX, mouseY)
    return mouseX >= self.pos.x and mouseX <= self.pos.x + self.size.width and
           mouseY >= self.pos.y and mouseY <= self.pos.y + self.size.height + EDGE
end

-- focused = false disables hovering (e.g. when an overlay covers the button).
function Button:update(dt, focused)
    local mouseX, mouseY = self.mouseProvider()
    local over = focused ~= false and self.visible and self:isInside(mouseX, mouseY)
    if over and not self.hoovered and not self.disabled then
        self.juice = Anim.newJuice(0.06, 0.015, 0.3)
        self.assets.audio:play("hover", { variation = 0.1 })
    end
    self.hoovered = over
    self.press = math.max(0, self.press - dt * 5)
    self.juice = Anim.updateJuice(self.juice, dt)
end

function Button:onMouseClick(mouseX, mouseY)
    if not self.visible or not self:isInside(mouseX, mouseY) then
        return false
    end
    if self.disabled then
        self.juice = Anim.newJuice(0.03, 0.06, 0.25)
        self.assets.audio:play("denied")
        return true
    end
    self.press = 1
    self.juice = Anim.newJuice(0.12, 0.02, 0.35)
    self.assets.audio:play("click")
    self.onClick()
    return true
end

return Button