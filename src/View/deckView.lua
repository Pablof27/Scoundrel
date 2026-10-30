--[[
    DeckView
    Renders a draw pile as a stack of card backs with a remaining-cards badge.
    Cards are dealt from, and returned to, topPosition(). Purely visual: no game actions.
]]

local Anim = require("src.View.anim")
local UI   = require("src.View.ui")

local DeckView = {}
DeckView.__index = DeckView

local MAX_LAYERS = 8
local LAYER_DX, LAYER_DY = -0.5, -1.5

function DeckView:new(assets, x, y)
    local o = setmetatable({}, self)
    o.assets    = assets
    o.x, o.y    = x, y  -- center of the bottom card
    o.size      = assets:getCardSize()
    o.count     = 0
    o.juice     = nil
    o.hoovered  = false
    o.showBadge = true  -- remaining-cards badge on the top card
    return o
end

function DeckView:setCount(count)
    if count ~= self.count then
        self.juice = Anim.newJuice(0.05, 0.01, 0.3)
    end
    self.count = count
end

function DeckView:layers()
    return math.min(MAX_LAYERS, math.ceil(self.count / 4))
end

function DeckView:topPosition()
    local n = math.max(0, self:layers() - 1)
    return self.x + n * LAYER_DX, self.y + n * LAYER_DY
end

function DeckView:isInside(mouseX, mouseY)
    return math.abs(mouseX - self.x) <= self.size.width / 2 and
           math.abs(mouseY - self.y) <= self.size.height / 2
end

function DeckView:update(dt, mouseX, mouseY)
    self.juice = Anim.updateJuice(self.juice, dt)
    self.hoovered = mouseX ~= nil and self:isInside(mouseX, mouseY)
end

function DeckView:render()
    local assets = self.assets
    local w, h = self.size.width, self.size.height
    local layers = self:layers()

    if layers == 0 then
        UI.box(self.x - w / 2, self.y - h / 2, w, h, UI.colors.panelDark, { radius = 6, alpha = 0.3 })
        UI.textCentered("EMPTY", self.x, self.y, assets.fonts.small, UI.colors.textDim, { alpha = 0.7 })
        return
    end

    local s = 1 + (self.juice and self.juice.scale or 0)
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.rectangle("fill", self.x - w / 2 + 3, self.y - h / 2 + 4, w, h, 6, 6)
    for i = 0, layers - 1 do
        local shade = (i == layers - 1) and 1 or (0.7 + 0.03 * i)
        love.graphics.setColor(shade, shade, shade, 1)
        love.graphics.draw(assets.textures.cards, assets:cardQuad(nil),
            self.x + i * LAYER_DX, self.y + i * LAYER_DY, 0, s, s, w / 2, h / 2)
    end

    if not self.showBadge then
        return
    end
    local topX, topY = self:topPosition()
    local label = tostring(self.count)
    local badgeW = math.max(22, assets.fonts.small:getWidth(label) + 10)
    UI.box(topX - badgeW / 2, topY + h / 2 - 20, badgeW, 15, UI.colors.panelDark, { radius = 4, depth = 2, alpha = 0.9 })
    UI.textCentered(label, topX, topY + h / 2 - 12.5, assets.fonts.small, UI.colors.text)
end

return DeckView