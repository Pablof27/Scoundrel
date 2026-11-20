--[[
    Regicide GameView
    The table:
      - Top row: Castle deck, current Royal enemy, Royal combat HUD (health bar with live damage/kill
        preview, suit immunity, attack and Spades shield) and the cards played against this Royal.
      - Middle row: Discard pile, action preview & hint panel with ATTACK/DEFEND and JESTER buttons,
        and the Tavern deck.
      - Bottom row: Your hand (up to 8 cards).
    Keeps one CardView per card and reconciles them with the GameState after every event.
]]

local Card        = require("src.Model.card")
local BoardView   = require("src.View.boardView")
local DeckView    = require("src.View.deckView")
local Button      = require("src.View.buttonView")
local Anim        = require("src.View.anim")
local UI          = require("src.View.ui")
local Config      = require("src.Games.Regicide.config")
local GameState   = require("src.Games.Regicide.Model.gameState")
local SidebarView = require("src.Games.Regicide.View.sidebarView")
local Actions     = require("src.Games.Regicide.Controller.actions")

local GameView = BoardView.extend()

local SIDEBAR_WIDTH  = Constants.SIDEBAR_WIDTH
local SAFE_X, SAFE_Y = Constants.SAFE_X, Constants.SAFE_Y

local ROW_GAP        = 12
local LIFT           = 12
local DEAL_INTERVAL  = 0.08
local HIT_TIME       = 0.24
local CLEAR_TIME     = 0.48
local DRAW_DELAY     = 0.42
local DISCARD_SHOWN  = 8
local JESTER_CONFIRM = 2.5

local function discardJitter(card)
    local p = card.position
    return (p * 7 % 5 - 2) * 1.5, (p * 3 % 5 - 2) * 1.2, (p * 13 % 9 - 4) * 0.03
end

local function positions(cards)
    local set = {}
    for _, card in ipairs(cards or {}) do
        set[card.position] = true
    end
    return set
end

local function royalTitle(card)
    local royal = Config.ROYALS[card.rank]
    local suit = Config.SUIT_BY_ID[card.suit]
    return (royal and royal.name:upper() or UI.rankName(card.rank)) .. " OF " .. suit.name:upper()
end

local function cardLabel(card)
    local suit = Config.SUIT_BY_ID[card.suit]
    if card.rank == Card.ACE then
        return "Animal Companion of " .. suit.name .. " (1)"
    elseif card.rank >= 11 then
        return Config.ROYALS[card.rank].name .. " of " .. suit.name .. " (" .. card.value .. ")"
    end
    return card.rank .. " of " .. suit.name
end

local function cardsEquation(cards)
    local parts = {}
    for _, card in ipairs(cards) do
        table.insert(parts, UI.rankName(card.rank) .. (card.rank >= 11 and ("(" .. card.value .. ")") or ""))
    end
    return table.concat(parts, " + ")
end

function GameView:new(context, gameState)
    local o = setmetatable({}, self)
    BoardView.init(o, context)
    o.state        = gameState
    o.selected     = {}
    o.candidates   = {}
    o.preview      = nil
    o.playReason   = nil
    o.hoveredView  = nil
    o.jesterArmed  = 0
    o.shownLife    = gameState.enemyLife
    o.targetLife   = gameState.enemyLife
    o.shownMaxLife = gameState.enemyMaxLife
    o.lifeFlash    = 0
    o.lifeJuice    = nil

    o:computeLayout()
    local L = o.layout
    o.enemyDeck  = DeckView:new(o.assets, L.castleX, L.enemyY)
    o.tavernDeck = DeckView:new(o.assets, L.tavernX, L.pileY)
    o.sidebar    = SidebarView:new(o.assets, L.sidebar.x, L.sidebar.y, L.sidebar.w, L.sidebar.h)

    o:setState(gameState)
    o:createButtons()
    o:subscribe()

    local dealDelay = 0.25
    local dealt = o:sync({ dealDelay = dealDelay, drawn = positions(gameState.hand), enemyFlip = true })
    o.lock = dealDelay + dealt * DEAL_INTERVAL + 0.3
    if gameState.currentEnemy then
        o:showBanner(royalTitle(gameState.currentEnemy), UI.colors.gold, L.centerX, L.pileY - 14, dealDelay + 0.1)
    end
    return o
end

function GameView:computeLayout()
    local size = self.assets:getCardSize()
    local W, H = self.assets.WIDTH, self.assets.HEIGHT
    local L = { cardW = size.width, cardH = size.height }

    L.sidebar = { x = SAFE_X, y = SAFE_Y, w = SIDEBAR_WIDTH, h = H - 2 * SAFE_Y }
    L.areaX   = L.sidebar.x + L.sidebar.w + 10
    L.areaW   = math.floor(W - SAFE_X - L.areaX)
    L.centerX = L.areaX + L.areaW / 2

    -- Top row: Castle deck, current Royal, Royal HUD, and active combat stack.
    L.topLabelY = SAFE_Y + 1
    L.enemyY    = SAFE_Y + 16 + size.height / 2
    L.castleX   = L.areaX + size.width / 2 + 4
    L.enemyX    = L.castleX + size.width + 14
    local hudX  = math.floor(L.enemyX + size.width / 2 + 10)
    L.hud       = { x = hudX, y = math.floor(L.enemyY - size.height / 2), w = 172, h = size.height }
    L.battleLeft  = L.hud.x + L.hud.w + 10
    L.battleRight = L.areaX + L.areaW
    L.battleCenterX = (L.battleLeft + L.battleRight) / 2

    -- Bottom row: player's hand.
    L.handY      = H - SAFE_Y - 18 - size.height / 2
    L.handLabelY = L.handY + size.height / 2 + 5

    -- Middle row: Discard pile, preview panel + buttons, and Tavern deck.
    L.pileY    = math.floor((L.enemyY + L.handY) / 2) + 0.5
    L.discardX = L.castleX
    L.tavernX  = L.areaX + L.areaW - size.width / 2 - 4

    local panelX     = math.floor(L.discardX + size.width / 2 + 14)
    local panelRight = math.floor(L.tavernX - size.width / 2 - 14)
    L.panel    = { x = panelX, y = math.floor(L.pileY - 48), w = panelRight - panelX, h = 66 }
    L.buttonsY = L.panel.y + L.panel.h + 7

    self.layout = L
