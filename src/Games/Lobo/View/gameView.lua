--[[
    Lobo GameView
    The table: the Wolf's hand at the top, yours at the bottom and, in between, the discard pile,
    the deck with the cub face up on top, and a panel naming the capture you have selected.
    - Click cards of both hands to select a capture. Cards that can't join the selection on the way
      to any capture are dimmed. CAPTURE (Enter) plays it; right-click (Backspace) clears the selection.
    - FOLD (click twice) gives the hand to the Wolf. NEXT HAND (Enter) deals the next one.
    - Keeps one CardView per card and reconciles them with the GameState after every event.
]]

local BoardView   = require("src.View.boardView")
local DeckView    = require("src.View.deckView")
local Button      = require("src.View.buttonView")
local Anim        = require("src.View.anim")
local UI          = require("src.View.ui")
local Plays       = require("src.Games.Lobo.Model.plays")
local SidebarView = require("src.Games.Lobo.View.sidebarView")
local Actions     = require("src.Games.Lobo.Controller.actions")

local GameView = BoardView.extend()

local SIDEBAR_WIDTH  = Constants.SIDEBAR_WIDTH
local SAFE_X, SAFE_Y = Constants.SAFE_X, Constants.SAFE_Y

local ROW_GAP       = 12    -- between the cards of a row, when they fit
local LIFT          = 12    -- selected cards move towards the middle of the table
local DEAL_INTERVAL = 0.09
local CLASH_TIME    = 0.3   -- captured cards meet in the middle of the table,
local DISCARD_TIME  = 0.5   -- then go to the discard pile,
local DRAW_DELAY    = 0.65  -- and the cards drawn after the capture start moving.
local DISCARD_SHOWN = 8     -- cards drawn on the discard pile (no capture takes more)
local FOLD_CONFIRM  = 2.5   -- seconds FOLD waits for its confirmation click

local REASONS = {
    captured = "You emptied the Wolf's hand",
    fold     = "You folded",
    stuck    = "No capture left",
}

-- Cards on the discard pile lie slightly askew, always the same way for the same card.
local function discardJitter(card)
    local p = card.position
    return (p * 7 % 5 - 2) * 1.5, (p * 3 % 5 - 2) * 1.2, (p * 13 % 9 - 4) * 0.03
end

local function has(cards, card)
    for _, c in ipairs(cards) do
        if c.position == card.position then
            return true
        end
    end
    return false
end

local function hasAll(cards, subset)
    for _, card in ipairs(subset) do
        if not has(cards, card) then
            return false
        end
    end
    return true
end

local function without(cards, removed)
    local kept = {}
    for _, card in ipairs(cards) do
        if not has(removed, card) then
            table.insert(kept, card)
        end
    end
    return kept
end

-- Set of the cards' positions.
local function positions(cards)
    local set = {}
    for _, card in ipairs(cards) do
        set[card.position] = true
    end
    return set
end

-- "6 + 4": values from highest to lowest.
local function valuesText(cards)
    local values = {}
    for _, card in ipairs(cards) do
        table.insert(values, card.value)
    end
    table.sort(values, function(a, b) return a > b end)
    return table.concat(values, " + ")
end

