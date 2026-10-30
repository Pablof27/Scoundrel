--[[
    BoardView
    Base of the game boards (the screens where a game is played), so every game shares the same feel:
    - one CardView per card (keyed by card.position), kept for the whole game: cards that leave play
      are revived instead of recreated, so every change can be animated
    - delayed callbacks and EventBus subscriptions owned by the board, released in destroy()
    - floating texts and particles, screen shake and a coloured flash of the screen edges
    A board is created with BoardView.extend() and calls BoardView.init(o, context) in its constructor.
]]

local CardView = require("src.View.cardView")
local Effects  = require("src.View.effects")
local Anim     = require("src.View.anim")
local UI       = require("src.View.ui")
local Timer    = require("lib.timer")

local BoardView = {}
BoardView.__index = BoardView

function BoardView.extend()
    local class = setmetatable({}, BoardView)
    class.__index = class
    return class
end

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

function BoardView.init(o, context)
    o.assets        = context.assets
    o.eventBus      = context.eventBus
    o.settings      = context.settings
    o.mouseProvider = context.mouseProvider
    o.views         = {}  -- card.position -> CardView
    o.viewCount     = 0
    o.timers        = {}
    o.subscriptions = {}
    o.effects       = Effects:new(o.assets)
    o.lock          = 0   -- input is ignored while animations play
    o.bannerTime    = 0   -- a banner is showing
    o.shakeAmount   = 0
    o.vignette      = 0
    o.vignetteColor = UI.colors.damage
    o.vignetteMesh  = newVignetteMesh(o.assets.WIDTH, o.assets.HEIGHT, 70)
    o.runTime       = 0
    o.over          = false
end

function BoardView:on(event, handler)
    table.insert(self.subscriptions, { event = event, callback = self.eventBus:subscribe(event, handler) })
end

function BoardView:destroy()
    for _, subscription in ipairs(self.subscriptions) do
        self.eventBus:unsubscribe(subscription.event, subscription.callback)
    end
    self.subscriptions = {}
    self.timers = {}
end

-- Delayed callback owned by this board: it dies with the board.
function BoardView:after(delay, callback)
    Timer.after(delay, callback):group(self.timers)
end

------------------------------------------------------------------------
-- Card views
------------------------------------------------------------------------

function BoardView:createView(card)
    local view = CardView:new(card, self.assets, 0, 0)
    self.viewCount = self.viewCount + 1
    view.order = self.viewCount
    self.views[card.position] = view
    return view
end

function BoardView:revive(view)
    view.exitToken = nil
    view.exitKind = nil
    view.faceUp = true
    view:restore()
    view:juiceUp(0.2)
end

-- Moves the card's view (created on the spot if needed) towards (x, y, r) in `zone`,
-- and marks it in `present`.
function BoardView:placeCard(card, zone, x, y, r, present)
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

-- Sorts views for drawing: by their `layer`, then by creation order.
function BoardView.sortByLayer(list)
    table.sort(list, function(a, b)
        if a.layer ~= b.layer then
            return a.layer < b.layer
        end
        return a.order < b.order
    end)
    return list
end

------------------------------------------------------------------------
-- Feedback
------------------------------------------------------------------------

function BoardView:shake(amount)
    if self.settings:get("screenShake") then
        self.shakeAmount = math.max(self.shakeAmount, amount)
    end
end

function BoardView:flashScreen(color, amount)
    self.vignetteColor = color
    self.vignette = math.max(self.vignette, amount)
end

-- Short label popping at (x, y). While it shows, bannerTime > 0 (boards hide their hints meanwhile).
function BoardView:showBanner(text, color, x, y, delay)
    local duration = 0.8
    delay = delay or 0
    self.effects:floatText(text, x, y, color,
        { font = self.assets.fonts.big, delay = delay, duration = duration, rise = 12 })
    self.bannerTime = math.max(self.bannerTime, delay + duration)
end

------------------------------------------------------------------------
-- Update & render helpers
------------------------------------------------------------------------

-- Game flow (clock, delayed callbacks, input lock) only runs while the board has focus,
-- so it pauses under an overlay. Call at the start of update.
function BoardView:updateClock(dt, hasFocus)
    if not hasFocus then
        return
    end
    if not self.over then
        self.runTime = self.runTime + love.timer.getDelta()
    end
    Timer.update(dt, self.timers)
    self.lock = math.max(0, self.lock - dt)
    self.bannerTime = math.max(0, self.bannerTime - dt)
end

-- Effects, shake and flash decay. Call at the end of update.
function BoardView:updateFeedback(dt)
    self.effects:update(dt)
    self.shakeAmount = Anim.approach(self.shakeAmount, 0, 7, dt)
    self.vignette = Anim.approach(self.vignette, 0, 3, dt)
end

-- Background and screen shake. Everything drawn until endRender shakes.
function BoardView:beginRender()
    UI.renderBackground(self.assets)
    love.graphics.push()
    if self.shakeAmount > 0.05 then
        local t = love.timer.getTime() * 30
        love.graphics.translate((love.math.noise(t, 0) - 0.5) * 2 * self.shakeAmount,
            (love.math.noise(0, t) - 0.5) * 2 * self.shakeAmount)
    end
end

-- Effects on top of the board, then the screen flash (which doesn't shake).
function BoardView:endRender()
    self.effects:draw()
    love.graphics.pop()
    if self.vignette > 0.01 then
        UI.setColor(self.vignetteColor, self.vignette)
        love.graphics.draw(self.vignetteMesh)
    end
end

return BoardView
