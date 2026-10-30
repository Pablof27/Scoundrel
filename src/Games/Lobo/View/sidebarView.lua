--[[
    Lobo SidebarView
    Left info panel: the match (your score against the Wolf's, racing to the target), hand number,
    deck size and time, how many cards of each value the deck still hides, and the ledger of
    finished hands. Scores and ledger change when the board reveals a hand's result (setScores).
]]

local Anim = require("src.View.anim")
local UI   = require("src.View.ui")

local SidebarView = {}
SidebarView.__index = SidebarView

local ROW_HEIGHT = 15
local SIDES = { "player", "wolf" }

local REASON_LABELS = { captured = "ALL TAKEN", fold = "FOLDED", stuck = "NO MOVES" }

function SidebarView:new(assets, x, y, width, height)
    local o = setmetatable({}, self)
    o.assets      = assets
    o.x, o.y      = x, y
    o.w, o.h      = width, height
    o.scores      = { player = 0, wolf = 0 }
    o.shown       = { player = 0, wolf = 0 }  -- counts up towards the scores
    o.juice       = {}
    o.ledgerCount = 0
    o.ledgerJuice = nil
    o.time        = 0
    local bx, bw = x + 6, width - 12
    o.matchRect   = { x = bx, y = y + 34, w = bw, h = 62 }
    o.infoRect    = { x = bx, y = y + 102, w = bw, h = 38 }
    o.trackerRect = { x = bx, y = y + 146, w = bw, h = 52 }
    o.ledgerRect  = { x = bx, y = y + 204, w = bw, h = y + height - 36 - 6 - (y + 204) }
    return o
end

-- Shows these scores and the first `ledgerCount` hands of the ledger.
function SidebarView:setScores(scores, ledgerCount)
    for _, side in ipairs(SIDES) do
        if scores[side] ~= self.scores[side] then
            self.juice[side] = Anim.newJuice(0.35, 0.08, 0.45)
        end
        self.scores[side] = scores[side]
    end
    if ledgerCount > self.ledgerCount then
        self.ledgerJuice = Anim.newJuice(0.25, 0.05, 0.4)
    end
    self.ledgerCount = ledgerCount
end

-- Top of the area reserved for the buttons at the bottom of the panel.
function SidebarView:buttonsY()
    return self.y + self.h - 36
end

local function inside(rect, x, y)
    return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
end

-- Name of the box under the mouse ("match", "tracker" or "ledger"), for the board's hints.
function SidebarView:boxAt(x, y)
    if inside(self.matchRect, x, y) then
        return "match"
    elseif inside(self.trackerRect, x, y) then
        return "tracker"
    elseif inside(self.ledgerRect, x, y) then
        return "ledger"
    end
    return nil
end

function SidebarView:update(dt)
    self.time = self.time + dt
    for _, side in ipairs(SIDES) do
        self.shown[side] = Anim.moveTowards(self.shown[side], self.scores[side], dt * 30)
        self.juice[side] = Anim.updateJuice(self.juice[side], dt)
    end
    self.ledgerJuice = Anim.updateJuice(self.ledgerJuice, dt)
end

function SidebarView:render(state, runTime)
    local C, fonts = UI.colors, self.assets.fonts
    local x, y, w = self.x, self.y, self.w

    UI.box(x, y, w, self.h, C.panel, { radius = 8, depth = 3 })
    UI.wavyText("LOBO", x + w / 2, y + 17, fonts.big, self.time,
        { amplitude = 1.2, speed = 2.2, spacing = 0.6, shadowDepth = 2 })

    local m = self.matchRect
    UI.box(m.x, m.y, m.w, m.h, C.panelDark, { radius = 6 })
    UI.text("MATCH TO " .. state.target, m.x + 7, m.y + 5, fonts.tiny, C.textDim, { shadow = false })
    self:renderScore("YOU", "player", C.gold, state.target, m.y + 19)
    self:renderScore("WOLF", "wolf", C.red, state.target, m.y + 40)

    local info = self.infoRect
    UI.box(info.x, info.y, info.w, info.h, C.panelDark, { radius = 6 })
    local columns = {
        { label = "HAND", value = tostring(state.handNumber) },
        { label = "DECK", value = tostring(#state.deck.cards) },
        { label = "TIME", value = UI.formatTime(runTime) },
    }
    local columnW = info.w / #columns
    for i, column in ipairs(columns) do
        local cx = info.x + columnW * (i - 0.5)
        UI.textCentered(column.label, cx, info.y + 9, fonts.tiny, C.textDim, { shadow = false })
        UI.textCentered(column.value, cx, info.y + 25, fonts.medium, C.text)
    end

    self:renderTracker(state)
    self:renderLedger(state)
end

function SidebarView:renderScore(label, side, color, target, y)
    local C, fonts = UI.colors, self.assets.fonts
    local m = self.matchRect
    UI.text(label, m.x + 7, y, fonts.small, color)
    local juice = self.juice[side]
    UI.textCentered(tostring(math.floor(self.shown[side] + 0.5)), m.x + 54, y + 6, fonts.medium, C.text,
        { scale = 1 + (juice and juice.scale or 0), r = juice and juice.r or 0 })
    local barX, barW = m.x + 72, m.w - 80
    UI.box(barX, y + 2, barW, 8, { 0, 0, 0, 1 }, { radius = 3, alpha = 0.45 })
    local fill = Anim.clamp(self.shown[side] / target, 0, 1)
    if fill > 0 then
        UI.box(barX, y + 2, math.max(6, barW * fill), 8, color, { radius = 3 })
    end
end

-- Cards of each value still hidden in the deck, below the cub.
function SidebarView:renderTracker(state)
    local C, fonts = UI.colors, self.assets.fonts
    local t = self.trackerRect
    UI.box(t.x, t.y, t.w, t.h, C.panelDark, { radius = 6 })
    UI.text("HIDDEN IN THE DECK", t.x + 7, t.y + 5, fonts.tiny, C.textDim, { shadow = false })
    local shuffle = state:handsBeforeShuffle()
    local note = shuffle == 0 and "SHUFFLE NEXT" or ("SHUFFLE IN " .. shuffle)
    UI.text(note, t.x + t.w - 6 - fonts.tiny:getWidth(note), t.y + 5, fonts.tiny, C.blue, { shadow = false })

    local counts = state:hiddenCounts()
    local columnW = (t.w - 8) / 10
    for value = 1, 10 do
        local cx = t.x + 4 + columnW * (value - 0.5)
        local count = counts[value]
        UI.textCentered(value == 1 and "A" or tostring(value), cx, t.y + 21, fonts.tiny, C.textDim, { shadow = false })
        UI.textCentered(tostring(count), cx, t.y + 37, fonts.small, count == 0 and C.textDim or C.text,
            { alpha = count == 0 and 0.5 or 1 })
    end
end

function SidebarView:renderLedger(state)
    local C, fonts = UI.colors, self.assets.fonts
    local l = self.ledgerRect
    UI.box(l.x, l.y, l.w, l.h, C.panelDark, { radius = 6 })
    UI.text("LEDGER", l.x + 7, l.y + 5, fonts.tiny, C.textDim, { shadow = false })
    if self.ledgerCount == 0 then
        UI.textCentered("No hands played yet", l.x + l.w / 2, l.y + l.h / 2 + 4, fonts.small, C.textDim)
        return
    end
    local rows = math.floor((l.h - 22) / ROW_HEIGHT)
    local first = math.max(1, self.ledgerCount - rows + 1)
    for i = first, self.ledgerCount do
        local entry = state.ledger[i]
        local rowY = l.y + 18 + (i - first) * ROW_HEIGHT
        local mine = entry.winner == "player"
        local color = mine and C.gold or C.red
        UI.text(tostring(entry.hand), l.x + 7, rowY, fonts.small, C.textDim)
        UI.text(mine and "YOU" or "WOLF", l.x + 24, rowY, fonts.small, color)
        UI.text(REASON_LABELS[entry.reason] or "", l.x + 56, rowY + 2, fonts.tiny, C.textDim, { shadow = false })
        local points = "+" .. entry.points
        local juice = i == self.ledgerCount and self.ledgerJuice or nil
        UI.textCentered(points, l.x + l.w - 8 - fonts.small:getWidth(points) / 2, rowY + 6, fonts.small, color,
            { scale = 1 + (juice and juice.scale or 0), r = juice and juice.r or 0 })
    end
end

return SidebarView