end

function GameView:createButtons()
    local L, C = self.layout, UI.colors
    local function button(params)
        return Button:new(params, self.assets, self.mouseProvider)
    end

    local actW, jesterW, gap = 136, 122, 10
    local left = math.floor(L.centerX - (actW + gap + jesterW) / 2)
    self.actButton = button({
        x = left, y = L.buttonsY, width = actW, height = 26,
        text = "ATTACK", color = C.blue, hotkey = "ENTER",
        onClick = function() self:confirmSelection() end,
    })
    self.jesterButton = button({
        x = left + actW + gap, y = L.buttonsY, width = jesterW, height = 26,
        text = "JESTER", color = C.purple, hotkey = "J",
        onClick = function() self:useJester() end,
    })

    local buttonsY = self.sidebar:buttonsY()
    local half = (L.sidebar.w - 18) / 2
    self.rulesButton = button({
        x = L.sidebar.x + 6, y = buttonsY, width = half, height = 26,
        text = "RULES", color = C.orange,
        onClick = function() self.eventBus:publish("navigate", "rules") end,
    })
    self.menuButton = button({
        x = L.sidebar.x + 12 + half, y = buttonsY, width = half, height = 26,
        text = "MENU", color = C.green, hotkey = "ESC",
        onClick = function() self:openMenu() end,
    })

    self.buttons = { self.actButton, self.jesterButton, self.rulesButton, self.menuButton }
end

function GameView:subscribe()
    self:on("attacked", function(gameState, outcome) self:onAttacked(gameState, outcome) end)
    self:on("defended", function(gameState, outcome) self:onDefended(gameState, outcome) end)
    self:on("jokerPlayed", function(gameState, outcome) self:onJokerPlayed(gameState, outcome) end)
    self:on("endGame", function(didWin, gameState) self:onEndGame(didWin, gameState) end)
end

function GameView:setState(gameState)
    self.state = gameState
    self.selected = {}
    self.jesterArmed = 0
    self:refreshSelection()
end

------------------------------------------------------------------------
-- Selection
------------------------------------------------------------------------

function GameView:selectedCards()
    local list = {}
    for _, card in ipairs(self.state.hand) do
        if self.selected[card.position] then
            table.insert(list, card)
        end
    end
    return list
end

function GameView:refreshSelection()
    local state = self.state
    local chosen = self:selectedCards()
    self.candidates = {}
    self.preview = nil
    self.playReason = nil

    if state.gameOver then
        self.sidebar.preview = nil
        return
    end

    if state.phase == "attack" then
        if #chosen > 0 then
            self.preview, self.playReason = state:previewAttack(chosen)
        end
        for _, card in ipairs(state.hand) do
            if #chosen == 0 or self.selected[card.position] then
                self.candidates[card.position] = true
            else
                local trial = {}
                for _, c in ipairs(chosen) do
                    table.insert(trial, c)
                end
                table.insert(trial, card)
                if GameState.classifyAttack(trial) ~= nil then
                    self.candidates[card.position] = true
                end
            end
        end
    else
        local enough = state:selectionCanDefend(chosen)
        for _, card in ipairs(state.hand) do
            if not enough or self.selected[card.position] then
                self.candidates[card.position] = true
            end
        end
    end

    self.sidebar.preview = self.preview
end

function GameView:toggleCard(view)
    local card = view.card
    local key = card.position
    self.jesterArmed = 0

    if self.state.phase == "attack" and not self.selected[key] and not self.candidates[key] then
        -- Clicking a card incompatible with the current attack switches cleanly to that card.
        self.selected = { [key] = true }
    else
        self.selected[key] = not self.selected[key] or nil
    end

    view:juiceUp(0.12, 0.03)
    self.assets.audio:play("deal", { volume = 0.6, pitch = self.selected[key] and 1.15 or 0.9, variation = 0.05 })
    self:refreshSelection()
    self:sync()
end

function GameView:clearSelection()
    if next(self.selected) == nil then
        return
    end
    self.selected = {}
    self.assets.audio:play("deal", { volume = 0.5, pitch = 0.8 })
    self:refreshSelection()
    self:sync()
end

------------------------------------------------------------------------
-- Reconciliation: model -> card views
------------------------------------------------------------------------

function GameView:handX(index, count)
    local L = self.layout
    local spacing = L.cardW + ROW_GAP
    if count > 1 then
        spacing = math.min(spacing, math.floor((L.areaW - L.cardW) / (count - 1)))
    end
    local width = spacing * (count - 1) + L.cardW
    return math.floor(L.centerX - width / 2) + L.cardW / 2 + (index - 1) * spacing
end

function GameView:battleX(index, count)
    local L = self.layout
    local availW = L.battleRight - L.battleLeft
    if count <= 1 then
        return L.battleCenterX
    end
    local spacing = math.min(20, math.floor((availW - L.cardW) / (count - 1)))
    local width = spacing * (count - 1) + L.cardW
    return math.floor(L.battleCenterX - width / 2) + L.cardW / 2 + (index - 1) * spacing
end

