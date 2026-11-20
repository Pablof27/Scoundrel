--[[
    Regicide SidebarView
    Left info panel: Royal Court progress (4 Jacks, 4 Queens, 4 Kings) with the active Victory Tier
    (Gold, Silver or Bronze), turn/Jester/time counters, live Suit Powers reference (highlighting
    enemy immunity and selected attack powers), and run statistics.
]]

local Card   = require("src.Model.card")
local Anim   = require("src.View.anim")
local UI     = require("src.View.ui")
local Config = require("src.Games.Regicide.config")

local SidebarView = {}
SidebarView.__index = SidebarView

local ROW_HEIGHT = 15

SidebarView.STAT_ROWS = {
    { key = "royalsDefeated", label = "Royals overthrown" },
    { key = "exactKills",     label = "Exact kills" },
    { key = "damageDealt",    label = "Damage dealt" },
    { key = "cardsHealed",    label = "Cards healed" },
    { key = "cardsDiscarded", label = "Cards discarded" },
}

function SidebarView:new(assets, x, y, width, height)
    local o = setmetatable({}, self)
    o.assets      = assets
    o.x, o.y      = x, y
    o.w, o.h      = width, height
    o.time        = 0
    o.preview     = nil  -- result of state:previewAttack for the current selection
    o.statValues  = {}
    o.statJuice   = {}
    o.tierShown   = nil
    o.tierJuice   = nil

    local bx, bw = x + 6, width - 12
    o.castleRect = { x = bx, y = y + 34,  w = bw, h = 58 }
    o.infoRect   = { x = bx, y = y + 98,  w = bw, h = 38 }
    o.powersRect = { x = bx, y = y + 142, w = bw, h = 80 }
    o.statsRect  = { x = bx, y = y + 228, w = bw, h = 98 }
    return o
end

function SidebarView:buttonsY()
    return self.y + self.h - 36
end

local function inside(rect, x, y)
    return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
end

function SidebarView:boxAt(x, y)
    if inside(self.castleRect, x, y) then
        return "castle"
    elseif inside(self.infoRect, x, y) then
        return "info"
    elseif inside(self.powersRect, x, y) then
        return "powers"
    elseif inside(self.statsRect, x, y) then
        return "stats"
    end
    return nil
end

function SidebarView:update(dt, state)
    self.time = self.time + dt

    local tier = Config.tierForJokersUsed(state.jokersUsed)
    if self.tierShown ~= nil and self.tierShown ~= tier then
        self.tierJuice = Anim.newJuice(0.28, 0.06, 0.35)
    end
    self.tierShown = tier
    self.tierJuice = Anim.updateJuice(self.tierJuice, dt)

    for _, row in ipairs(self.STAT_ROWS) do
        local value = state.stats[row.key]
        local previous = self.statValues[row.key]
        if previous ~= nil and previous ~= value then
            self.statJuice[row.key] = Anim.newJuice(0.3, 0.08, 0.35)
        end
        self.statValues[row.key] = value
        self.statJuice[row.key] = Anim.updateJuice(self.statJuice[row.key], dt)
    end
end

function SidebarView:render(state, runTime)
    local C, fonts = UI.colors, self.assets.fonts
    local x, y, w = self.x, self.y, self.w

    UI.box(x, y, w, self.h, C.panel, { radius = 8, depth = 3 })
    UI.wavyText("REGICIDE", x + w / 2, y + 17, fonts.big, self.time,
        { amplitude = 1.2, speed = 2.2, spacing = 0.6, shadowDepth = 2 })

    self:renderCastle(state)
    self:renderInfo(state, runTime)
    self:renderPowers(state)
    self:renderStats(state)
end

function SidebarView:renderCastle(state)
    local C, fonts = UI.colors, self.assets.fonts
    local r = self.castleRect
    UI.box(r.x, r.y, r.w, r.h, C.panelDark, { radius = 6 })
    UI.text("ROYAL COURT", r.x + 7, r.y + 5, fonts.tiny, C.textDim, { shadow = false })

    local tierInfo = Config.TIERS[Config.tierForJokersUsed(state.jokersUsed)]
    local badgeLabel = (state.gameOver and not state.won) and "FALLEN" or tierInfo.name:upper()
    local badgeColor = (state.gameOver and not state.won) and C.red or C[tierInfo.color]
    local badgeW = fonts.tiny:getWidth(badgeLabel) + 8
    local juice = self.tierJuice
    UI.box(r.x + r.w - badgeW - 5, r.y + 3, badgeW, 11, badgeColor, { radius = 3 })
    UI.textCentered(badgeLabel, r.x + r.w - 5 - badgeW / 2, r.y + 8.5, fonts.tiny,
        badgeColor == C.gold and C.textDark or C.text,
        { shadow = false, scale = 1 + (juice and juice.scale or 0), r = juice and juice.r or 0 })

    local remaining = state:remainingRoyalsByRank()
    local colW = r.w / #Config.ROYAL_RANKS
    local pipSize, pipGap = 7, 3
    local pipsW = 4 * pipSize + 3 * pipGap

    for i, rank in ipairs(Config.ROYAL_RANKS) do
        local cx = r.x + colW * (i - 0.5)
        local left = remaining[rank]
        local defeated = 4 - left
        local isCurrentTier = state.currentEnemy and state.currentEnemy.rank == rank
        local labelColor = left == 0 and C.heal or (isCurrentTier and C.gold or C.textDim)
        UI.textCentered(UI.rankName(rank) .. "s", cx, r.y + 25, fonts.small, labelColor)

        local startX = math.floor(cx - pipsW / 2)
        local pipY = r.y + 39
        for p = 1, 4 do
            local px = startX + (p - 1) * (pipSize + pipGap)
            if p <= defeated then
                UI.box(px, pipY, pipSize, pipSize, C.heal, { radius = 2 })
            elseif p == defeated + 1 and isCurrentTier then
                local pulse = 0.65 + 0.35 * math.sin(self.time * 7)
                UI.box(px, pipY, pipSize, pipSize, C.red, { radius = 2, alpha = pulse, outline = C.gold })
            else
                UI.box(px, pipY, pipSize, pipSize, C.panelLight, { radius = 2, alpha = 0.45 })
            end
        end
    end
