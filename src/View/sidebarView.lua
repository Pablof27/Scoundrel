--[[
    SidebarView
    Left info panel: health (with a live preview of the hovered action), room info,
    potion availability and the statistics of the current run.
]]

local Anim = require("src.View.anim")
local UI   = require("src.View.ui")

local SidebarView = {}
SidebarView.__index = SidebarView

local MAX_LIFES = Constants.MAX_LIFES

SidebarView.STAT_ROWS = {
    { key = "cardsPlayed",     label = "Cards played" },
    { key = "monstersSlain",   label = "Monsters slain" },
    { key = "bossesSlain",     label = "Bosses slain (J-A)" },
    { key = "damageTaken",     label = "Damage taken" },
    { key = "damageBlocked",   label = "Damage blocked" },
    { key = "potionsDrunk",    label = "Potions drunk" },
    { key = "healed",          label = "Health restored" },
    { key = "weaponsEquipped", label = "Weapons equipped" },
    { key = "roomsFled",       label = "Rooms fled" },
}

local ROW_HEIGHT = 15

function SidebarView:new(assets, x, y, width, height, life)
    local o = setmetatable({}, self)
    o.assets      = assets
    o.x, o.y      = x, y
    o.w, o.h      = width, height
    o.life        = life
    o.displayLife = life
    o.lifeJuice   = nil
    o.flash       = 0
    o.flashColor  = UI.colors.damage
    o.preview     = nil  -- health after the hovered action, if any
    o.time        = 0
    o.statValues  = {}
    o.statJuice   = {}
    return o
end

function SidebarView:setLife(life)
    if life == self.life then
        return
    end
    self.flashColor = life < self.life and UI.colors.damage or UI.colors.heal
    self.flash = 1
    self.life = life
end

-- Center of the heart icon: potions fly here, health numbers pop from here.
function SidebarView:healthAnchor()
    return self.x + 27, self.y + 64
end

-- Top of the area reserved for the buttons at the bottom of the panel.
function SidebarView:buttonsY()
    return self.y + self.h - 36
end

function SidebarView:update(dt, gameState)
    self.time = self.time + dt

    local shownBefore = math.floor(self.displayLife + 0.5)
    self.displayLife = Anim.moveTowards(self.displayLife, self.life, dt * 24)
    if math.floor(self.displayLife + 0.5) ~= shownBefore then
        self.lifeJuice = Anim.newJuice(0.2, 0.06, 0.3)
    end
    self.lifeJuice = Anim.updateJuice(self.lifeJuice, dt)
    self.flash = math.max(0, self.flash - dt * 2)

    for _, row in ipairs(self.STAT_ROWS) do
        local value = gameState.stats[row.key]
        local previous = self.statValues[row.key]
        if previous ~= nil and previous ~= value then
            self.statJuice[row.key] = Anim.newJuice(0.3, 0.08, 0.35)
        end
        self.statValues[row.key] = value
        self.statJuice[row.key] = Anim.updateJuice(self.statJuice[row.key], dt)
    end
end

