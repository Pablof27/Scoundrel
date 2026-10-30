--[[
    PauseView
    In-game menu overlay (ESC / MENU button). The game keeps its state underneath.
]]

local Button = require("src.View.buttonView")
local Anim   = require("src.View.anim")
local UI     = require("src.View.ui")

local PauseView = {}
PauseView.__index = PauseView

local PANEL_W = 200
local BUTTON_H, BUTTON_GAP = 28, 8

-- game: descriptor of the game being played (its `restartLabel` names the restart button).
function PauseView:new(context, game)
    local o = setmetatable({}, self)
    o.assets        = context.assets
    o.eventBus      = context.eventBus
    o.mouseProvider = context.mouseProvider
    o.appear        = 0
    o.buttons       = {}

    local specs = {
        { text = "RESUME",      color = "blue",   target = "back" },
        { text = game.restartLabel or "RESTART", color = "orange", target = "newGame" },
        { text = "HOW TO PLAY", color = "purple", target = "rules" },
        { text = "SETTINGS",    color = "green",  target = "settings" },
        { text = "MAIN MENU",   color = "red",    target = "menu" },
    }
    local panelH = 52 + #specs * (BUTTON_H + BUTTON_GAP) + 6
    o.panel = {
        x = math.floor((o.assets.WIDTH - PANEL_W) / 2),
        y = math.floor((o.assets.HEIGHT - panelH) / 2),
        w = PANEL_W,
        h = panelH,
    }
    for i, spec in ipairs(specs) do
        local button = Button:new({
            x = o.panel.x + 16, y = 0, width = PANEL_W - 32, height = BUTTON_H,
            text = spec.text, color = UI.colors[spec.color],
            onClick = function() o.eventBus:publish("navigate", spec.target) end,
        }, o.assets, o.mouseProvider)
        button.baseY = o.panel.y + 48 + (i - 1) * (BUTTON_H + BUTTON_GAP)
        table.insert(o.buttons, button)
    end
    return o
end

function PauseView:offset()
    return (1 - Anim.easeOutBack(self.appear)) * 40
end

function PauseView:update(dt, hasFocus)
    self.appear = Anim.moveTowards(self.appear, 1, dt * 5)
    for _, button in ipairs(self.buttons) do
        button.pos.y = button.baseY + self:offset()
        button:update(dt, hasFocus)
    end
end

function PauseView:render()
    local p = self.panel
    local offset = self:offset()
    UI.dim(self.assets, 0.55 * self.appear)
    UI.panel(p.x, p.y + offset, p.w, p.h)
    UI.textCentered("PAUSED", p.x + p.w / 2, p.y + offset + 24, self.assets.fonts.big, UI.colors.text, { shadowDepth = 2 })
    for _, button in ipairs(self.buttons) do
        button:render()
    end
end

function PauseView:onMouseClick(mouseX, mouseY, button)
    for _, b in ipairs(self.buttons) do
        if b:onMouseClick(mouseX, mouseY) then
            return
        end
    end
end

function PauseView:onKeyPressed(key)
    if key == "escape" then
        self.eventBus:publish("navigate", "back")
    end
end

return PauseView