end

function SidebarView:renderInfo(state, runTime)
    local C, fonts = UI.colors, self.assets.fonts
    local info = self.infoRect
    UI.box(info.x, info.y, info.w, info.h, C.panelDark, { radius = 6 })

    local jesterColor = state.availableJokers == 0 and C.textDim
        or (state.jokersUsed == 0 and C.gold or C.purple)
    local columns = {
        { label = "TURN",    value = tostring(state.turnNumber), color = C.text },
        { label = "JESTERS", value = state.availableJokers .. "/" .. state.maxJokers, color = jesterColor },
        { label = "TIME",    value = UI.formatTime(runTime), color = C.text },
    }
    local colW = info.w / #columns
    for i, col in ipairs(columns) do
        local cx = info.x + colW * (i - 0.5)
        UI.textCentered(col.label, cx, info.y + 9, fonts.tiny, C.textDim, { shadow = false })
        UI.textCentered(col.value, cx, info.y + 25, fonts.medium, col.color)
    end
end

function SidebarView:renderPowers(state)
    local C, fonts = UI.colors, self.assets.fonts
    local p = self.powersRect
    UI.box(p.x, p.y, p.w, p.h, C.panelDark, { radius = 6 })
    UI.text("SUIT POWERS", p.x + 7, p.y + 5, fonts.tiny, C.textDim, { shadow = false })

    local enemySuit = state.currentEnemy and state.currentEnemy.suit or nil
    local preview = self.preview
    for i, suitInfo in ipairs(Config.SUITS) do
        local rowY = p.y + 17 + (i - 1) * ROW_HEIGHT
        local immune = enemySuit == suitInfo.suit
        local active = preview and preview.activeSuits[suitInfo.suit]
        local alpha = immune and 0.4 or 1

        UI.icon(self.assets, suitInfo.icon, p.x + 6, rowY, 12, alpha)
        UI.text(suitInfo.short, p.x + 21, rowY, fonts.small,
            active and C[suitInfo.color] or (immune and C.textDim or C.text), { alpha = alpha })

        local tag, tagColor
        if immune then
            tag, tagColor = "IMMUNE", C.red
        elseif active then
            if suitInfo.suit == Card.SUITS.HEART then
                tag, tagColor = "+" .. preview.healCount, C.heal
            elseif suitInfo.suit == Card.SUITS.DIAMOND then
                tag, tagColor = "+" .. preview.drawCount, C.blue
            elseif suitInfo.suit == Card.SUITS.CLUB then
                tag, tagColor = "x2", C.orange
            elseif suitInfo.suit == Card.SUITS.SPADE then
                tag, tagColor = "-" .. preview.shieldGain, C.purple
            end
        end
        if tag then
            local font = immune and fonts.tiny or fonts.small
            local ty = immune and (rowY + 2) or rowY
            UI.text(tag, p.x + p.w - 6 - font:getWidth(tag), ty, font, tagColor, { shadow = not immune })
        end
    end
end

function SidebarView:renderStats(state)
    local C, fonts = UI.colors, self.assets.fonts
    local s = self.statsRect
    UI.box(s.x, s.y, s.w, s.h, C.panelDark, { radius = 6 })
    UI.text("RUN STATS", s.x + 7, s.y + 5, fonts.tiny, C.textDim, { shadow = false })

    for i, row in ipairs(self.STAT_ROWS) do
        local rowY = s.y + 17 + (i - 1) * ROW_HEIGHT
        UI.text(row.label, s.x + 7, rowY, fonts.small, C.textDim)
        local juice = self.statJuice[row.key]
        local value = tostring(state.stats[row.key])
        local valueX = s.x + s.w - 7 - fonts.small:getWidth(value) / 2
        UI.textCentered(value, valueX, rowY + 6, fonts.small, juice and C.gold or C.text,
            { scale = 1 + (juice and juice.scale or 0), r = juice and juice.r or 0 })
    end
end

return SidebarView