--[[
    Moves every CardView to match the GameState:
      - currentEnemy at the Royal slot
      - playedCards fanned in the combat zone
      - hand along the bottom row
      - top of discardPile on the discard slot
      - cards healed by Hearts or Exact-Killed Royals slide face-down into the Tavern deck
]]
function GameView:sync(opts)
    opts = opts or {}
    local L, state = self.layout, self.state
    local present = {}
    local drawnSet = opts.drawn or {}
    local drawn = 0
    local dealDelay = opts.dealDelay or 0

    self.enemyDeck:setCount(#state.enemyDeck.cards)
    self.tavernDeck:setCount(#state.playerDeck.cards)
    local castleX, castleY = self.enemyDeck:topPosition()
    local tavernX, tavernY = self.tavernDeck:topPosition()

    -- Current Royal enemy.
    local enemy = state.currentEnemy
    if enemy then
        local prev = self.views[enemy.position]
        local isNewEnemy = opts.enemyFlip or prev == nil or prev.zone == "castle" or prev.zone == "gone"
        local view = self:placeCard(enemy, "enemy", L.enemyX, L.enemyY, 0, present)
        view.slot = 1
        if isNewEnemy then
            view:snapTo(castleX, castleY, 0)
            view:setTarget(L.enemyX, L.enemyY, 0)
            view.flip = -1
            view.faceUp = true
            view.delay = opts.enemyDelay or dealDelay
            self:after(view.delay, function()
                self.assets.audio:play("room")
            end)
        end
    end

    -- Cards played against the current Royal.
    local battleCount = #state.playedCards
    for i, card in ipairs(state.playedCards) do
        local bx = self:battleX(i, battleCount)
        local r = (i - (battleCount + 1) / 2) * 0.035
        local view = self:placeCard(card, "battle", bx, L.enemyY, r, present)
        view.slot = i
    end

    -- Player hand.
    local function fromTavern(view)
        return view == nil or view.zone == "tavern" or view.zone == "gone" or
            (view.zone == "exiting" and view.exitKind == "tavern")
    end
    local handCount = #state.hand
    for i, card in ipairs(state.hand) do
        local previous = self.views[card.position]
        local wasInDeck = drawnSet[card.position] or fromTavern(previous)
        local lift = self.selected[card.position] and -LIFT or 0
        local hx, hy = self:handX(i, handCount), L.handY + lift
        local view = self:placeCard(card, "hand", hx, hy, 0, present)
        view.slot = i
        if wasInDeck then
            view:snapTo(tavernX, tavernY, 0)
            view:setTarget(hx, hy, 0)
            view.flip = -1
            view.faceUp = true
            view.delay = dealDelay + drawn * DEAL_INTERVAL
            self:after(view.delay, function()
                self.assets.audio:play("deal", { variation = 0.15 })
            end)
            drawn = drawn + 1
        end
    end

    -- Top of the discard pile.
    local pile = state.discardPile
    for i = math.max(1, #pile - DISCARD_SHOWN + 1), #pile do
        local dx, dy, r = discardJitter(pile[i])
        local view = self:placeCard(pile[i], "discard", L.discardX + dx, L.pileY + dy, r, present)
        view.pileIndex = i
        view.slot = nil
        if opts.discardDelay and opts.discarded and opts.discarded[pile[i].position] then
            view.delay = opts.discardDelay
        end
    end

    -- Cards inside the Tavern deck (healed from Discard, or an Exact-Killed Royal).
    local inTavern = positions(state.playerDeck.cards)
    for key, view in pairs(self.views) do
        if not present[key] then
            if inTavern[key] and view.zone == "gone" then
                view.zone = "tavern"
            elseif inTavern[key] and view.zone ~= "tavern"
                and not (view.zone == "exiting" and view.exitKind == "tavern") then
                self:sendToTavern(view, opts.tavernDelay or 0)
            elseif not inTavern[key] and view.zone ~= "gone" then
                view.zone = "gone"
            end
        end
    end

    return drawn
end

function GameView:sendToTavern(view, delay)
    local x, y = self.tavernDeck:topPosition()
    view.zone = "exiting"
    view.exitKind = "tavern"
    view.faceUp = false
    view.hovered = false
    view.slot = nil
    view.delay = delay or 0
    view:setTarget(x, y, 0)
end

function GameView:updateExit(view)
    if view.zone == "exiting" and view.exitKind == "tavern" and view.delay <= 0 and view:distanceToTarget() < 3 then
        view.zone = "tavern"
    end
end

------------------------------------------------------------------------
-- Model events
------------------------------------------------------------------------

function GameView:onAttacked(gameState, outcome)
    local L, C = self.layout, UI.colors
    self:setState(gameState)

    local enemyDelay = outcome.enemyDefeated and (CLEAR_TIME + 0.28) or 0
    local discardedSet = positions(outcome.clearedBattle)
    if outcome.enemyDefeated and not outcome.exactKill then
        discardedSet[outcome.enemy.position] = true
    end

    local dealt = self:sync({
        dealDelay    = DRAW_DELAY,
        drawn        = positions(outcome.drawn),
        enemyFlip    = outcome.nextEnemy ~= nil,
        enemyDelay   = enemyDelay,
        tavernDelay  = outcome.exactKill and CLEAR_TIME or 0.18,
        discardDelay = outcome.enemyDefeated and CLEAR_TIME or nil,
        discarded    = discardedSet,
    })

    -- Played cards strike first.
    for _, card in ipairs(outcome.cards) do
        local view = self.views[card.position]
        if view then
            view:juiceUp(0.18, 0.04)
        end
    end

    local enemyView = self.views[outcome.enemy.position]
    if outcome.enemyDefeated and enemyView then
        -- Keep the defeated Royal at its slot briefly so the killing blow lands on it, then send it away.
        local destX, destY, destR = enemyView.T.x, enemyView.T.y, enemyView.T.r
        local wasFaceUp = enemyView.faceUp
        enemyView.faceUp = true
        enemyView.delay = 0
        enemyView:setTarget(L.enemyX, L.enemyY, 0)
        self:after(CLEAR_TIME, function()
            enemyView.faceUp = wasFaceUp
            enemyView:setTarget(destX, destY, destR)
        end)
    end
    for i, card in ipairs(outcome.clearedBattle) do
        local view = self.views[card.position]
        if view and view.zone == "discard" then
            local destX, destY, destR = view.T.x, view.T.y, view.T.r
            local bx = self:battleX(i, #outcome.clearedBattle)
            view.delay = 0
            view:setTarget(bx, L.enemyY, 0)
            self:after(CLEAR_TIME + i * 0.025, function()
                if view.zone == "discard" then
                    view:setTarget(destX, destY, destR)
                end
            end)
        end
    end

    -- Suit power feedback.
    if #outcome.healed > 0 then
        self:after(0.14, function()
            self.assets.audio:play("heal")
            self.effects:floatText("+" .. #outcome.healed .. " TAVERN", L.tavernX, L.pileY - 56, C.heal,
                { font = self.assets.fonts.medium, duration = 1.0, rise = 14 })
            self.effects:burst(L.discardX, L.pileY, C.heal, 12, { speed = 80 })
        end)
    end
    if outcome.shieldGain > 0 then
        self:after(0.18, function()
            self.assets.audio:play("block")
            self.effects:floatText("-" .. outcome.shieldGain .. " ATK", L.hud.x + L.hud.w / 2, L.enemyY + 34, C.purple,
                { font = self.assets.fonts.medium, duration = 1.0, rise = 12 })
        end)
    end

    -- Impact on the Royal.
    self:after(HIT_TIME, function()
        self.assets.audio:play(outcome.doubled and "capture" or "hit")
        local hitColor = outcome.doubled and C.orange or C.damage
        local dmgLabel = (outcome.doubled and "x2! -" or "-") .. outcome.damage
        self.effects:floatText(dmgLabel, L.enemyX, L.enemyY - 26, hitColor, { font = self.assets.fonts.big })
        self.effects:burst(L.enemyX, L.enemyY, hitColor, outcome.doubled and 22 or 14, { speed = 130, spread = 18 })
        self:shake(outcome.doubled and 5 or 3)
        self.lifeFlash = 1
        if enemyView then
            enemyView:flashWhite(0.85)
            enemyView:juiceUp(0.25, 0.06)
        end
        if outcome.enemyDefeated then
            self.targetLife = 0
        else
            self.targetLife = gameState.enemyLife
            self.shownMaxLife = gameState.enemyMaxLife
        end
    end)

    if outcome.enemyDefeated then
        self:after(CLEAR_TIME, function()
            if outcome.exactKill then
                self.assets.audio:play("equip")
                self:flashScreen(C.gold, 0.35)
                self.effects:burst(L.enemyX, L.enemyY, C.gold, 24, { speed = 150, up = 60 })
                self:showBanner("EXACT KILL! -> TAVERN", C.gold, L.centerX, L.pileY - 14)
            else
                self.assets.audio:play("burn")
                self:showBanner("ROYAL OVERTHROWN!", C.heal, L.centerX, L.pileY - 14)
            end
        end)
        self:after(enemyDelay, function()
            self.shownMaxLife = gameState.enemyMaxLife
            self.targetLife = gameState.enemyLife
            self.shownLife = gameState.enemyLife
        end)
        if outcome.nextEnemy then
            self:after(enemyDelay + 0.15, function()
                self.effects:floatText(royalTitle(outcome.nextEnemy), L.enemyX + 40, L.enemyY - 56, C.gold,
                    { font = self.assets.fonts.medium, duration = 1.1, rise = 10 })
            end)
        end
    elseif outcome.autoBlocked then
        self:after(HIT_TIME + 0.28, function()
            self.assets.audio:play("block")
            self.effects:floatText("BLOCKED!", L.enemyX, L.enemyY + 26, C.heal,
                { font = self.assets.fonts.big, duration = 0.9, rise = 12 })
        end)
    elseif outcome.incoming and outcome.incoming > 0 and not gameState.gameOver then
        self:after(HIT_TIME + 0.26, function()
            self:flashScreen(C.damage, 0.18)
        end)
    end

    local animEnd = HIT_TIME + 0.35
    if outcome.enemyDefeated then
        animEnd = math.max(animEnd, enemyDelay + 0.45)
    end
    if dealt > 0 then
        animEnd = math.max(animEnd, DRAW_DELAY + dealt * DEAL_INTERVAL + 0.25)
    end
    self.lock = animEnd
end

function GameView:onDefended(gameState, outcome)
    local L, C = self.layout, UI.colors
    self:setState(gameState)
    self:sync()

    local clashX, clashY = L.enemyX + 26, L.pileY - 24
    for i, card in ipairs(outcome.cards) do
        local view = self.views[card.position]
        if view and view.zone == "discard" then
            local destX, destY, destR = view.T.x, view.T.y, view.T.r
            local spread = (i - (#outcome.cards + 1) / 2) * 16
            view:setTarget(clashX + spread, clashY, (love.math.random() - 0.5) * 0.25)
            view:juiceUp(0.16)
            self:after(0.32 + i * 0.03, function()
                if view.zone == "discard" then
                    view:setTarget(destX, destY, destR)
                end
            end)
        end
    end
    self:after(0.18, function()
        self.assets.audio:play("block")
        self.effects:burst(clashX, clashY, C.blue, 14, { speed = 100, spread = 16 })
        self.effects:floatText("DEFENDED " .. outcome.incoming, clashX, clashY - 24, C.blue,
            { font = self.assets.fonts.medium, duration = 0.85, rise = 12 })
        self:shake(2.5)
    end)

    self.lock = 0.55
end

function GameView:onJokerPlayed(gameState, outcome)
    local L, C = self.layout, UI.colors
    self:setState(gameState)

    local dealDelay = #outcome.discarded > 0 and 0.32 or 0.1
    local dealt = self:sync({ dealDelay = dealDelay, drawn = positions(outcome.drawn) })

    self.assets.audio:play("flee")
    self:showBanner("JESTER FLIPPED!", C.purple, L.centerX, L.pileY - 14)
    self.effects:burst(L.tavernX, L.pileY, C.purple, 18, { speed = 110 })

    self.lock = dealDelay + dealt * DEAL_INTERVAL + 0.3
end

function GameView:onEndGame(didWin, gameState)
    self.over = true
    self.jesterArmed = 0
    local L, C = self.layout, UI.colors
    local delay = self.lock + 0.9

    self:after(delay, function()
        if didWin then
            local tier = Config.TIERS[gameState:victoryTier()]
            local color = C[tier.color]
            self.assets.audio:play("victory")
            self.effects:floatText(tier.title, L.centerX, L.pileY - 10, color,
                { font = self.assets.fonts.large, duration = 1.7, rise = 18 })
            for i = 1, 6 do
                self:after(i * 0.11, function()
                    local x = L.areaX + love.math.random() * L.areaW
                    self.effects:burst(x, L.handY, i % 2 == 0 and C.gold or color, 16, { speed = 145, up = 85 })
                end)
            end
        else
            self.assets.audio:play("defeat")
            self:shake(8)
            self:flashScreen(C.damage, 0.6)
            local msg = gameState.loseReason == "noCards" and "OUT OF CARDS" or "OVERWHELMED"
            self.effects:floatText(msg, L.centerX, L.pileY - 10, C.red,
                { font = self.assets.fonts.large, duration = 1.7, rise = 18 })
        end
    end)

    self:after(delay + 1.7, function()
        self.eventBus:publish("navigate", "endGame", { didWin = didWin, gameState = gameState, runTime = self.runTime })
    end)
end

------------------------------------------------------------------------
-- Player input
------------------------------------------------------------------------

function GameView:isBusy()
    return self.over or self.lock > 0
end

function GameView:canConfirm()
    local chosen = self:selectedCards()
    if self.state.phase == "attack" then
        return self.preview ~= nil
    end
    return self.state:selectionCanDefend(chosen)
end

function GameView:confirmSelection()
    if self:isBusy() then
        return
    end
    local chosen = self:selectedCards()
    if not self:canConfirm() then
        self.actButton.juice = Anim.newJuice(0.03, 0.06, 0.25)
        self.assets.audio:play("denied")
        return
    end
    if self.state.phase == "attack" then
        self.eventBus:publish("action", Actions.PlayCardAction:new(chosen))
    else
        self.eventBus:publish("action", Actions.DefendAction:new(chosen))
    end
end

function GameView:useJester()
    if self:isBusy() then
        return
    end
    if not self.state:canPlayJoker() then
        self.jesterButton.juice = Anim.newJuice(0.03, 0.06, 0.25)
        self.assets.audio:play("denied")
        return
    end
    if self.jesterArmed <= 0 then
        self.jesterArmed = JESTER_CONFIRM
        self.jesterButton.juice = Anim.newJuice(0.1, 0.04, 0.35)
        return
    end
    self.jesterArmed = 0
    self.eventBus:publish("action", Actions.PlayJokerAction:new())
end

function GameView:openMenu()
    if not self.over then
        self.eventBus:publish("navigate", "pause")
    end
end

function GameView:handCardAt(x, y)
    for i = #self.state.hand, 1, -1 do
        local view = self.views[self.state.hand[i].position]
        if view and view.zone == "hand" and view:contains(x, y) then
            return view
        end
    end
    return nil
end

function GameView:discardHovered(x, y)
    local L = self.layout
    return math.abs(x - L.discardX) <= L.cardW / 2 and math.abs(y - L.pileY) <= L.cardH / 2
end

function GameView:hudHovered(x, y)
    local h = self.layout.hud
    return x >= h.x and x <= h.x + h.w and y >= h.y and y <= h.y + h.h
end

function GameView:enemyHovered(x, y)
    local enemy = self.state.currentEnemy
    local view = enemy and self.views[enemy.position]
    return view ~= nil and view.zone == "enemy" and view:contains(x, y)
end

function GameView:onMouseClick(mouseX, mouseY, button)
    if self.over then
        return
    end
    for _, b in ipairs(self.buttons) do
        if b:onMouseClick(mouseX, mouseY) then
            return
        end
    end
    self.jesterArmed = 0
    if self:isBusy() then
        return
    end
    if button == 2 then
        self:clearSelection()
        return
    end
    local view = self:handCardAt(mouseX, mouseY)
    if view then
        self:toggleCard(view)
    end
end

function GameView:onKeyPressed(key)
    if self.over then
        return
    end
    if key == "escape" then
        self:openMenu()
    elseif key == "return" or key == "space" then
        self:confirmSelection()
    elseif key == "backspace" or key == "delete" then
        self:clearSelection()
    elseif key == "j" then
        self:useJester()
    else
        local idx = tonumber(key)
        if idx and idx >= 1 and idx <= #self.state.hand and not self:isBusy() then
            local view = self.views[self.state.hand[idx].position]
            if view and view.zone == "hand" then
                self:toggleCard(view)
            end
        end
    end
end

------------------------------------------------------------------------
-- Update
------------------------------------------------------------------------

function GameView:update(dt, hasFocus)
    self:updateClock(dt, hasFocus)
    if hasFocus then
        self.jesterArmed = math.max(0, self.jesterArmed - dt)
    end

    local mouseX, mouseY = self.mouseProvider()
    if not hasFocus then
        mouseX, mouseY = -1000, -1000
    end
    self:updateHover(mouseX, mouseY)
    self.mouseX, self.mouseY = mouseX, mouseY

    local state = self.state
    local before = math.floor(self.shownLife + 0.5)
    self.shownLife = Anim.moveTowards(self.shownLife, self.targetLife, dt * 45)
    if math.floor(self.shownLife + 0.5) ~= before then
        self.lifeJuice = Anim.newJuice(0.18, 0.05, 0.25)
    end
    self.lifeJuice = Anim.updateJuice(self.lifeJuice, dt)
    self.lifeFlash = math.max(0, self.lifeFlash - dt * 2.5)

    local playing = not self.over
    for key, view in pairs(self.views) do
        if view.zone ~= "gone" and view.zone ~= "tavern" and view.zone ~= "castle" then
            local dim = playing and view.zone == "hand" and not self.candidates[key]
            view.tint = Anim.approach(view.tint, dim and 0.58 or 1, 8, dt)
            view:update(dt, mouseX, mouseY)
            self:updateExit(view)
        end
    end

    self.enemyDeck:update(dt, mouseX, mouseY)
    self.tavernDeck:update(dt, mouseX, mouseY)
    self.sidebar:update(dt, state)
    for _, b in ipairs(self.buttons) do
        b:update(dt, hasFocus)
    end

    local busy = self:isBusy()
    local isAttack = state.phase == "attack"
    self.actButton.text = isAttack and "ATTACK" or "DEFEND"
    self.actButton.color = isAttack and UI.colors.blue or UI.colors.red
    self.actButton.disabled = busy or not self:canConfirm()

    self.jesterButton.disabled = busy or not state:canPlayJoker()
    self.jesterButton.color = self.jesterArmed > 0 and UI.colors.gold or UI.colors.purple
    self.jesterButton.text = self.jesterArmed > 0 and "FLIP JESTER?"
        or ("JESTER (" .. state.availableJokers .. ")")

    self:updateFeedback(dt)
end

function GameView:updateHover(mouseX, mouseY)
    local hovered = nil
    if not self:isBusy() then
        hovered = self:handCardAt(mouseX, mouseY)
    end
    if hovered ~= self.hoveredView and hovered then
        hovered:juiceUp(0.05, 0.02)
        self.assets.audio:play("hover", { pitch = 0.7, variation = 0.1 })
    end
    self.hoveredView = hovered
    for _, view in pairs(self.views) do
        view.hovered = view == hovered
    end
end

------------------------------------------------------------------------
-- Rendering
------------------------------------------------------------------------

function GameView:render()
    self:beginRender()

    self.sidebar:render(self.state, self.runTime)
    self:renderTable()
    self:renderRoyalHud()
    self:renderPanel()

    for _, view in ipairs(self:drawList(true)) do
        view:draw()
    end
    self.enemyDeck:render()
    self.tavernDeck:render()
    for _, view in ipairs(self:drawList(false)) do
        if self.selected[view.card.position] and view.zone == "hand" then
            self:renderHalo(view)
        end
        view:draw()
    end
    self:renderPileLabels()

    for _, b in ipairs(self.buttons) do
        b:render()
    end

    self:endRender()
end

function GameView:layerOf(view)
    if view.delay > 0 then
        return 3 - view.delay
    end
    if view:distanceToTarget() > 3 then
        return view.zone == "discard" and 3.5 or 3
    end
    if view.zone == "discard" then
        return (view.pileIndex or 0) * 0.0001
    end
    if view.zone == "battle" then
        return 1 + (view.slot or 0) * 0.001
    end
    if view.zone == "enemy" then
        return 1.5
    end
    if view.hovered then
        return 2.6
    end
    return 2 + (self.selected[view.card.position] and 0.3 or 0) + (view.slot or 0) * 0.001
end

function GameView:drawList(deckBound)
    local list = {}
    for _, view in pairs(self.views) do
        local isDeckBound = view.zone == "exiting" and view.exitKind == "tavern"
        if view.zone ~= "gone" and view.zone ~= "tavern" and view.zone ~= "castle" and isDeckBound == deckBound then
            view.layer = self:layerOf(view)
            table.insert(list, view)
        end
    end
    return BoardView.sortByLayer(list)
end

function GameView:renderHalo(view)
    local C = UI.colors
    local color = C.white
    if self.state.phase == "attack" and self.preview then
        color = self.preview.exactKill and C.gold
            or (self.preview.killsEnemy and C.heal or C[GameState.PLAY_KINDS[self.preview.kind].color])
    elseif self.state.phase == "defend" then
        color = self:canConfirm() and C.blue or C.orange
    end
    local alpha = 0.55 + 0.25 * math.sin(love.timer.getTime() * 6)
    local s = view.VT.s
    local w, h = (view.width + 6) * s, (view.height + 6) * s
    love.graphics.push()
    love.graphics.translate(view.VT.x, view.VT.y)
    love.graphics.rotate(view.VT.r)
    UI.setColor(color, alpha)
    love.graphics.rectangle("fill", -w / 2, -h / 2, w, h, 7, 7)
    love.graphics.pop()
end

function GameView:renderTable()
    local L, C, fonts = self.layout, UI.colors, self.assets.fonts
    local state = self.state
    local right = L.areaX + L.areaW

    UI.text("THE CASTLE", L.areaX, L.topLabelY, fonts.small, C.red)
    local combatInfo = #state.playedCards > 0 and ("IN COMBAT: " .. #state.playedCards) or "COMBAT ZONE"
    UI.text(combatInfo, right - fonts.small:getWidth(combatInfo), L.topLabelY, fonts.small, C.textDim)

    -- Empty combat slot placeholder.
    if #state.playedCards == 0 then
        UI.box(L.battleCenterX - L.cardW / 2, L.enemyY - L.cardH / 2, L.cardW, L.cardH,
            C.panelDark, { radius = 6, alpha = 0.25 })
        UI.textCentered("PLAYED", L.battleCenterX, L.enemyY, fonts.tiny, C.textDim, { alpha = 0.6, shadow = false })
    end

    -- Empty discard slot placeholder.
    UI.box(L.discardX - L.cardW / 2, L.pileY - L.cardH / 2, L.cardW, L.cardH, C.panelDark, { radius = 6, alpha = 0.3 })
    if #state.discardPile == 0 then
        UI.textCentered("DISCARD", L.discardX, L.pileY, fonts.small, C.textDim, { alpha = 0.7 })
    end

    -- Bottom hand labels.
    local leftLabel = state.phase == "defend"
        and ("DEFEND: DISCARD " .. state:incomingDamage() .. "+")
        or "YOUR HAND"
    local leftColor = state.phase == "defend" and C.red or C.gold
    local handInfo = #state.hand .. "/" .. Config.HAND_SIZE .. " CARDS   TOTAL " .. state:handTotal()
    UI.text(leftLabel, L.areaX, L.handLabelY, fonts.small, leftColor)
    UI.text(handInfo, right - fonts.small:getWidth(handInfo), L.handLabelY, fonts.small, C.text)
end

function GameView:renderPileLabels()
    local L, C, fonts = self.layout, UI.colors, self.assets.fonts
    local y = L.pileY - L.cardH / 2 - 11
    UI.textCentered("DISCARD " .. #self.state.discardPile, L.discardX, y, fonts.tiny, C.textDim, { shadow = false })
    UI.textCentered("TAVERN " .. #self.state.playerDeck.cards, L.tavernX, y, fonts.tiny, C.textDim, { shadow = false })
end

function GameView:renderRoyalHud()
    local C, fonts = UI.colors, self.assets.fonts
    local h = self.layout.hud
    local state = self.state
    local enemy = state.currentEnemy

    UI.box(h.x, h.y, h.w, h.h, C.panelDark, { radius = 7, alpha = 0.88, outline = C.panelLight })
    if not enemy then
        UI.textCentered("CASTLE CLEARED", h.x + h.w / 2, h.y + h.h / 2, fonts.medium, C.gold)
        return
    end

    local suitInfo = Config.SUIT_BY_ID[enemy.suit]
    local royal = Config.ROYALS[enemy.rank]
    local title = royal.name:upper() .. " OF " .. suitInfo.name:upper()
    UI.text(title, h.x + 8, h.y + 6, fonts.small, C.gold)

    -- Immunity banner.
    local immY = h.y + 21
    local immWarn = self.preview and self.preview.immuneTriggered
    UI.box(h.x + 7, immY, h.w - 14, 15, immWarn and UI.shade(C.red, 0.65) or C.panelInner, { radius = 4 })
    UI.icon(self.assets, suitInfo.icon, h.x + 11, immY + 1.5, 12, 1)
    UI.text("IMMUNE: " .. suitInfo.short:upper(), h.x + 26, immY + 3.5, fonts.tiny,
        immWarn and C.white or C.textDim, { shadow = false })

    -- Health readout & bar with live attack preview.
    local hpY = h.y + 42
    local shownHp = math.max(0, math.floor(self.shownLife + 0.5))
    local maxHp = math.max(1, self.shownMaxLife)
    local hpColor = UI.mix(C.text, C.damage, self.lifeFlash)
    local juice = self.lifeJuice
    UI.text("HP", h.x + 8, hpY + 5, fonts.tiny, C.textDim, { shadow = false })
    UI.textCentered(tostring(shownHp), h.x + 40, hpY + 8, fonts.big, hpColor,
        { scale = 1 + (juice and juice.scale or 0), r = juice and juice.r or 0 })
    UI.text("/" .. maxHp, h.x + 58, hpY + 5, fonts.small, C.textDim)

    local blink = 0.55 + 0.45 * math.sin(love.timer.getTime() * 10)
    local preview = self.preview
    if preview then
        local tag, tagColor
        if preview.exactKill then
            tag, tagColor = "EXACT!", C.gold
        elseif preview.killsEnemy then
            tag, tagColor = "KILL!", C.heal
        else
            tag, tagColor = "-" .. preview.damage, C.damage
        end
        UI.text(tag, h.x + h.w - 8 - fonts.medium:getWidth(tag), hpY + 2, fonts.medium, tagColor, { alpha = blink })
    end

    local barX, barY, barW, barH = h.x + 8, hpY + 20, h.w - 16, 7
    UI.box(barX, barY, barW, barH, { 0, 0, 0, 1 }, { radius = 3, alpha = 0.5 })
    local fill = Anim.clamp(self.shownLife / maxHp, 0, 1)
    if fill > 0 then
        UI.box(barX, barY, math.max(4, barW * fill), barH, C.red, { radius = 3 })
    end
    if preview and state.enemyLife > 0 then
        local after = math.max(0, state.enemyLife - preview.damage)
        local from = Anim.clamp(after / maxHp, 0, 1)
        local to = Anim.clamp(state.enemyLife / maxHp, 0, 1)
        if to > from then
            local ghost = preview.exactKill and C.gold or C.white
            UI.box(barX + barW * from, barY, barW * (to - from), barH, ghost,
                { radius = 2, alpha = 0.35 + 0.5 * blink })
        end
    end

    -- Enemy attack & cumulative Spades shield.
    local atkY = h.y + 74
    local incoming = state:incomingDamage()
    local atkColor = incoming == 0 and C.heal or (state.damageShield > 0 and C.orange or C.red)
    UI.text("ATK " .. incoming, h.x + 8, atkY, fonts.medium, atkColor)
    if state.damageShield > 0 then
        local shieldNote = "(" .. enemy.value .. " -" .. state.damageShield .. ")"
        UI.text(shieldNote, h.x + 62, atkY + 3, fonts.tiny, C.purple, { shadow = false })
    end
    if preview and not preview.killsEnemy and preview.shieldGain > 0 then
        local nextAtk = "-> " .. preview.incomingAfter
        UI.text(nextAtk, h.x + h.w - 8 - fonts.small:getWidth(nextAtk), atkY + 2, fonts.small, C.purple,
            { alpha = blink })
    end
end

function GameView:renderPanel()
    local C, fonts = UI.colors, self.assets.fonts
    local p = self.layout.panel
    local info = self:panelInfo()

    UI.box(p.x, p.y, p.w, p.h, C.panelDark, { radius = 8, alpha = 0.85 })
    local badgeW = math.max(78, fonts.medium:getWidth(info.badge) + 16)
    UI.box(p.x + 8, p.y + 8, badgeW, 22, info.badgeColor or C.grey, { radius = 5, depth = 2 })
    UI.textCentered(info.badge, p.x + 8 + badgeW / 2, p.y + 19, fonts.medium,
        info.badgeColor == C.gold and C.textDark or C.text, { shadow = info.badgeColor ~= C.gold })
    if info.headline then
        local font = fonts.big
        local room = p.w - badgeW - 24
        if font:getWidth(info.headline) > room then
            font = fonts.medium
        end
        UI.textCentered(info.headline, p.x + 16 + badgeW + room / 2, p.y + 19, font, info.headlineColor or C.text)
    end
    UI.text(info.text or "", p.x + 10, p.y + 36, fonts.small, info.textColor or C.text,
        { width = p.w - 20, align = "center" })
end

function GameView:panelInfo()
    local state, C = self.state, UI.colors
    if self.lock > 0 then
        return { badge = state.phase == "defend" and "STRIKE!" or "RESOLVING", badgeColor = C.grey, text = "" }
    end

    local hint, hintColor = self:hoverHint()

    if self.jesterArmed > 0 then
        return {
            badge = "JESTER",
            badgeColor = C.gold,
            headline = "Discard " .. #state.hand .. " -> Draw 8",
            headlineColor = C.gold,
            text = "Click JESTER again (or press J) to discard your hand and draw up to 8 cards.",
        }
    end

    if state.phase == "defend" then
        local incoming = state:incomingDamage()
        local chosen = self:selectedCards()
        local total = GameState.total(chosen)
        if state:handTotal() < incoming then
            return {
                badge = "DANGER",
                badgeColor = C.red,
                headline = state:handTotal() .. " / " .. incoming .. " DMG",
                headlineColor = C.red,
                text = hint or "Your hand can't absorb this blow! Flip a JESTER to draw 8 new cards.",
                textColor = hintColor or C.gold,
            }
        end
        if total >= incoming then
            local extra = total - incoming
            local note = extra > 0
                and ("Absorbs " .. incoming .. " damage (" .. extra .. " over). Press ENTER or click DEFEND.")
                or ("Exact block of " .. incoming .. " damage! Press ENTER or click DEFEND.")
            return {
                badge = "DEFEND",
                badgeColor = C.blue,
                headline = total .. " / " .. incoming .. " DMG",
                headlineColor = C.heal,
                text = hint or note,
                textColor = hintColor,
            }
        end
        return {
            badge = "DEFEND",
            badgeColor = C.red,
            headline = total .. " / " .. incoming .. " DMG",
            headlineColor = C.red,
            text = hint or ("Royal strikes for " .. incoming .. "! Select cards totaling at least " ..
                (incoming - total) .. " more to survive."),
            textColor = hintColor,
        }
    end

    -- Attack phase.
    if #state.hand == 0 then
        return {
            badge = "EMPTY HAND",
            badgeColor = C.purple,
            headline = "Flip a Jester",
            headlineColor = C.gold,
            text = hint or "Your hand is empty: flip a JESTER to draw up to 8 cards from the Tavern.",
            textColor = hintColor or C.gold,
        }
    end

    if self.preview then
        local p = self.preview
        local kindInfo = GameState.PLAY_KINDS[p.kind]
        local badge = p.exactKill and "EXACT!" or (p.killsEnemy and "LETHAL" or kindInfo.name)
        local badgeColor = p.exactKill and C.gold or (p.killsEnemy and C.heal or C[kindInfo.color])
        local text, textColor = self:describeAttack(p)
        return {
            badge = badge,
            badgeColor = badgeColor,
            headline = cardsEquation(p.cards) .. " -> " .. p.damage .. " DMG",
            headlineColor = p.exactKill and C.gold or C.text,
            text = hint or text,
            textColor = hint and hintColor or textColor,
        }
    end

    return {
        badge = "ATTACK",
        badgeColor = C.blue,
        headline = state.currentEnemy and (royalTitle(state.currentEnemy)) or nil,
        headlineColor = C.gold,
        text = hint or "Select a card, an Animal Companion (A) + 1 card, or equal ranks up to 10.",
        textColor = hintColor,
    }
end

function GameView:describeAttack(p)
    local C = UI.colors
    local parts = {}
    if p.healCount > 0 then
        table.insert(parts, "heals " .. p.healCount .. " to Tavern")
    elseif p.activeSuits[Card.SUITS.HEART] then
        table.insert(parts, "discard empty")
    end
    if p.drawCount > 0 then
        table.insert(parts, "draws " .. p.drawCount)
    elseif p.activeSuits[Card.SUITS.DIAMOND] then
        table.insert(parts, "no draw")
    end
    if p.doubleDamage then
        table.insert(parts, "Clubs x2")
    end
    if p.shieldGain > 0 then
        table.insert(parts, "-" .. p.shieldGain .. " enemy ATK")
    end
    if p.immuneTriggered then
        local suitName = Config.SUIT_BY_ID[p.immuneSuit].name
        table.insert(parts, suitName .. " immune!")
    end

    local effects = ""
    if #parts > 0 then
        local joined = table.concat(parts, ", ")
        effects = joined:sub(1, 1):upper() .. joined:sub(2) .. ". "
    end
    if p.exactKill then
        return effects .. "Exact 0 HP: Royal joins the TOP of the Tavern deck!", C.gold
    elseif p.killsEnemy then
        return effects .. "Overthrows the Royal (goes to Discard): no counterattack!", C.heal
    elseif p.incomingAfter == 0 then
        return effects .. "Enemy attack fully shielded (0 damage back).", C.heal
    end
    local remainingHand = self.state:handTotal() - GameState.total(p.cards)
    if p.drawCount == 0 and remainingHand < p.incomingAfter and self.state.availableJokers == 0 then
        return effects .. "Warning: Royal hits back for " .. p.incomingAfter ..
            " and your remaining hand only holds " .. remainingHand .. "!", C.damage
    end
    return effects .. "Royal hits back for " .. p.incomingAfter .. " damage.",
        p.immuneTriggered and C.orange or C.text
end

function GameView:hoverHint()
    local mx, my = self.mouseX, self.mouseY
    if not mx or self.bannerTime > 0 then
        return nil
    end
    local state, C = self.state, UI.colors

    if self.jesterButton.hoovered then
        local blocked = state:jokerBlockedReason()
        if blocked then
            return blocked, C.orange
        end
        return "Solo Jester: discard your whole hand and draw up to 8 cards (does not cancel immunity).", C.purple
    end

    if self.hoveredView and self.hoveredView.zone == "hand" then
        local card = self.hoveredView.card
        if state.phase == "attack" and not self.selected[card.position] and not self.candidates[card.position] then
            local trial = self:selectedCards()
            table.insert(trial, card)
            local _, reason = GameState.classifyAttack(trial)
            return (reason or "Can't combine") .. ". Click to switch to " .. cardLabel(card) .. ".", C.orange
        end
        if state.phase == "defend" then
            return cardLabel(card) .. ": worth " .. card.value .. " when discarded to defend."
        end
    end

    if self.enemyDeck.hoovered then
        local n = #state.enemyDeck.cards
        return n == 0 and "Castle deck is empty: this is the final King!"
            or ("Castle deck: " .. n .. (n == 1 and " Royal waits" or " Royals wait") ..
                " behind the current enemy (Jacks, then Queens, then Kings).")
    end
    if self.tavernDeck.hoovered then
        local n = #state.playerDeck.cards
        return "Tavern deck: " .. n .. (n == 1 and " card" or " cards") ..
            ". Diamonds draw from the top; Hearts heal discards to the bottom; Exact Kills go on top."
    end
    if self:discardHovered(mx, my) then
        local n = #state.discardPile
        return "Discard pile: " .. n .. (n == 1 and " card" or " cards") ..
            ". Playing Hearts (against a non-Heart Royal) shuffles cards from here under the Tavern deck."
    end
    if self:enemyHovered(mx, my) or self:hudHovered(mx, my) then
        local enemy = state.currentEnemy
        if enemy then
            local suit = Config.SUIT_BY_ID[enemy.suit]
            return royalTitle(enemy) .. ": " .. state.enemyLife .. " HP, hits for " .. state:incomingDamage() ..
                " and ignores " .. suit.name .. " (" .. suit.short:lower() .. "). Exact 0 HP puts it on top of Tavern!"
        end
    end

    local box = self.sidebar:boxAt(mx, my)
    if box == "castle" then
        return "Defeat all 12 Royals. Win with 0, 1 or 2 Jesters used for a Gold, Silver or Bronze Victory!"
    elseif box == "powers" then
        return "Suit powers trigger at your total attack value. Hearts resolve before Diamonds; enemy's suit is immune."
    elseif box == "stats" then
        return "Statistics of your current rebellion against the Royal Court."
    end

    return nil
end

return GameView

