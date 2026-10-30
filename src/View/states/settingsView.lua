--[[
    SettingsView
    Overlay listing every user preference. Click a value (or use the arrow keys) to change it.
    Values are applied and saved immediately through Settings. Options with `details` (difficulty)
    explain their current value in a note next to the panel.
]]

local Settings = require("src.Core.settings")
local Button   = require("src.View.buttonView")
local Anim     = require("src.View.anim")
local UI       = require("src.View.ui")

local SettingsView = {}
SettingsView.__index = SettingsView

local PANEL_W = 340
local ROW_H = 28
local VALUE_W = 128
local DETAILS_W, DETAILS_GAP = 148, 8

function SettingsView:new(context)
    local o = setmetatable({}, self)
    o.assets        = context.assets
    o.eventBus      = context.eventBus
    o.settings      = context.settings
    o.mouseProvider = context.mouseProvider
    o.appear        = 0
    o.selected      = 1
    o.hoveredRow    = nil
    o.juice         = {}

    local panelH = 50 + #Settings.OPTIONS * ROW_H + 52
    o.panel = {
        x = math.floor((o.assets.WIDTH - PANEL_W) / 2),
        y = math.floor((o.assets.HEIGHT - panelH) / 2),
        w = PANEL_W,
        h = panelH,
    }
    o.backButton = Button:new({
        x = o.panel.x + (PANEL_W - 120) / 2, y = 0, width = 120, height = 28,
        text = "BACK", color = UI.colors.orange,
        onClick = function() o.eventBus:publish("navigate", "back") end,
    }, o.assets, o.mouseProvider)
    o.backButton.baseY = o.panel.y + panelH - 42
    return o
end

function SettingsView:offset()
    return (1 - Anim.easeOutBack(self.appear)) * 40
end

function SettingsView:rowRect(index)
    local p = self.panel
    return p.x + 14, p.y + 46 + (index - 1) * ROW_H + self:offset(), p.w - 28, ROW_H - 4
end

function SettingsView:valueRect(index)
    local x, y, w, h = self:rowRect(index)
    return x + w - VALUE_W - 4, y + 2, VALUE_W, h - 4
end

function SettingsView:change(index, dir)
    local key = Settings.OPTIONS[index].key
    self.settings:cycle(key, dir)
    self.juice[index] = Anim.newJuice(0.15, 0.03, 0.3)
    self.assets.audio:play("toggle")
end

function SettingsView:update(dt, hasFocus)
    self.appear = Anim.moveTowards(self.appear, 1, dt * 5)
    local mouseX, mouseY = self.mouseProvider()
    self.hoveredRow = nil
    if hasFocus then
        for i = 1, #Settings.OPTIONS do
            local x, y, w, h = self:rowRect(i)
            if mouseX >= x and mouseX <= x + w and mouseY >= y and mouseY <= y + h then
                self.hoveredRow = i
                self.selected = i
            end
        end
    end
    for i = 1, #Settings.OPTIONS do
        self.juice[i] = Anim.updateJuice(self.juice[i], dt)
    end
    self.backButton.pos.y = self.backButton.baseY + self:offset()
    self.backButton:update(dt, hasFocus)
end

function SettingsView:render()
    local C, fonts = UI.colors, self.assets.fonts
    local p = self.panel
    local offset = self:offset()
    UI.dim(self.assets, 0.55 * self.appear)
    UI.panel(p.x, p.y + offset, p.w, p.h)
    UI.textCentered("SETTINGS", p.x + p.w / 2, p.y + offset + 22, fonts.big, C.text, { shadowDepth = 2 })

    for i, option in ipairs(Settings.OPTIONS) do
        local x, y, w, h = self:rowRect(i)
        local selected = self.selected == i
        UI.box(x, y, w, h, selected and C.panelLight or C.panelDark, { radius = 5, alpha = selected and 0.9 or 0.6 })
        UI.text(option.label, x + 10, y + (h - fonts.medium:getHeight()) / 2, fonts.medium, C.text)

        local vx, vy, vw, vh = self:valueRect(i)
        UI.box(vx, vy, vw, vh, C.blue, { radius = 4, depth = 2 })
        local juice = self.juice[i]
        UI.textCentered(self.settings:displayValue(option.key), vx + vw / 2, vy + vh / 2, fonts.medium, C.text,
            { scale = 1 + (juice and juice.scale or 0), r = juice and juice.r or 0 })
        UI.textCentered("<", vx + 9, vy + vh / 2, fonts.medium, C.text, { alpha = 0.8 })
        UI.textCentered(">", vx + vw - 9, vy + vh / 2, fonts.medium, C.text, { alpha = 0.8 })
    end

    self:renderDetails()
    self.backButton:render()
end

-- Side note next to the selected row explaining its current value (options with `details` only).
function SettingsView:renderDetails()
    local option = Settings.OPTIONS[self.selected]
    local details = self.settings:details(option.key)
    if not details then
        return
    end
    local C, fonts = UI.colors, self.assets.fonts
    local font = fonts.small
    local textW = DETAILS_W - 16
    local lineH = font:getHeight()
    local _, lines = font:getWrap(details, textW)
    local noteLines = {}
    if option.note then
        _, noteLines = font:getWrap(option.note, textW)
    end

    local _, rowY, _, rowH = self:rowRect(self.selected)
    local x, y = self.panel.x + self.panel.w + DETAILS_GAP, rowY - 4
    local h = 30 + #lines * lineH + (#noteLines > 0 and (6 + #noteLines * lineH) or 0)
    local alpha = self.appear
    UI.box(x, y, DETAILS_W, h, C.panelDark, { radius = 6, depth = 3, outline = C.panelLight, alpha = alpha })
    -- Pointer towards the row.
    local tipY = rowY + rowH / 2
    UI.setColor(C.panelLight, alpha)
    love.graphics.polygon("fill", x + 0.5, tipY - 6, x - DETAILS_GAP + 2, tipY, x + 0.5, tipY + 6)

    UI.text(self.settings:displayValue(option.key):upper(), x + 8, y + 8, fonts.medium, C.gold, { alpha = alpha })
    UI.text(details, x + 8, y + 26, font, C.text, { width = textW, alpha = alpha })
    if option.note then
        UI.text(option.note, x + 8, y + 32 + #lines * lineH, font, C.textDim, { width = textW, alpha = alpha })
    end
end

function SettingsView:onMouseClick(mouseX, mouseY, button)
    if self.backButton:onMouseClick(mouseX, mouseY) then
        return
    end
    for i = 1, #Settings.OPTIONS do
        local x, y, w, h = self:valueRect(i)
        if mouseX >= x and mouseX <= x + w and mouseY >= y and mouseY <= y + h then
            local dir = (mouseX < x + w / 3 or button == 2) and -1 or 1
            self:change(i, dir)
            return
        end
    end
end

function SettingsView:onKeyPressed(key)
    if key == "escape" or key == "return" then
        self.eventBus:publish("navigate", "back")
    elseif key == "up" then
        self.selected = (self.selected - 2) % #Settings.OPTIONS + 1
        self.assets.audio:play("hover")
    elseif key == "down" then
        self.selected = self.selected % #Settings.OPTIONS + 1
        self.assets.audio:play("hover")
    elseif key == "left" then
        self:change(self.selected, -1)
    elseif key == "right" then
        self:change(self.selected, 1)
    end
end

return SettingsView
