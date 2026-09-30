--[[
    GameView
    Main gameplay screen.
    - Keeps one CardView per card and reconciles them with the GameState after every event
      (room slots, weapon, slain stack, deck), so every change - undo included - is animated.
    - Hovering a room card shows action tabs with the exact outcome and explains it in the
      hint line. Clicking the card performs its main action; clicking a tab performs that one.
    - Once a single card is left the next room is dealt automatically.
]]

local CardView    = require("src.View.cardView")
local DeckView    = require("src.View.deckView")
local SidebarView = require("src.View.sidebarView")
local Button      = require("src.View.buttonView")
local Effects     = require("src.View.effects")
local Anim        = require("src.View.anim")
local UI          = require("src.View.ui")
local Actions     = require("src.Controller.playerAction")
local Timer       = require("lib.timer")

local GameView = {}
GameView.__index = GameView

local CARDS_PER_ROOM = Constants.CARDS_PER_ROOM
local ROOM_SPACING   = Constants.ROOM_SPACING
local STACK_SPACING  = Constants.STACK_SPACING
local SIDEBAR_WIDTH  = Constants.SIDEBAR_WIDTH
local SAFE_X, SAFE_Y = Constants.SAFE_X, Constants.SAFE_Y

local TAB_HEIGHT, TAB_GAP = 18, 3
local DEAL_INTERVAL       = 0.09
local AUTO_ADVANCE_DELAY  = 0.75

local FLEE_BLOCKED_HINTS = {
    deckEmpty   = "The dungeon is empty: there is nowhere left to flee.",
    roomStarted = "You can only flee before resolving any card of the room.",
    fledLast    = "You fled the last room. You can't flee twice in a row.",
}

-- Screen-edge glow used for damage/heal flashes.
local function newVignetteMesh(width, height, inset)
    local outer, inner = { 1, 1, 1, 1 }, { 1, 1, 1, 0 }
    local function vertex(x, y, color)
        return { x, y, 0, 0, color[1], color[2], color[3], color[4] }
    end
    local mesh = love.graphics.newMesh({
        vertex(0, 0, outer), vertex(width, 0, outer), vertex(width, height, outer), vertex(0, height, outer),
        vertex(inset, inset, inner), vertex(width - inset, inset, inner),
        vertex(width - inset, height - inset, inner), vertex(inset, height - inset, inner),
    }, "triangles", "static")
    mesh:setVertexMap(1, 2, 6, 1, 6, 5, 2, 3, 7, 2, 7, 6, 3, 4, 8, 3, 8, 7, 4, 1, 5, 4, 5, 8)
    return mesh
end

