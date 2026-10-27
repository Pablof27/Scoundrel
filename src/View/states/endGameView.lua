--[[
    EndGameView
    End-of-run overlay drawn on top of the final board: result, score (official Scoundrel
    scoring), personal best and the statistics of the run.
]]

local SidebarView = require("src.View.sidebarView")
local Button      = require("src.View.buttonView")
local Anim        = require("src.View.anim")
local UI          = require("src.View.ui")

local EndGameView = {}
EndGameView.__index = EndGameView

local PANEL_W, PANEL_H = 400, 284
local ROW_H = 15

-- result: { didWin, gameState, runTime }; record: { score, isBest }
function EndGameView:new(context, result, record)
    local o = setmetatable({}, self)
    o.assets        = context.assets
    o.eventBus      = context.eventBus
    o.mouseProvider = context.mouseProvider
    o.didWin        = result.didWin
    o.gameState     = result.gameState
    o.runTime       = result.runTime
    o.score         = record.score
    o.isBest        = record.isBest
    o.time          = 0
    o.appear        = 0
    o.titleJuice    = nil
    o.scoreJuice    = nil

    o.panel = {
        x = math.floor((o.assets.WIDTH - PANEL_W) / 2),
        y = math.floor((o.assets.HEIGHT - PANEL_H) / 2),
        w = PANEL_W,
        h = PANEL_H,
    }
    local buttonW = 150
    local buttonsY = o.panel.y + PANEL_H - 44
    o.buttons = {
        Button:new({
            x = o.panel.x + PANEL_W / 2 - buttonW - 6, y = buttonsY, width = buttonW, height = 30,
            text = "PLAY AGAIN", color = UI.colors.blue,
            onClick = function() o.eventBus:publish("navigate", "newGame") end,
        }, o.assets, o.mouseProvider),
        Button:new({
            x = o.panel.x + PANEL_W / 2 + 6, y = buttonsY, width = buttonW, height = 30,
            text = "MAIN MENU", color = UI.colors.orange,
            onClick = function() o.eventBus:publish("navigate", "menu") end,
        }, o.assets, o.mouseProvider),
    }
    for _, button in ipairs(o.buttons) do
        button.baseY = buttonsY
    end
    return o
end

function EndGameView:offset()
    return (1 - Anim.easeOutBack(self.appear)) * 60
end

function EndGameView:shownScore()
    local t = Anim.clamp((self.time - 0.35) / 0.6, 0, 1)
    return math.floor(self.score * Anim.easeOutCubic(t) + 0.5)
end

function EndGameView:update(dt, hasFocus)
    local before = self.time
    self.time = self.time + dt
    self.appear = Anim.moveTowards(self.appear, 1, dt * 4)
    if before < 0.2 and self.time >= 0.2 then
        self.titleJuice = Anim.newJuice(0.35, 0.08, 0.5)
    end
    if before < 0.95 and self.time >= 0.95 then
        self.scoreJuice = Anim.newJuice(0.4, 0.1, 0.5)
        if self.isBest then
            self.assets.audio:play("heal")
        end
    end
    self.titleJuice = Anim.updateJuice(self.titleJuice, dt)
    self.scoreJuice = Anim.updateJuice(self.scoreJuice, dt)
    for _, button in ipairs(self.buttons) do
        button.pos.y = button.baseY + self:offset()
        button:update(dt, hasFocus)
    end
end

function EndGameView:render()
    local C, fonts = UI.colors, self.assets.fonts
    local p = self.panel
    local offset = self:offset()
    local cx = p.x + p.w / 2
    local y = p.y + offset

    UI.dim(self.assets, 0.6 * self.appear)
    UI.panel(p.x, y, p.w, p.h)

    local title = self.didWin and "YOU ESCAPED!" or "YOU DIED"
    local juice = self.titleJuice
    UI.textCentered(title, cx, y + 28, fonts.large, self.didWin and C.gold or C.red,
        { scale = 1 + (juice and juice.scale or 0), r = juice and juice.r or 0, shadowDepth = 3 })
    local subtitle = self.didWin and "You made it through the whole dungeon." or
        ("The dungeon claimed you in room " .. self.gameState.roomNumber .. ".")
    UI.textCentered(subtitle, cx, y + 54, fonts.small, C.textDim)

    UI.box(p.x + 20, y + 68, p.w - 40, 44, C.panelDark, { radius = 6 })
    UI.text("SCORE", p.x + 30, y + 74, fonts.tiny, C.textDim, { shadow = false })
    local scoreJuice = self.scoreJuice
    UI.textCentered(tostring(self:shownScore()), cx, y + 90, fonts.large, self.score >= 0 and C.text or C.damage,
        { scale = 1 + (scoreJuice and scoreJuice.scale or 0), r = scoreJuice and scoreJuice.r or 0, shadowDepth = 2 })
    if self.isBest and self.time > 0.95 then
        local pulse = 1 + 0.06 * math.sin(self.time * 6)
        UI.box(p.x + p.w - 112, y + 80, 80, 18, C.gold, { radius = 4, depth = 2 })
        UI.textCentered("NEW BEST!", p.x + p.w - 72, y + 89, fonts.small, C.textDark, { scale = pulse, shadow = false })
    end

    local stats = self.gameState.stats
    local rows = {
        { label = "Rooms explored", value = self.gameState.roomNumber },
        { label = "Time", value = UI.formatTime(self.runTime) },
    }
    for _, row in ipairs(SidebarView.STAT_ROWS) do
        table.insert(rows, { label = row.label, value = stats[row.key] })
    end
    local perColumn = math.ceil(#rows / 2)
    local statsY = y + 120
    UI.box(p.x + 20, statsY, p.w - 40, perColumn * ROW_H + 12, C.panelDark, { radius = 6 })
    local columnW = (p.w - 40) / 2
    for i, row in ipairs(rows) do
        local column = math.floor((i - 1) / perColumn)
        local rowX = p.x + 20 + column * columnW
        local rowY = statsY + 7 + ((i - 1) % perColumn) * ROW_H
        UI.text(row.label, rowX + 10, rowY, fonts.small, C.textDim)
        local value = tostring(row.value)
        UI.text(value, rowX + columnW - 10 - fonts.small:getWidth(value), rowY, fonts.small, C.text)
    end

    for _, button in ipairs(self.buttons) do
        button:render()
    end
end

function EndGameView:onMouseClick(mouseX, mouseY, button)
    for _, b in ipairs(self.buttons) do
        if b:onMouseClick(mouseX, mouseY) then
            return
        end
    end
end

function EndGameView:onKeyPressed(key)
    if key == "return" or key == "space" then
        self.eventBus:publish("navigate", "newGame")
    elseif key == "escape" then
        self.eventBus:publish("navigate", "menu")
    end
end

return EndGameView