function SidebarView:render(gameState, runTime)
    local C = UI.colors
    local fonts = self.assets.fonts
    local x, y, w = self.x, self.y, self.w
    local bx, bw = x + 6, w - 12

    UI.box(x, y, w, self.h, C.panel, { radius = 8, depth = 3 })
    self:renderTitle(x + w / 2, y + 17)

    local healthY = y + 34
    self:renderHealth(bx, healthY, bw, 64)

    local roomY = healthY + 70
    UI.box(bx, roomY, bw, 38, C.panelDark, { radius = 6 })
    local columns = {
        { label = "ROOM",    value = tostring(gameState.roomNumber) },
        { label = "DUNGEON", value = tostring(#gameState.drawPile.cards) },
        { label = "TIME",    value = UI.formatTime(runTime) },
    }
    local columnW = bw / #columns
    for i, column in ipairs(columns) do
        local cx = bx + columnW * (i - 0.5)
        UI.textCentered(column.label, cx, roomY + 9, fonts.tiny, C.textDim, { shadow = false })
        UI.textCentered(column.value, cx, roomY + 25, fonts.medium, C.text)
    end

    local potionY = roomY + 44
    local used = gameState.potionUsedThisRoom
    UI.box(bx, potionY, bw, 16, used and C.panelInner or UI.shade(C.red, 0.7), { radius = 4 })
    UI.icon(self.assets, "heart", bx + 4, potionY + 2, 12, used and 0.35 or 1)
    UI.text(used and "Potion already used this room" or "Potion available this room",
        bx + 20, potionY + 4, fonts.tiny, used and C.textDim or C.text, { shadow = not used })

    local statsY = potionY + 22
    local statsH = 20 + #self.STAT_ROWS * ROW_HEIGHT
    UI.box(bx, statsY, bw, statsH, C.panelDark, { radius = 6 })
    UI.text("RUN STATS", bx + 7, statsY + 5, fonts.tiny, C.textDim, { shadow = false })
    for i, row in ipairs(self.STAT_ROWS) do
        local rowY = statsY + 17 + (i - 1) * ROW_HEIGHT
        UI.text(row.label, bx + 7, rowY, fonts.small, C.textDim)
        local juice = self.statJuice[row.key]
        local value = tostring(gameState.stats[row.key])
        local valueX = bx + bw - 8 - fonts.small:getWidth(value) / 2
        UI.textCentered(value, valueX, rowY + 6, fonts.small, juice and C.gold or C.text,
            { scale = 1 + (juice and juice.scale or 0), r = juice and juice.r or 0 })
    end
end

function SidebarView:renderTitle(cx, cy)
    local font = self.assets.fonts.big
    local title = "SCOUNDREL"
    local x = cx - font:getWidth(title) / 2
    for i = 1, #title do
        local letter = title:sub(i, i)
        local letterW = font:getWidth(letter)
        local wobble = math.sin(self.time * 2.2 + i * 0.6) * 1.2
        UI.textCentered(letter, x + letterW / 2, cy + wobble, font, UI.colors.text, { shadowDepth = 2 })
        x = x + letterW
    end
end

function SidebarView:renderHealth(x, y, w, h)
    local C = UI.colors
    local fonts = self.assets.fonts
    UI.box(x, y, w, h, C.panelDark, { radius = 6 })
    UI.text("HEALTH", x + 7, y + 5, fonts.tiny, C.textDim, { shadow = false })

    local hx, hy = self:healthAnchor()
    local pulse = self.life <= 5 and (1 + 0.1 * math.sin(self.time * 8)) or 1
    local heartSize = 28 * pulse
    UI.icon(self.assets, "heart", hx - heartSize / 2, hy - heartSize / 2, heartSize)

    local shown = math.floor(self.displayLife + 0.5)
    local juice = self.lifeJuice
    local color = UI.mix(C.text, self.flashColor, self.flash)
    UI.textCentered(tostring(shown), x + 66, y + 30, fonts.large, color,
        { scale = 1 + (juice and juice.scale or 0), r = juice and juice.r or 0, shadowDepth = 2 })
    UI.text("/" .. MAX_LIFES, x + 86, y + 29, fonts.small, C.textDim)

    local preview = self.preview
    local blink = 0.55 + 0.45 * math.sin(self.time * 10)
    if preview and preview ~= self.life then
        local delta = preview - self.life
        local label = preview <= 0 and "DEAD" or ((delta > 0 and "+" or "") .. delta)
        local labelColor = delta > 0 and C.heal or C.damage
        UI.text(label, x + w - 8 - fonts.medium:getWidth(label), y + 22, fonts.medium, labelColor, { alpha = blink })
    end

    local barX, barY, barW, barH = x + 7, y + h - 14, w - 14, 8
    UI.box(barX, barY, barW, barH, { 0, 0, 0, 1 }, { radius = 3, alpha = 0.45 })
    local fill = Anim.clamp(self.displayLife / MAX_LIFES, 0, 1)
    local barColor = self.life > 10 and C.green or (self.life > 5 and C.orange or C.red)
    if fill > 0 then
        UI.box(barX, barY, math.max(6, barW * fill), barH, barColor, { radius = 3 })
    end
    if preview and preview ~= self.life then
        local from = Anim.clamp(math.min(preview, self.life) / MAX_LIFES, 0, 1)
        local to = Anim.clamp(math.max(preview, self.life) / MAX_LIFES, 0, 1)
        if to > from then
            local ghost = preview < self.life and C.white or C.heal
            UI.box(barX + barW * from, barY, barW * (to - from), barH, ghost, { radius = 2, alpha = 0.35 + 0.5 * blink })
        end
    end
end

return SidebarView