-- "6 + 4 takes 10", "9 takes 6 + 3"...
local function equation(mine, theirs)
    return (#mine > 0 and valuesText(mine) or "?") .. " takes " .. (#theirs > 0 and valuesText(theirs) or "?")
end

function GameView:new(context, gameState)
    local o = setmetatable({}, self)
    BoardView.init(o, context)
    o.selected    = {}     -- card.position -> true
    o.candidates  = {}     -- card.position -> true: cards that can join the selection
    o.plays       = {}     -- every capture available
    o.play        = nil    -- the capture selected, if the selection is one
    o.lastPlay    = nil    -- the capture being animated
    o.hoveredView = nil
    o.foldArmed   = 0
    o.resultShown = not gameState.handOver

    o:computeLayout()
    local L = o.layout
    o.deck = DeckView:new(o.assets, L.deckX, L.pileY)
    o.deck.showBadge = false
    o.sidebar = SidebarView:new(o.assets, L.sidebar.x, L.sidebar.y, L.sidebar.w, L.sidebar.h)
    o:setState(gameState)
    o.sidebar:setScores(o:scoresBeforeResult())
    o:createButtons()
    o:subscribe()

    local dealDelay = 0.3
    local dealt = o:sync({ dealDelay = dealDelay })
    o.lock = dealDelay + dealt * DEAL_INTERVAL + 0.3
    o:showBanner("HAND " .. gameState.handNumber, UI.colors.gold, L.centerX, L.pileY - 14, dealDelay)
    if gameState.handOver then
        o:after(o.lock, function() o:revealHandResult() end)
    end
    return o
end

function GameView:computeLayout()
    local size = self.assets:getCardSize()
    local W, H = self.assets.WIDTH, self.assets.HEIGHT
    local L = { cardW = size.width, cardH = size.height }

    L.sidebar = { x = SAFE_X, y = SAFE_Y, w = SIDEBAR_WIDTH, h = H - 2 * SAFE_Y }
    L.areaX = L.sidebar.x + L.sidebar.w + 10
    L.areaW = math.floor(W - SAFE_X - L.areaX)
    L.centerX = L.areaX + L.areaW / 2

    -- Card centers sit on half pixels (odd card size) so card edges land on whole pixels.
    L.wolfLabelY = SAFE_Y + 1
    L.wolfY = SAFE_Y + 16 + size.height / 2
    L.playerY = H - SAFE_Y - 18 - size.height / 2
    L.playerLabelY = L.playerY + size.height / 2 + 5
    L.pileY = math.floor((L.wolfY + L.playerY) / 2) + 0.5
    L.discardX = L.areaX + size.width / 2 + 4
    L.deckX = L.areaX + L.areaW - size.width / 2 - 4

    local panelX = math.floor(L.discardX + size.width / 2 + 14)
    local panelRight = math.floor(L.deckX - size.width / 2 - 14)
    L.panel = { x = panelX, y = math.floor(L.pileY - 48), w = panelRight - panelX, h = 66 }
    L.buttonsY = L.panel.y + L.panel.h + 8

    self.layout = L
end

function GameView:createButtons()
    local L, C = self.layout, UI.colors
    local function button(params)
        return Button:new(params, self.assets, self.mouseProvider)
    end

    local captureW, foldW, gap = 124, 84, 10
    local left = math.floor(L.centerX - (captureW + gap + foldW) / 2)
    self.captureButton = button({
        x = left, y = L.buttonsY, width = captureW, height = 26,
        text = "CAPTURE", color = C.blue, hotkey = "ENTER",
        onClick = function() self:capture() end,
    })
    self.foldButton = button({
        x = left + captureW + gap, y = L.buttonsY, width = foldW, height = 26,
        text = "FOLD", color = C.red,
        onClick = function() self:fold() end,
    })
    self.nextButton = button({
        x = math.floor(L.centerX - 70), y = L.buttonsY, width = 140, height = 26,
        text = "NEXT HAND", color = C.blue, hotkey = "ENTER",
        onClick = function() self:nextHand() end,
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

    self.buttons = { self.captureButton, self.foldButton, self.nextButton, self.rulesButton, self.menuButton }
end

function GameView:subscribe()
    self:on("captured", function(gameState, outcome) self:onCaptured(gameState, outcome) end)
    self:on("folded", function(gameState) self:onFolded(gameState) end)
    self:on("handDealt", function(gameState, outcome) self:onHandDealt(gameState, outcome) end)
    self:on("endGame", function(didWin, gameState) self:onEndGame(didWin, gameState) end)
end

function GameView:setState(gameState)
    self.state = gameState
    self.plays = gameState.handOver and {} or gameState:plays()
    self.selected = {}
    self.foldArmed = 0
    self:refreshSelection()
end

-- Scores and ledger length before the result of the current hand, which shows after its animation.
function GameView:scoresBeforeResult()
    local state = self.state
    local scores = { player = state.scores.player, wolf = state.scores.wolf }
    local count = #state.ledger
    if state.handOver and not self.resultShown then
        local result = state.handResult
        scores[result.winner] = scores[result.winner] - result.points
        count = count - 1
    end
    return scores, count
end

------------------------------------------------------------------------
-- Selection
------------------------------------------------------------------------

-- The selected cards of your hand and of the Wolf's, in table order.
function GameView:selection()
    local mine, theirs = {}, {}
    for _, card in ipairs(self.state.hand) do
        if self.selected[card.position] then
            table.insert(mine, card)
        end
    end
    for _, card in ipairs(self.state.wolf) do
        if self.selected[card.position] then
            table.insert(theirs, card)
        end
    end
    return mine, theirs
end

-- Works out the capture selected and which cards can still join the selection.
function GameView:refreshSelection()
    local mine, theirs = self:selection()
    self.play, self.playReason = Plays.classify(mine, theirs)
    self.candidates = {}
    for _, play in ipairs(self.plays) do
        if hasAll(play.mine, mine) and hasAll(play.theirs, theirs) then
            for _, card in ipairs(play.mine) do
                self.candidates[card.position] = true
            end
            for _, card in ipairs(play.theirs) do
                self.candidates[card.position] = true
            end
        end
    end
end

function GameView:toggle(view)
    local key = view.card.position
    self.selected[key] = not self.selected[key] or nil
    view:juiceUp(0.12, 0.03)
    self.assets.audio:play("deal", { volume = 0.6, pitch = self.selected[key] and 1.15 or 0.9, variation = 0.05 })
    self.foldArmed = 0
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

--[[
    What a capture leads to when every card it draws is known (the cub): "win" with your points when
    it takes the Wolf's last card, or "stuck" with the Wolf's points when you'd have no capture left.
    nil when the hand would go on, or depends on cards still hidden.
]]
function GameView:predict(play)
    if play.wolfDraws > 1 then
        return nil
    end
    local state = self.state
    local hand, wolf = without(state.hand, play.mine), without(state.wolf, play.theirs)
    local cub = state:cub()
    if cub then
        table.insert(play.playerDraws > 0 and hand or wolf, cub)
    end
    if #wolf == 0 then
        return "win", Plays.total(hand)
    end
    if not Plays.any(hand, wolf) then
        return "stuck", Plays.total(wolf)
    end
    return nil
end

------------------------------------------------------------------------
-- Reconciliation: model -> card views
------------------------------------------------------------------------

-- Center of card `index` of a row of `count` cards. Rows squeeze when the cards don't fit.
function GameView:rowX(index, count)
    local L = self.layout
    local spacing = L.cardW + ROW_GAP
    if count > 1 then
        spacing = math.min(spacing, math.floor((L.areaW - L.cardW) / (count - 1)))
    end
    local width = spacing * (count - 1) + L.cardW
    return math.floor(L.centerX - width / 2) + L.cardW / 2 + (index - 1) * spacing
end

--[[
    Moves every card view to where the model says the card is: the rows, the cub on the deck, the top
    of the discard pile. Cards shuffled back go into the deck; cards buried in the discard pile hide.
    opts.drawn:        card.position -> true for the cards just drawn from the deck
    opts.dealDelay:    delay before the cards drawn from the deck start moving (one after another)
    opts.shuffleDelay: delay before cards go back into the deck
    Returns how many cards were drawn from the deck.
]]
function GameView:sync(opts)
    opts = opts or {}
    local L, state = self.layout, self.state
    local present = {}
    local drawnCards = opts.drawn or {}
    local drawn = 0
    local dealDelay = opts.dealDelay or 0
    local deckX, deckY = self.deck:topPosition()

    local function fromDeck(view)
        return view == nil or view.zone == "deck" or view.zone == "gone" or
            (view.zone == "exiting" and view.exitKind == "deck")
    end
    local function place(card, zone, x, y)
        local previous = self.views[card.position]
        local wasCub = previous ~= nil and previous.zone == "cub"
        local wasInDeck = not wasCub and (drawnCards[card.position] or fromDeck(previous))
        local view = self:placeCard(card, zone, x, y, 0, present)
        if wasInDeck then
            view:snapTo(deckX, deckY, 0)
            view:setTarget(x, y, 0)
            view.flip = -1
            view.faceUp = true
        end
        if wasInDeck or wasCub then
            view.delay = dealDelay + drawn * DEAL_INTERVAL
            self:after(view.delay, function() self.assets.audio:play("deal", { variation = 0.15 }) end)
            drawn = drawn + 1
        end
        return view
    end

    -- One card of each row in turn: the order a new hand is dealt in.
    local wolfCount, handCount = #state.wolf, #state.hand
    for i = 1, math.max(wolfCount, handCount) do
        local card = state.wolf[i]
        if card then
            local lift = self.selected[card.position] and LIFT or 0
            place(card, "wolf", self:rowX(i, wolfCount), L.wolfY + lift).slot = i
        end
        card = state.hand[i]
        if card then
            local lift = self.selected[card.position] and -LIFT or 0
            place(card, "hand", self:rowX(i, handCount), L.playerY + lift).slot = i
        end
    end

    self.deck:setCount(#state.deck.cards)
    deckX, deckY = self.deck:topPosition()

    -- The cub turns face up on the deck once the cards drawn before it have left.
    local cub = state:cub()
    if cub then
        local previous = self.views[cub.position]
        local wasInDeck, wasCub = fromDeck(previous), previous ~= nil and previous.zone == "cub"
        local view = self:placeCard(cub, "cub", deckX, deckY, 0, present)
        if not wasCub then
            local reveal = dealDelay + drawn * DEAL_INTERVAL + 0.1
            if wasInDeck then
                view:snapTo(deckX, deckY, 0)
                view.flip = -1
                view.faceUp = true
                view.delay = reveal
            else
                -- Back from the discard pile (reshuffled): face down into the deck, then turned over.
                view.faceUp = false
                self:after(reveal + (opts.shuffleDelay or 0), function()
                    if view.zone == "cub" then
                        view.faceUp = true
                    end
                end)
            end
        end
    end

    local pile = state.discardPile
    for i = math.max(1, #pile - DISCARD_SHOWN + 1), #pile do
        local dx, dy, r = discardJitter(pile[i])
        local view = self:placeCard(pile[i], "discard", L.discardX + dx, L.pileY + dy, r, present)
        view.pileIndex = i
        view.slot = nil
    end

    local inDeck = {}
    for _, card in ipairs(state.deck.cards) do
        inDeck[card.position] = true
    end
    for key, view in pairs(self.views) do
        if not present[key] then
            if inDeck[key] and view.zone == "gone" then
                view.zone = "deck"
            elseif inDeck[key] and view.zone ~= "deck" and not (view.zone == "exiting" and view.exitKind == "deck") then
                self:sendToDeck(view, opts.shuffleDelay)
            elseif not inDeck[key] and view.zone ~= "gone" then
                view.zone = "gone"
            end
        end
    end
    return drawn
end

function GameView:sendToDeck(view, delay)
    local x, y = self.deck:topPosition()
    view.zone = "exiting"
    view.exitKind = "deck"
    view.faceUp = false
    view.hovered = false
    view.slot = nil
    view.delay = delay or 0
    view:setTarget(x, y, 0)
end

function GameView:updateExit(view)
    if view.zone == "exiting" and view.exitKind == "deck" and view.delay <= 0 and view:distanceToTarget() < 3 then
        view.zone = "deck"
    end
end

------------------------------------------------------------------------
-- Model events
------------------------------------------------------------------------

function GameView:onCaptured(gameState, outcome)
    local L, C = self.layout, UI.colors
    local kind = Plays.KINDS[outcome.kind]
    local color = C[kind.color]
    self.lastPlay = outcome.play
    self:setState(gameState)
    if outcome.handResult then
        self.resultShown = false
    end

    local dealt = self:sync({ dealDelay = DRAW_DELAY, shuffleDelay = DISCARD_TIME, drawn = positions(outcome.drawn) })

    -- sync sent the captured cards to the discard pile: they meet in the middle of the table first.
    -- (When the pile was just shuffled into a new deck, they go straight there instead.)
    local clashX, clashY = L.centerX, L.pileY - 8
    local captured = {}
    for _, card in ipairs(outcome.mine) do
        table.insert(captured, { view = self.views[card.position], side = 1 })
    end
    for _, card in ipairs(outcome.theirs) do
        table.insert(captured, { view = self.views[card.position], side = -1 })
    end
    for i, entry in ipairs(captured) do
        local view = entry.view
        if view.zone == "discard" then
            local pileX, pileY, pileR = view.T.x, view.T.y, view.T.r
            local spread = (i - (#captured + 1) / 2) * 14
            view:setTarget(clashX + spread, clashY + entry.side * 10, (love.math.random() - 0.5) * 0.3)
            view:juiceUp(0.15)
            self:after(DISCARD_TIME + i * 0.03, function()
                if view.zone == "discard" then
                    view:setTarget(pileX, pileY, pileR)
                end
            end)
        end
    end
    self:after(CLASH_TIME, function()
        self.assets.audio:play("capture")
        self.effects:burst(clashX, clashY, color, 18, { speed = 120, spread = 20 })
        self.effects:floatText(kind.name .. "!", clashX, clashY - 34, color, { font = self.assets.fonts.big })
        self:shake(2)
        for _, entry in ipairs(captured) do
            entry.view:flashWhite(0.6)
        end
    end)

    local count = #outcome.drawn
    if outcome.drawnBy == "wolf" and count > 0 then
        local last = self.views[outcome.drawn[count].position]
        self:after(DRAW_DELAY + count * DEAL_INTERVAL, function()
            self.effects:floatText("+" .. count, last.T.x, last.T.y + 24, C.damage,
                { font = self.assets.fonts.big, duration = 1.0, rise = 10 })
        end)
        if count >= 2 then
            self:after(DRAW_DELAY, function()
                self.assets.audio:play("howl")
                self:flashScreen(C.damage, math.min(0.5, 0.12 + count * 0.05))
                self:shake(2 + count)
            end)
        end
    elseif outcome.drawnBy == "player" and count > 0 then
        local view = self.views[outcome.drawn[1].position]
        self:after(DRAW_DELAY + 0.3, function()
            self.effects:burst(view.T.x, view.T.y - 30, C.gold, 8, { speed = 60 })
        end)
    end
    if outcome.reshuffled then
        self:after(DISCARD_TIME, function()
            self.assets.audio:play("shuffle")
            self:showBanner("RESHUFFLED", C.blue, L.deckX, L.pileY - 62)
        end)
    end

    self.lock = math.max(DISCARD_TIME + 0.35, DRAW_DELAY + dealt * DEAL_INTERVAL + 0.45)
    if outcome.handResult then
        self:after(self.lock, function() self:revealHandResult() end)
    end
end

function GameView:onFolded(gameState)
    self.lastPlay = nil
    self:setState(gameState)
    self.resultShown = false
    self:sync()
    for i, card in ipairs(gameState.wolf) do
        local view = self.views[card.position]
        self:after(i * 0.06, function() view:juiceUp(0.2, 0.05) end)
    end
    self.lock = 0.4
    self:after(0.2, function() self:revealHandResult() end)
end

function GameView:onHandDealt(gameState, outcome)
    local L, C = self.layout, UI.colors
    self.lastPlay = nil
    self:setState(gameState)
    self.resultShown = not gameState.handOver

    -- The cards left on the table go to the discard pile...
    for i, card in ipairs(outcome.returned) do
        local view = self.views[card.position]
        if view then
            local dx, dy, r = discardJitter(card)
            view.zone = "discard"
            view.slot = nil
            view.pileIndex = 1000 + i
            view.hovered = false
            view:setTarget(L.discardX + dx, L.pileY + dy, r)
        end
    end

    local start, dealDelay = 0, 0.4
    if outcome.shuffled then
        -- ...then the whole pile and the cub are shuffled back into the deck.
        start, dealDelay = 0.45, 0.55
        self:after(start, function()
            self.assets.audio:play("shuffle")
            self:showBanner("SHUFFLE", C.blue, L.deckX, L.pileY - 62)
        end)
    end
    local function deal()
        local drawn = positions(gameState.wolf)
        for key in pairs(positions(gameState.hand)) do
            drawn[key] = true
        end
        local dealt = self:sync({ dealDelay = dealDelay, drawn = drawn })
        self:after(dealDelay, function() self.assets.audio:play("room") end)
        self:showBanner("HAND " .. gameState.handNumber, C.gold, L.centerX, L.pileY - 14, dealDelay)
        return dealt
    end
    local dealt
    if start > 0 then
        dealt = 2 * #gameState.hand
        self:after(start, deal)
    else
        dealt = deal()
    end

    self.lock = start + dealDelay + dealt * DEAL_INTERVAL + 0.35
    if gameState.handOver then
        self:after(self.lock, function() self:revealHandResult() end)
    end
end

function GameView:revealHandResult()
    local state = self.state
    local result = state.handResult
    if not result or self.resultShown then
        return
    end
    self.resultShown = true
    self.lastPlay = nil
    self.sidebar:setScores(state.scores, #state.ledger)

    local L, C = self.layout, UI.colors
    if result.winner == "player" then
        self.assets.audio:play("heal")
        self:showBanner("HAND WON! +" .. result.points, C.gold, L.centerX, L.pileY - 14)
        self:flashScreen(C.heal, 0.3)
        for i, card in ipairs(state.hand) do
            local view = self.views[card.position]
            self:after(i * 0.07, function()
                view:juiceUp(0.25)
                self.effects:burst(view.T.x, view.T.y, C.gold, 10, { speed = 90, up = 70 })
            end)
        end
    else
        self.assets.audio:play("howl")
        self:showBanner("WOLF SCORES +" .. result.points, C.red, L.centerX, L.pileY - 14)
        self:flashScreen(C.damage, 0.35)
        self:shake(4)
        for i, card in ipairs(state.wolf) do
            local view = self.views[card.position]
            self:after(i * 0.05, function()
                view:juiceUp(0.2, 0.05)
                view:flashWhite(0.5)
            end)
        end
    end
end

function GameView:onEndGame(didWin, gameState)
    self.over = true
    self.foldArmed = 0
    local L, C = self.layout, UI.colors
    local delay = self.lock + 1.4
    self:after(delay, function()
        if didWin then
            self.assets.audio:play("victory")
            self.effects:floatText("YOU BEAT THE WOLF!", L.centerX, L.pileY - 10, C.gold,
                { font = self.assets.fonts.large, duration = 1.7, rise = 18 })
            for i = 1, 5 do
                self:after(i * 0.12, function()
                    local x = L.areaX + love.math.random() * L.areaW
                    self.effects:burst(x, L.playerY, i % 2 == 0 and C.gold or C.heal, 16, { speed = 140, up = 80 })
                end)
            end
        else
            self.assets.audio:play("defeat")
            self:shake(8)
            self:flashScreen(C.damage, 0.6)
            self.effects:floatText("THE WOLF WINS", L.centerX, L.pileY - 10, C.red,
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

function GameView:capture()
    if self:isBusy() or self.state.handOver then
        return
    end
    if not self.play then
        self.captureButton.juice = Anim.newJuice(0.03, 0.06, 0.25)
        self.assets.audio:play("denied")
        return
    end
    self.eventBus:publish("action", Actions.CaptureAction:new(self.play.mine, self.play.theirs))
end

-- The first click arms the button, the second one folds.
function GameView:fold()
    if self:isBusy() or self.state.handOver then
        return
    end
    if self.foldArmed <= 0 then
        self.foldArmed = FOLD_CONFIRM
        self.foldButton.juice = Anim.newJuice(0.1, 0.04, 0.35)
        return
    end
    self.foldArmed = 0
    self.eventBus:publish("action", Actions.FoldAction:new())
end

function GameView:nextHand()
    if self:isBusy() or not self.state.handOver or not self.resultShown then
        return
    end
    self.eventBus:publish("action", Actions.NextHandAction:new())
end

function GameView:openMenu()
    if not self.over then
        self.eventBus:publish("navigate", "pause")
    end
end

-- Topmost card of either hand under the mouse.
function GameView:cardAt(x, y)
    for _, pile in ipairs({ self.state.hand, self.state.wolf }) do
        for i = #pile, 1, -1 do
            local view = self.views[pile[i].position]
            if view and (view.zone == "hand" or view.zone == "wolf") and view:contains(x, y) then
                return view
            end
        end
    end
    return nil
end

function GameView:discardHovered(x, y)
    local L = self.layout
    return math.abs(x - L.discardX) <= L.cardW / 2 and math.abs(y - L.pileY) <= L.cardH / 2
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
    self.foldArmed = 0
    if self:isBusy() or self.state.handOver then
        return
    end
    if button == 2 then
        self:clearSelection()
        return
    end
    local view = self:cardAt(mouseX, mouseY)
    if view then
        self:toggle(view)
    end
end

function GameView:onKeyPressed(key)
    if self.over then
        return
    end
    if key == "escape" then
        self:openMenu()
    elseif key == "return" or key == "space" then
        if self.state.handOver then
            self:nextHand()
        else
            self:capture()
        end
    elseif key == "backspace" or key == "delete" then
        self:clearSelection()
    end
end

------------------------------------------------------------------------
-- Update
------------------------------------------------------------------------

function GameView:update(dt, hasFocus)
    self:updateClock(dt, hasFocus)
    if hasFocus then
        self.foldArmed = math.max(0, self.foldArmed - dt)
    end

    local mouseX, mouseY = self.mouseProvider()
    if not hasFocus then
        mouseX, mouseY = -1000, -1000
    end
    self:updateHover(mouseX, mouseY)
    self.mouseX, self.mouseY = mouseX, mouseY

    -- During a hand, cards that can't take part in a capture with the selection are dimmed.
    local playing = not self.state.handOver and not self.over
    for key, view in pairs(self.views) do
        if view.zone ~= "gone" and view.zone ~= "deck" then
            local inHand = view.zone == "hand" or view.zone == "wolf"
            local dim = playing and inHand and not self.candidates[key]
            view.tint = Anim.approach(view.tint, dim and 0.55 or 1, 8, dt)
            view:update(dt, mouseX, mouseY)
            self:updateExit(view)
        end
    end

    self.deck:update(dt, mouseX, mouseY)
    self.sidebar:update(dt)
    for _, b in ipairs(self.buttons) do
        b:update(dt, hasFocus)
    end
    local busy = self:isBusy()
    local handOver = self.state.handOver
    self.captureButton.visible = not handOver
    self.captureButton.disabled = busy or not self.play
    self.foldButton.visible = not handOver
    self.foldButton.disabled = busy
    self.foldButton.text = self.foldArmed > 0 and "SURE?" or "FOLD"
    self.nextButton.visible = handOver and self.resultShown and not self.over
    self.nextButton.disabled = busy

    self:updateFeedback(dt)
end

function GameView:updateHover(mouseX, mouseY)
    local hovered = nil
    if not self:isBusy() and not self.state.handOver then
        hovered = self:cardAt(mouseX, mouseY)
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
    self:renderPanel()

    -- Cards going back into the deck slide under the pile; everything else is drawn above it.
    for _, view in ipairs(self:drawList(true)) do
        view:draw()
    end
    self.deck:render()
    for _, view in ipairs(self:drawList(false)) do
        if self.selected[view.card.position] and (view.zone == "hand" or view.zone == "wolf") then
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
    if view.zone == "cub" then
        return 1
    end
    if view.hovered then
        return 2.6
    end
    return 2 + (self.selected[view.card.position] and 0.3 or 0) + (view.slot or 0) * 0.001
end

function GameView:drawList(deckBound)
    local list = {}
    for _, view in pairs(self.views) do
        local isDeckBound = view.zone == "exiting" and view.exitKind == "deck"
        if view.zone ~= "gone" and view.zone ~= "deck" and isDeckBound == deckBound then
            view.layer = self:layerOf(view)
            table.insert(list, view)
        end
    end
    return BoardView.sortByLayer(list)
end

-- Glow behind a selected card, in the colour of the capture once the selection is one.
function GameView:renderHalo(view)
    local color = self.play and UI.colors[Plays.KINDS[self.play.kind].color] or UI.colors.white
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

-- Row labels with the points each hand holds, and the empty discard slot.
function GameView:renderTable()
    local L, C, fonts = self.layout, UI.colors, self.assets.fonts
    local state = self.state
    local right = L.areaX + L.areaW

    local function label(text, color, info, y)
        UI.text(text, L.areaX, y, fonts.small, color)
        UI.text(info, right - fonts.small:getWidth(info), y, fonts.small, C.text)
    end
    local function count(n)
        return n .. (n == 1 and " CARD   " or " CARDS   ")
    end
    label("THE WOLF", C.red, count(#state.wolf) .. state:wolfTotal() .. " PTS", L.wolfLabelY)
    label("YOUR HAND", C.gold, count(#state.hand) .. state:handTotal() .. " PTS", L.playerLabelY)

    UI.box(L.discardX - L.cardW / 2, L.pileY - L.cardH / 2, L.cardW, L.cardH, C.panelDark, { radius = 6, alpha = 0.3 })
    if #state.discardPile == 0 then
        UI.textCentered("DISCARD", L.discardX, L.pileY, fonts.small, C.textDim, { alpha = 0.7 })
    end
end

function GameView:renderPileLabels()
    local L, C, fonts = self.layout, UI.colors, self.assets.fonts
    local y = L.pileY + L.cardH / 2 + 7
    local deckCount = #self.state.deck.cards
    UI.textCentered("DECK " .. deckCount, L.deckX, y, fonts.tiny, C.textDim, { shadow = false })
    UI.textCentered("DISCARD " .. #self.state.discardPile, L.discardX, y, fonts.tiny, C.textDim, { shadow = false })
    if deckCount > 0 then
        local x, top = self.deck:topPosition()
        UI.textCentered("THE CUB", x, top - L.cardH / 2 - 6, fonts.tiny, C.gold, { shadow = false })
    end
end

-- The panel between the piles names the selected capture, explains it, or shows the hand's result.
function GameView:renderPanel()
    local C, fonts = UI.colors, self.assets.fonts
    local p = self.layout.panel
    local info = self:panelInfo()

    UI.box(p.x, p.y, p.w, p.h, C.panelDark, { radius = 8, alpha = 0.8 })
    local badgeW = math.max(78, fonts.medium:getWidth(info.badge) + 16)
    UI.box(p.x + 8, p.y + 8, badgeW, 22, info.badgeColor or C.grey, { radius = 5, depth = 2 })
    UI.textCentered(info.badge, p.x + 8 + badgeW / 2, p.y + 19, fonts.medium, C.text)
    if info.headline then
        local font = fonts.big
        local room = p.w - badgeW - 24
        if font:getWidth(info.headline) > room then
            font = fonts.medium
        end
        UI.textCentered(info.headline, p.x + 16 + badgeW + room / 2, p.y + 19, font, info.headlineColor or C.text)
    end
    UI.text(info.text or "", p.x + 10, p.y + 37, fonts.small, info.textColor or C.text,
        { width = p.w - 20, align = "center" })
end

function GameView:panelInfo()
    local state, C = self.state, UI.colors
    local hint, hintColor = self:hoverHint()

    if state.handOver and self.resultShown then
        local result = state.handResult
        local reason = REASONS[result.reason]
        if result.winner == "player" then
            return { badge = "HAND WON", badgeColor = C.gold, headline = "+" .. result.points, headlineColor = C.gold,
                text = hint or (reason .. ": you score the " .. result.points .. " points left in your hand."),
                textColor = hintColor }
        end
        return { badge = "WOLF SCORES", badgeColor = C.red, headline = "+" .. result.points, headlineColor = C.red,
            text = hint or (reason .. ": the Wolf scores the " .. result.points .. " points in its hand."),
            textColor = hintColor }
    end
    if self.lock > 0 or state.handOver then
        local play = self.lastPlay
        if play then
            local kind = Plays.KINDS[play.kind]
            local outcome = state.lastOutcome or {}
            local drawn = outcome.drawn or {}
            local text = ""
            if #drawn > 0 then
                local who = outcome.drawnBy == "wolf" and "The Wolf takes " or "You take "
                text = who .. (#drawn == 1 and "a card." or (#drawn .. " cards."))
            end
            return { badge = kind.name, badgeColor = C[kind.color], headline = equation(play.mine, play.theirs),
                text = text, textColor = outcome.drawnBy == "wolf" and C.damage or nil }
        end
        if state.handOver and state.handResult.reason == "fold" then
            return { badge = "FOLDED", badgeColor = C.red, text = "" }
        end
        return { badge = "DEALING", badgeColor = C.grey, text = "" }
    end

    if self.play then
        local kind = Plays.KINDS[self.play.kind]
        local text, color = self:describePlay(self.play)
        return { badge = kind.name, badgeColor = C[kind.color], headline = equation(self.play.mine, self.play.theirs),
            text = hint or text, textColor = hint and hintColor or color }
    end

    local mine, theirs = self:selection()
    local text, color = self:guidance(mine, theirs)
    return { badge = "SELECT", badgeColor = C.grey,
        headline = (#mine > 0 or #theirs > 0) and equation(mine, theirs) or nil, headlineColor = C.textDim,
        text = hint or text, textColor = hint and hintColor or color }
end

-- What the selected capture does.
function GameView:describePlay(play)
    local C = UI.colors
    local cub = self.state:cub()
    local cubText = cub and ("the cub (" .. cub.value .. ")") or "nothing: the deck is empty"
    local result, points = self:predict(play)
    if result == "win" then
        return "The Wolf's last card! You win the hand with " .. points .. " points.", C.gold
    end

    local text
    local discarded = (#play.mine + #play.theirs == 2) and "Both discarded" or "All discarded"
    if play.kind == "perfect" or play.kind == "sum" then
        text = discarded .. ", then you take " .. cubText .. "."
    elseif play.wolfDraws == 1 then
        text = discarded .. ", then the Wolf takes " .. cubText .. "."
    else
        text = discarded .. ", then the Wolf takes " .. play.wolfDraws .. " cards: " .. cubText ..
            " and " .. (play.wolfDraws - 1) .. " unknown."
    end
    if result == "stuck" then
        return text .. " You'd have no capture left: the Wolf scores " .. points .. ".", C.damage
    end
    return text, play.wolfDraws > 1 and C.orange or nil
end

-- What to select next, given a selection that isn't a capture (yet).
function GameView:guidance(mine, theirs)
    local C = UI.colors
    if #mine == 0 and #theirs == 0 then
        return "Select cards from your hand and from the Wolf's to make a capture."
    end
    if next(self.candidates) == nil then
        return "No capture uses these cards together. Right-click to clear the selection.", C.damage
    end
    if #theirs == 0 then
        local total = Plays.total(mine)
        if #mine == 1 then
            return "Now pick from the Wolf: a " .. total .. " (Perfect), cards adding up to " .. total ..
                " (Split) or a smaller card (Over)."
        end
        return "Your cards add up to " .. total .. ": pick the Wolf's " .. total .. " (Sum)."
    end
    if #mine == 0 then
        local total = Plays.total(theirs)
        if #theirs == 1 then
            return "Now pick from your hand: a " .. total .. " (Perfect), cards adding up to " .. total ..
                " (Sum) or a bigger card (Over)."
        end
        return "The Wolf's cards add up to " .. total .. ": pick your " .. total .. " (Split)."
    end
    if #mine > 1 then
        return "Your cards add up to " .. Plays.total(mine) .. ", the Wolf's card is " .. Plays.total(theirs) ..
            ": add or remove cards to match."
    end
    return "The Wolf's cards add up to " .. Plays.total(theirs) .. ", your card is " .. Plays.total(mine) ..
        ": add or remove cards to match."
end

-- Explanation of the button, pile or panel under the mouse, if any.
function GameView:hoverHint()
    local state, C = self.state, UI.colors
    local x, y = self.mouseX or -1000, self.mouseY or -1000
    if self.foldButton.visible and self.foldButton.hoovered then
        if self.foldArmed > 0 then
            return "Click again to fold: the Wolf scores the " .. state:wolfTotal() .. " points in its hand.", C.damage
        end
        return "Fold: stop fighting and the Wolf scores the " .. state:wolfTotal() .. " points in its hand. Click twice."
    end
    if self.captureButton.visible and self.captureButton.hoovered and not self.play then
        return "Select a capture first: cards of your hand against cards of the Wolf's.", C.textDim
    end
    if self.nextButton.visible and self.nextButton.hoovered then
        local shuffle = state:handsBeforeShuffle() == 0 or #state.deck.cards < 9
        return "Clear the table and deal hand " .. (state.handNumber + 1) ..
            (shuffle and " from a freshly shuffled deck." or " from what is left of the deck.")
    end
    if self.deck.hoovered then
        local cub = state:cub()
        if not cub then
            return "The deck is empty."
        end
        local hidden = #state.deck.cards - 1
        return "The cub (" .. cub.value .. ") is the next card drawn. Below it, " .. hidden ..
            (hidden == 1 and " hidden card." or " hidden cards.")
    end
    if self:discardHovered(x, y) then
        return "The discard pile: " .. #state.discardPile .. " cards. If the deck runs out, they become a new deck."
    end
    local box = self.sidebar:boxAt(x, y)
    if box == "tracker" then
        return "Cards of each value still hidden below the cub. The deck is only shuffled every 3 hands."
    elseif box == "ledger" then
        return "One line per hand: who scored, how the hand ended, and the points."
    elseif box == "match" then
        return "You and the Wolf race to " .. state.target .. " points. Only the winner of a hand scores."
    end
    return nil
end

return GameView