function GameView:new(context, gameState)
    local o = setmetatable({}, self)
    o.assets        = context.assets
    o.eventBus      = context.eventBus
    o.settings      = context.settings
    o.mouseProvider = context.mouseProvider
    o.state         = gameState
    o.views         = {}  -- card.position -> CardView (kept for the whole run so undo can revive cards)
    o.slots         = {}  -- room slot index -> card.position
    o.viewCount     = 0
    o.timers        = {}
    o.subscriptions = {}
    o.effects       = Effects:new(o.assets)
    o.lock          = 0
    o.bannerTime    = 0
    o.advanceToken  = nil  -- pending automatic next room
    o.playToken     = nil  -- delayed feedback of the last card played
    o.focusKey      = nil
    o.hoverTab      = nil
    o.tabReveal     = 0
    o.shakeAmount   = 0
    o.vignette      = 0
    o.vignetteColor = UI.colors.damage
    o.runTime       = 0
    o.over          = false

    o:computeLayout()
    local L = o.layout
    o.deck = DeckView:new(o.assets, L.deckX, L.roomY)
    o.deck:setCount(#gameState.drawPile.cards)
    o.sidebar = SidebarView:new(o.assets, L.sidebar.x, L.sidebar.y, L.sidebar.w, L.sidebar.h, gameState.player.lifes)
    o.vignetteMesh = newVignetteMesh(o.assets.WIDTH, o.assets.HEIGHT, 70)
    o:createButtons()
    o:subscribe()

    local dealDelay = 0.3
    local dealt = o:sync({ dealDelay = dealDelay })
    o.lock = dealDelay + dealt * DEAL_INTERVAL + 0.2
    return o
end

function GameView:computeLayout()
    local size = self.assets:getCardSize()
    local W, H = self.assets.WIDTH, self.assets.HEIGHT
    local L = { cardW = size.width, cardH = size.height }

    L.sidebar = { x = SAFE_X, y = SAFE_Y, w = SIDEBAR_WIDTH, h = H - 2 * SAFE_Y }

    local areaX = L.sidebar.x + L.sidebar.w + 10
    local areaW = W - SAFE_X - areaX
    local spacing = size.width + ROOM_SPACING
    local roomW = spacing * (CARDS_PER_ROOM - 1) + size.width
    local deckGap = 28
    local left = math.floor(areaX + (areaW - (roomW + deckGap + size.width)) / 2)

    -- Card centers sit on half pixels (odd card size) so card edges land on whole pixels.
    L.roomY = 30 + size.height / 2
    L.slotX = {}
    for i = 1, CARDS_PER_ROOM do
        L.slotX[i] = left + size.width / 2 + (i - 1) * spacing
    end
    L.roomLeft = left
    L.roomRight = left + roomW
    L.roomCenterX = left + roomW / 2
    L.deckX = left + roomW + deckGap + size.width / 2
    L.tabsY = L.roomY + size.height / 2 + 8
    L.hintY = L.tabsY + 2 * TAB_HEIGHT + TAB_GAP + 6

    local zoneY = L.hintY + 38
    local zoneLeft = L.roomLeft - 10
    local zoneRight = L.deckX + size.width / 2 + 10
    L.zone = { x = zoneLeft, y = zoneY, w = zoneRight - zoneLeft, h = H - SAFE_Y - zoneY }
    L.weaponX = L.slotX[1]
    L.weaponY = zoneY + 26 + size.height / 2

    self.layout = L
end

function GameView:createButtons()
    local L, C = self.layout, UI.colors
    local function button(params)
        return Button:new(params, self.assets, self.mouseProvider)
    end

    self.fleeButton = button({
        x = L.deckX - 40, y = L.tabsY, width = 80, height = 24,
        text = "FLEE", color = C.red,
        onClick = function() self:flee() end,
    })
    self.undoButton = button({
        x = L.deckX - 40, y = L.tabsY + 31, width = 80, height = 24,
        text = "UNDO", color = C.blue, hotkey = "U",
        onClick = function() self:undo() end,
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

    self.buttons = { self.fleeButton, self.undoButton, self.rulesButton, self.menuButton }
end

function GameView:subscribe()
    local function on(event, handler)
        table.insert(self.subscriptions, { event = event, callback = self.eventBus:subscribe(event, handler) })
    end
    on("cardPlayed", function(gameState, outcome) self:onCardPlayed(gameState, outcome) end)
    on("roomChanged", function(gameState, reason) self:onRoomChanged(gameState, reason) end)
    on("stateRestored", function(gameState) self:onStateRestored(gameState) end)
    on("endGame", function(didWin, gameState) self:onEndGame(didWin, gameState) end)
end

function GameView:destroy()
    for _, subscription in ipairs(self.subscriptions) do
        self.eventBus:unsubscribe(subscription.event, subscription.callback)
    end
    self.subscriptions = {}
    self.timers = {}
end

-- Delayed callback owned by this view: it dies with the view.
function GameView:after(delay, callback)
    Timer.after(delay, callback):group(self.timers)
end

------------------------------------------------------------------------
-- Reconciliation: model -> card views
------------------------------------------------------------------------

function GameView:createView(card)
    local view = CardView:new(card, self.assets, 0, 0)
    self.viewCount = self.viewCount + 1
    view.order = self.viewCount
    self.views[card.position] = view
    return view
end

function GameView:findRoomCard(key)
    for _, card in ipairs(self.state.room.cards) do
        if card.position == key then
            return card
        end
    end
end

-- Cards keep their slot while they stay in the room; new cards fill free slots left to right.
function GameView:assignSlots(roomCards)
    local inRoom = {}
    for _, card in ipairs(roomCards) do
        inRoom[card.position] = true
    end
    local assigned = {}
    for slot = 1, CARDS_PER_ROOM do
        local key = self.slots[slot]
        if key and not inRoom[key] then
            self.slots[slot] = nil
        elseif key then
            assigned[key] = true
        end
    end
    for _, card in ipairs(roomCards) do
        local key = card.position
        if not assigned[key] then
            local view = self.views[key]
            local preferred = view and view.lastSlot
            if preferred and not self.slots[preferred] then
                self.slots[preferred] = key
            else
                for slot = 1, CARDS_PER_ROOM do
                    if not self.slots[slot] then
                        self.slots[slot] = key
                        break
                    end
                end
            end
            assigned[key] = true
        end
    end
end

function GameView:revive(view)
    view.exitToken = nil
    view.exitKind = nil
    view.faceUp = true
    view:restore()
    view:juiceUp(0.2)
end

function GameView:placeCard(card, zone, x, y, r, present)
    local view = self.views[card.position]
    if not view then
        view = self:createView(card)
        view:snapTo(x, y, r)
    elseif view.zone == "gone" or view.zone == "exiting" then
        self:revive(view)
    end
    view.card = card
    view.zone = zone
    view:setTarget(x, y, r)
    present[card.position] = true
    return view
end

--[[
    Moves every card view to where the model says the card is.
    opts.exits:     card.position -> exit animation for cards leaving play
    opts.dealDelay: delay before cards coming from the deck start moving
    Returns how many cards were dealt from the deck.
]]
function GameView:sync(opts)
    opts = opts or {}
    local L = self.layout
    local state = self.state
    local present = {}
    local dealt = 0
    local deckX, deckY = self.deck:topPosition()

    self:assignSlots(state.room.cards)
    for slot = 1, CARDS_PER_ROOM do
        local key = self.slots[slot]
        if key then
            local card = self:findRoomCard(key)
            local view = self.views[key]
            local fromDeck = view == nil or view.zone == "deck"
            view = self:placeCard(card, "room", L.slotX[slot], L.roomY, 0, present)
            if fromDeck then
                view:snapTo(deckX, deckY)
                view:setTarget(L.slotX[slot], L.roomY)
                view.exitKind = nil
                view.exitToken = nil
                view.flip = -1
                view.faceUp = true
                view.delay = (opts.dealDelay or 0) + dealt * DEAL_INTERVAL
                dealt = dealt + 1
            end
            view.slot = slot
            view.lastSlot = slot
        end
    end

    local armor = state.player.armor
    if armor and armor.card then
        self:placeCard(armor.card, "weapon", L.weaponX, L.weaponY, 0, present).slot = nil
        for i, card in ipairs(armor.defendedCards) do
            local lean = (i % 2 == 0 and 1 or -1) * 0.03
            local view = self:placeCard(card, "stack", L.weaponX + i * STACK_SPACING, L.weaponY + i * 2, lean, present)
            view.slot = nil
            view.stackIndex = i
        end
    end

    for key, view in pairs(self.views) do
        local inPlay = view.zone == "room" or view.zone == "weapon" or view.zone == "stack"
        if inPlay and not present[key] then
            self:startExit(view, (opts.exits and opts.exits[key]) or "discard")
        end
    end

    self.deck:setCount(#state.drawPile.cards)
    return dealt
end

--[[
    Exit animations for cards leaving play:
      deck    - flip face down and slide under the dungeon pile (fleeing)
      drink   - fly into the health meter and dissolve (potions)
      fists   - lunge at the player and burn (monsters fought barehanded)
      discard - burn to ash where it is (replaced weapons, wasted potions)
]]
function GameView:startExit(view, kind)
    local token = {}
    view.zone = "exiting"
    view.exitKind = kind
    view.exitToken = token
    view.hovered = false
    view.slot = nil

    if kind == "deck" then
        local x, y = self.deck:topPosition()
        view.faceUp = false
        view.lastSlot = nil
        view:setTarget(x, y, 0, 1)
    elseif kind == "drink" then
        local hx, hy = self.sidebar:healthAnchor()
        view:juiceUp(0.3)
        view:setTarget(hx, hy, 0, 0.55)
        self:after(0.28, function()
            if view.exitToken == token then
                view:burnAway("heal", 2.2)
            end
        end)
    elseif kind == "fists" then
        view:juiceUp(0.35)
        view:setTarget(view.T.x, view.T.y + 36, 0, 1.12)
        self:after(0.2, function()
            if view.exitToken == token then
                view:flashWhite(1)
                view:burnAway("fire", 1.6)
            end
        end)
    else
        view:burnAway("ash", 1.6)
    end
end

function GameView:updateExit(view)
    if view.zone ~= "exiting" then
        return
    end
    if view.exitKind == "deck" then
        if view:distanceToTarget() < 3 then
            view.zone = "deck"
        end
    elseif view:isBurnt() then
        view.zone = "gone"
    end
end

------------------------------------------------------------------------
-- Model events
------------------------------------------------------------------------

function GameView:onCardPlayed(gameState, outcome)
    self.state = gameState
    self.focusKey = nil
    local L, C = self.layout, UI.colors
    local fonts = self.assets.fonts
    local card = outcome.card
    local key = card.position
    local view = self.views[key]
    local exits = {}

    -- Delayed feedback is dropped if the play gets undone before it shows up.
    local token = {}
    self.playToken = token
    local function later(delay, callback)
        self:after(delay, function()
            if self.playToken == token then
                callback()
            end
        end)
    end

    if outcome.kind == "potion" then
        if outcome.wasted then
            exits[key] = "discard"
            self.effects:floatText("WASTED", view.T.x, view.T.y - 10, C.textDim, { font = fonts.big })
        else
            exits[key] = "drink"
            later(0.3, function()
                local hx, hy = self.sidebar:healthAnchor()
                self.sidebar:setLife(self.state.player.lifes)
                self.effects:floatText("+" .. outcome.heal, hx + 100, hy - 2, C.heal,
                    { font = self.assets.fonts.big, rise = 12 })
                self.effects:burst(hx, hy, C.heal, 14)
                self:flashScreen(C.heal, 0.25)
            end)
        end
    elseif outcome.kind == "weapon" then
        for _, discarded in ipairs(outcome.discarded or {}) do
            exits[discarded.position] = "discard"
        end
        later(0.25, function()
            local weapon = self:weaponView()
            if weapon then
                weapon:juiceUp(0.3)
            end
            self.effects:burst(L.weaponX, L.weaponY, C.orange, 12, { spread = 40 })
        end)
    elseif outcome.usedWeapon then
        local x = L.weaponX + #gameState.player.armor.defendedCards * STACK_SPACING
        later(0.22, function()
            local weapon = self:weaponView()
            if weapon then
                weapon:juiceUp(0.25)
            end
            if outcome.damage > 0 then
                self:hurt(outcome.damage, x, L.weaponY - 20)
            else
                self.effects:floatText("BLOCKED", x, L.weaponY - 20, UI.mix(C.blue, C.white, 0.35), { font = fonts.big })
                self.effects:burst(x, L.weaponY, C.blue, 10)
            end
        end)
    else
        exits[key] = "fists"
        local x, y = view.T.x, view.T.y + 36
        later(0.2, function()
            self:hurt(outcome.damage, x, y)
        end)
    end

    self:sync({ exits = exits })
    self.lock = 0.3
    if gameState:canGoNextRoom() then
        self:scheduleAdvance(AUTO_ADVANCE_DELAY)
    end
end

function GameView:onRoomChanged(gameState, reason)
    local exits = {}
    local dealDelay = 0.05
    if reason == "flee" then
        for slot = 1, CARDS_PER_ROOM do
            local key = self.slots[slot]
            if key then
                exits[key] = "deck"
                -- Sweep the room back into the dungeon from right to left.
                self.views[key].delay = (CARDS_PER_ROOM - slot) * 0.06
            end
        end
        self.slots = {}
        dealDelay = 0.6
    end
    self.state = gameState
    self.focusKey = nil
    local dealt = self:sync({ exits = exits, dealDelay = dealDelay })
    self.lock = dealDelay + dealt * DEAL_INTERVAL + 0.25

    local label = reason == "flee" and "FLED!" or ("ROOM " .. gameState.roomNumber)
    self:showBanner(label, UI.colors.gold, dealDelay)
end

function GameView:onStateRestored(gameState)
    self.state = gameState
    self.focusKey = nil
    self.advanceToken = nil
    self.playToken = nil
    self:sync()
    self.sidebar:setLife(gameState.player.lifes)
    self.lock = 0.2
    local button = self.undoButton
    self.effects:floatText("UNDONE", button.pos.x + button.size.width / 2, button.pos.y + 46, UI.colors.text,
        { font = self.assets.fonts.medium, duration = 0.7, rise = 6 })
end

function GameView:onEndGame(didWin, gameState)
    self.over = true
    self.focusKey = nil
    local L, C = self.layout, UI.colors
    local delay
    if didWin then
        delay = 1.5
        self:after(0.35, function()
            self.effects:floatText("ESCAPED!", L.roomCenterX, L.roomY + 20, C.gold,
                { font = self.assets.fonts.title, duration = 1.6, rise = 20 })
            for i = 1, 5 do
                self:after(i * 0.12, function()
                    local x = L.roomLeft + love.math.random() * (L.roomRight - L.roomLeft)
                    self.effects:burst(x, L.roomY, i % 2 == 0 and C.gold or C.heal, 16, { speed = 140, up = 80 })
                end)
            end
        end)
    else
        delay = 1.7
        self:after(0.3, function()
            self:shake(10)
            self:flashScreen(C.damage, 0.7)
            for _, view in pairs(self.views) do
                if view.zone == "room" or view.zone == "weapon" or view.zone == "stack" then
                    view:setTarget(view.T.x + (love.math.random() - 0.5) * 60, self.assets.HEIGHT + 140,
                        (love.math.random() - 0.5) * 1.5)
                end
            end
        end)
    end
    self:after(delay, function()
        self.eventBus:publish("navigate", "endGame", { didWin = didWin, gameState = gameState, runTime = self.runTime })
    end)
end

function GameView:scheduleAdvance(delay)
    local token = {}
    self.advanceToken = token
    self:after(delay, function()
        if self.advanceToken ~= token then
            return
        end
        self.advanceToken = nil
        if not self.over and self.state:canGoNextRoom() then
            self.eventBus:publish("action", Actions.NextRoomAction:new())
        end
    end)
end

------------------------------------------------------------------------
-- Feedback helpers
------------------------------------------------------------------------

function GameView:hurt(damage, x, y)
    local C = UI.colors
    self.sidebar:setLife(self.state.player.lifes)
    self.effects:floatText("-" .. damage, x, y, C.damage)
    self.effects:burst(x, y, C.damage, 8 + damage, { speed = 70 + damage * 8 })
    local hx, hy = self.sidebar:healthAnchor()
    self.effects:burst(hx, hy, C.damage, 8)
    self:shake(2 + damage * 0.6)
    self:flashScreen(C.damage, math.min(0.5, 0.15 + damage * 0.025))
end

function GameView:shake(amount)
    if self.settings:get("screenShake") then
        self.shakeAmount = math.max(self.shakeAmount, amount)
    end
end

function GameView:flashScreen(color, amount)
    self.vignetteColor = color
    self.vignette = math.max(self.vignette, amount)
end

-- Short label popping over the hint line (which is hidden meanwhile).
function GameView:showBanner(text, color, delay)
    local L = self.layout
    local duration = 0.8
    self.effects:floatText(text, L.roomCenterX, L.hintY + 12, color,
        { font = self.assets.fonts.big, delay = delay, duration = duration, rise = 12 })
    self.bannerTime = delay + duration
end

function GameView:weaponView()
    local armor = self.state.player.armor
    return armor and armor.card and self.views[armor.card.position]
end

------------------------------------------------------------------------
-- Player input
------------------------------------------------------------------------

function GameView:isBusy()
    return self.over or self.lock > 0 or self.advanceToken ~= nil
end

function GameView:flee()
    if not self:isBusy() then
        self.eventBus:publish("action", Actions.SkipRoomAction:new())
    end
end

function GameView:undo()
    if self.over then
        return
    end
    if not self.state.canUndo then
        self.undoButton.juice = Anim.newJuice(0.03, 0.06, 0.25)
        return
    end
    self.eventBus:publish("action", Actions.UndoAction:new())
end

function GameView:openMenu()
    if not self.over then
        self.eventBus:publish("navigate", "pause")
    end
end

-- Every way the hovered card can be resolved, main action first.
function GameView:actionsFor(card)
    local state, C = self.state, UI.colors
    local function damageLabel(damage)
        return damage > 0 and ("-" .. damage) or "0"
    end
    if card:isMonster() then
        local actions = {}
        local withWeapon = state:previewCard(card, true)
        if withWeapon.usedWeapon then
            table.insert(actions, { useArmor = true, preview = withWeapon, label = "WEAPON",
                value = damageLabel(withWeapon.damage), color = withWeapon.lethal and C.darkRed or C.orange })
        end
        local barehanded = state:previewCard(card, false)
        table.insert(actions, { useArmor = false, preview = barehanded, label = "FISTS",
            value = damageLabel(barehanded.damage), color = barehanded.lethal and C.darkRed or C.red,
            alternative = withWeapon.usedWeapon })
        return actions
    end
    local preview = state:previewCard(card)
    if preview.kind == "potion" then
        if preview.wasted then
            return { { preview = preview, label = "WASTED", value = "+0", color = C.grey } }
        end
        return { { preview = preview, label = "DRINK", value = "+" .. preview.heal, color = C.green } }
    end
    return { { preview = preview, label = "EQUIP", value = tostring(card.value), color = C.orange } }
end

function GameView:tabRect(slot, index)
    local L = self.layout
    local width = L.cardW + 6
    return L.slotX[slot] - width / 2, L.tabsY + (index - 1) * (TAB_HEIGHT + TAB_GAP), width, TAB_HEIGHT
end

function GameView:tabAt(key, mouseX, mouseY)
    local view = self.views[key]
    if not view or not view.slot then
        return nil
    end
    for index = 1, #self:actionsFor(view.card) do
        local x, y, w, h = self:tabRect(view.slot, index)
        if mouseX >= x and mouseX <= x + w and mouseY >= y and mouseY <= y + h + 2 then
            return index
        end
    end
    return nil
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
    if self:isBusy() then
        return
    end
    -- Resolve the hover at the click position, in case the mouse moved since the last update.
    self:updateHover(mouseX, mouseY)
    if not self.focusKey then
        return
    end
    local view = self.views[self.focusKey]
    local actions = self:actionsFor(view.card)
    local tab = self:tabAt(self.focusKey, mouseX, mouseY)
    -- Card body: main action; right click: the alternative (fight barehanded).
    local action = actions[tab or (button == 2 and #actions or 1)]
    view:juiceUp(0.2)
    self.eventBus:publish("action", Actions.PlayCardAction:new(view.card, action.useArmor))
end

function GameView:onKeyPressed(key)
    if self.over then
        return
    end
    local command = love.keyboard.isDown("lctrl", "rctrl", "lgui", "rgui")
    if key == "escape" then
        self:openMenu()
    elseif key == "u" or key == "backspace" or (key == "z" and command) then
        self:undo()
    end
end

------------------------------------------------------------------------
-- Update
------------------------------------------------------------------------

function GameView:update(dt, hasFocus)
    if hasFocus then
        -- Game flow (auto-advance, delayed effects) pauses while an overlay is open;
        -- the cards keep their idle animation.
        if not self.over then
            self.runTime = self.runTime + love.timer.getDelta()
        end
        Timer.update(dt, self.timers)
        self.lock = math.max(0, self.lock - dt)
        self.bannerTime = math.max(0, self.bannerTime - dt)
    end

    local mouseX, mouseY = self.mouseProvider()
    if not hasFocus then
        mouseX, mouseY = -1000, -1000
    end
    self:updateHover(mouseX, mouseY)

    for _, view in pairs(self.views) do
        if view.zone ~= "gone" and view.zone ~= "deck" then
            -- Potions that would be wasted this room are dimmed.
            local wasted = view.zone == "room" and view.card:isHeart() and self.state.potionUsedThisRoom
            view.tint = Anim.approach(view.tint, wasted and 0.65 or 1, 8, dt)
            view:update(dt, mouseX, mouseY)
            self:updateExit(view)
        end
    end

    self.deck:update(dt, mouseX, mouseY)
    self.sidebar:update(dt, self.state)
    self.sidebar.preview = self:hoveredPreviewLife()
    for _, b in ipairs(self.buttons) do
        b:update(dt, hasFocus)
    end
    self.fleeButton.disabled = self.over or not self.state:canSkipRoom()
    self.undoButton.disabled = self.over or not self.state.canUndo

    self.effects:update(dt)
    self.shakeAmount = Anim.approach(self.shakeAmount, 0, 7, dt)
    self.vignette = Anim.approach(self.vignette, 0, 3, dt)
    self.tabReveal = Anim.moveTowards(self.tabReveal, (self.focusKey and not self:isBusy()) and 1 or 0, dt * 8)
end

function GameView:updateHover(mouseX, mouseY)
    local focusKey = nil
    local tab = nil
    if not self.over then
        if self.focusKey and not self:isBusy() then
            tab = self:tabAt(self.focusKey, mouseX, mouseY)
            if tab then
                focusKey = self.focusKey
            end
        end
        if not focusKey then
            for slot = 1, CARDS_PER_ROOM do
                local key = self.slots[slot]
                local view = key and self.views[key]
                if view and view.zone == "room" and view:contains(mouseX, mouseY) then
                    focusKey = key
                end
            end
        end
    end

    if focusKey ~= self.focusKey then
        self.tabReveal = 0
        if focusKey then
            self.views[focusKey]:juiceUp(0.06, 0.02)
        end
    end
    self.focusKey = focusKey
    self.hoverTab = tab or (focusKey and 1 or nil)

    local zoneHover = self:zoneCardAt(mouseX, mouseY)
    for key, view in pairs(self.views) do
        view.hovered = key == focusKey or view == zoneHover
    end
end

-- Topmost weapon/slain-monster card under the mouse (purely cosmetic hover).
function GameView:zoneCardAt(mouseX, mouseY)
    local armor = self.state.player.armor
    if self.over or not armor or not armor.card then
        return nil
    end
    for i = #armor.defendedCards, 1, -1 do
        local view = self.views[armor.defendedCards[i].position]
        if view and view.zone == "stack" and view:contains(mouseX, mouseY) then
            return view
        end
    end
    local weapon = self.views[armor.card.position]
    if weapon and weapon.zone == "weapon" and weapon:contains(mouseX, mouseY) then
        return weapon
    end
    return nil
end

function GameView:hoveredAction()
    if not self.focusKey or self:isBusy() then
        return nil
    end
    local actions = self:actionsFor(self.views[self.focusKey].card)
    return actions[self.hoverTab or 1]
end

function GameView:hoveredPreviewLife()
    local action = self:hoveredAction()
    return action and action.preview.lifeAfter or nil
end

------------------------------------------------------------------------
-- Rendering
------------------------------------------------------------------------

function GameView:render()
    UI.renderBackground(self.assets)

    love.graphics.push()
    if self.shakeAmount > 0.05 then
        local t = love.timer.getTime() * 30
        love.graphics.translate((love.math.noise(t, 0) - 0.5) * 2 * self.shakeAmount,
            (love.math.noise(0, t) - 0.5) * 2 * self.shakeAmount)
    end

    self.sidebar:render(self.state, self.runTime)
    self:renderSlots()
    self:renderWeaponZone()

    -- Cards fleeing into the dungeon slide under the pile; everything else is drawn above it.
    for _, view in ipairs(self:drawList(true)) do
        view:draw()
    end
    self.deck:render()
    for _, view in ipairs(self:drawList(false)) do
        view:draw()
    end

    self:renderTabs()
    self:renderHint()
    for _, b in ipairs(self.buttons) do
        b:render()
    end
    self.effects:draw()
    love.graphics.pop()

    if self.vignette > 0.01 then
        UI.setColor(self.vignetteColor, self.vignette)
        love.graphics.draw(self.vignetteMesh)
    end
end

function GameView:layerOf(view)
    if view.hovered and view.zone == "room" then
        return 5
    end
    if view.zone == "exiting" then
        return view.exitKind == "discard" and 0 or 4
    end
    if view.delay > 0 then
        return 3 - view.delay
    end
    if view:distanceToTarget() > 3 then
        return 3
    end
    if view.zone == "weapon" then
        return 1
    end
    if view.zone == "stack" then
        return 1 + (view.stackIndex or 0) * 0.01
    end
    return 2
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
    table.sort(list, function(a, b)
        if a.layer ~= b.layer then
            return a.layer < b.layer
        end
        return a.order < b.order
    end)
    return list
end

function GameView:renderSlots()
    local L = self.layout
    for slot = 1, CARDS_PER_ROOM do
        UI.box(L.slotX[slot] - L.cardW / 2, L.roomY - L.cardH / 2, L.cardW, L.cardH,
            UI.colors.panelDark, { radius = 6, alpha = 0.2 })
    end
end

function GameView:renderWeaponZone()
    local L, C = self.layout, UI.colors
    local fonts = self.assets.fonts
    local zone = L.zone
    UI.box(zone.x, zone.y, zone.w, zone.h, C.panelDark, { radius = 8, alpha = 0.3 })
    UI.icon(self.assets, "diamond", zone.x + 8, zone.y + 6, 12)
    UI.text("WEAPON", zone.x + 23, zone.y + 8, fonts.tiny, C.text)

    local player = self.state.player
    local left = L.weaponX - L.cardW / 2
    local infoY = L.weaponY + L.cardH / 2 + 8

    local focus = self.focusKey and self.views[self.focusKey]
    if focus and focus.card:isMonster() and player:hasArmor() and not self:isBusy() then
        local usable = player:canUseArmor(focus.card)
        local label = usable and "can slay this monster" or "is too weak for this monster"
        UI.text(label, zone.x + 58, zone.y + 8, fonts.tiny, usable and C.heal or C.damage)
    end

    if not player:hasArmor() then
        UI.box(left, L.weaponY - L.cardH / 2, L.cardW, L.cardH, C.panelDark, { radius = 6, alpha = 0.35 })
        UI.textCentered("NONE", L.weaponX, L.weaponY, fonts.medium, C.textDim)
        UI.text("Monsters hit you for their full value.", left, infoY, fonts.small, C.textDim)
        UI.text("Pick up a diamond to fight back.", left, infoY + 14, fonts.small, C.textDim)
        return
    end

    local weapon = player.armor.card
    local limit = player:armorLimit()
    UI.text("POWER " .. weapon.value, left, infoY, fonts.small, C.orange)
    local reach = limit and ("Slays monsters below " .. UI.valueLabel(limit)) or "Slays any monster"
    UI.text(reach, left, infoY + 14, fonts.small, C.text)
    if #player.armor.defendedCards == 0 then
        UI.text("Monsters slain with this weapon\nstack here and lower its reach.", L.weaponX + L.cardW / 2 + 14,
            L.weaponY - 12, fonts.small, C.textDim, { alpha = 0.8 })
    end
end

function GameView:renderTabs()
    if self.tabReveal <= 0 or not self.focusKey then
        return
    end
    local view = self.views[self.focusKey]
    if not view.slot then
        return
    end
    local fonts = self.assets.fonts
    local reveal = Anim.easeOutCubic(self.tabReveal)
    for index, action in ipairs(self:actionsFor(view.card)) do
        local x, y, w, h = self:tabRect(view.slot, index)
        y = y - (1 - reveal) * 8
        local active = self.hoverTab == index
        local color = active and UI.mix(action.color, UI.colors.white, 0.15) or UI.shade(action.color, 0.8)
        local lift = active and -1 or 0
        UI.box(x, y + lift, w, h, color, { radius = 4, depth = 2, alpha = reveal })
        UI.text(action.label, x + 5, y + lift + 3, fonts.small, UI.colors.text, { alpha = reveal })
        UI.text(action.value, x + w - 5 - fonts.small:getWidth(action.value), y + lift + 3, fonts.small,
            UI.colors.text, { alpha = reveal })
    end
end

function GameView:renderHint()
    local text, color = self:hintText()
    if not text then
        return
    end
    local L = self.layout
    UI.text(text, L.roomLeft, L.hintY, self.assets.fonts.small, color or UI.colors.text,
        { width = L.roomRight - L.roomLeft, align = "center" })
end

-- Contextual guidance under the room: explains the hovered action or what to do next.
function GameView:hintText()
    local state, C = self.state, UI.colors
    if self.over or self.bannerTime > 0 then
        return nil
    end
    if self.fleeButton.hoovered then
        local reason = state:skipBlockedReason()
        if reason then
            return FLEE_BLOCKED_HINTS[reason], C.textDim
        end
        return "Flee: these 4 cards go to the bottom of the dungeon and a new room is dealt. Never twice in a row."
    end
    if self.undoButton.hoovered then
        if state.canUndo then
            return "Take back the last card you resolved (U)."
        end
        return "Nothing to undo. Only cards resolved in the current room can be undone.", C.textDim
    end
    if self.deck.hoovered then
        return "The dungeon: " .. #state.drawPile.cards .. " cards left. Every new room is dealt from here."
    end

    local action = self:hoveredAction()
    if action then
        return self:describe(action)
    end

    if self.advanceToken then
        return "Room cleared! The last card stays for the next room."
    end
    if state:isFinalRoom() then
        return "Final room! Resolve every card left to escape the dungeon.", C.gold
    end
    local toResolve = #state.room.cards - 1
    if toResolve >= CARDS_PER_ROOM - 1 then
        if state:canSkipRoom() then
            return "Resolve 3 of these 4 cards in any order, or flee the room. Hover a card to see what it does."
        end
        return "Resolve 3 of these 4 cards in any order. You fled the last room, so no fleeing now."
    end
    if toResolve == 1 then
        return "1 more card to resolve. The last one stays for the next room."
    end
    return toResolve .. " more cards to resolve in this room."
end

function GameView:describe(action)
    local preview, C = action.preview, UI.colors
    local card = preview.card
    local player = self.state.player

    if preview.kind == "potion" then
        if preview.wasted then
            return "You already drank a potion in this room: this one would be wasted.", C.textDim
        end
        if preview.heal == 0 then
            return "You are at full health: drinking now heals nothing and uses up this room's potion.", C.textDim
        end
        if preview.heal < card.value then
            return "Drink to heal " .. preview.heal .. " (health is capped at 20). Only one potion per room works."
        end
        return "Drink to heal " .. preview.heal .. ". Only one potion per room works."
    end

    if preview.kind == "weapon" then
        if preview.replaced then
            local extra = preview.discardCount > 1 and " and the monsters on it are" or " is"
            return "Equip this " .. card.value .. ". Your " .. preview.replaced.value .. extra .. " discarded."
        end
        return "Equip this weapon: monsters will deal their value minus " .. card.value .. "."
    end

    local text
    if preview.usedWeapon then
        local weaponValue = player.armor.card.value
        local cost = preview.damage > 0 and
            ("take " .. preview.damage .. " damage (" .. card.value .. " - " .. weaponValue .. ")") or
            ("no damage, your " .. weaponValue .. " beats its " .. card.value)
        text = "Weapon: " .. cost .. ". It will then only slay monsters below " .. UI.valueLabel(card.value) .. "."
    elseif action.alternative then
        text = "Barehanded: take all " .. preview.damage .. " damage, but your weapon stays untouched."
    elseif not player:hasArmor() then
        text = "No weapon: fight barehanded and take " .. preview.damage .. " damage."
    else
        text = "Your weapon only slays monsters below " .. UI.valueLabel(player:armorLimit()) ..
            ". Fight barehanded: " .. preview.damage .. " damage."
    end
    if preview.lethal then
        return "LETHAL! " .. text, C.damage
    end
    return text
end

return GameView