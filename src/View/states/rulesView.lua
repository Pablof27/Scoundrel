--[[
    RulesView
    "How to play" overlay: a short illustrated tutorial split into pages.
    Can be opened from the home screen, the pause menu or the in-game RULES button.
]]

local Card     = require("src.Model.card")
local CardView = require("src.View.cardView")
local Button   = require("src.View.buttonView")
local Anim     = require("src.View.anim")
local UI       = require("src.View.ui")

local RulesView = {}
RulesView.__index = RulesView

local PANEL_W, PANEL_H = 620, 352
local HEART, CLUB, DIAMOND, SPADE = 0, 1, 2, 3
local TEXT_W = 290

--[[
    Each page has a title and either `text` (left column) plus an illustration on the right
    (`cards` and `extras`, positioned relative to the illustration center), or `columns`.
]]
local PAGES = {
    {
        title = "THE DUNGEON",
        text = "You are a scoundrel delving into a dungeon made from a deck of cards.\n\n" ..
            "The dungeon holds 44 cards: every club and spade, plus the hearts and diamonds " ..
            "from 2 to 10. Red face cards and aces are left out.\n\n" ..
            "You start with 20 health. Resolve every card to escape. If your health drops to 0, you die.",
        cards = {
            { faceUp = false, x = -62, y = -4 },
            { faceUp = false, x = -60, y = -7 },
            { faceUp = false, x = -58, y = -10 },
        },
        extras = function(self, ax, ay)
            local C, fonts = UI.colors, self.assets.fonts
            UI.textCentered("44 CARDS", ax - 58, ay + 56, fonts.small, C.text)
            UI.icon(self.assets, "heart", ax + 38, ay - 44, 48)
            UI.textCentered("20", ax + 62, ay - 20, fonts.large, C.text, { shadowDepth = 2 })
            UI.textCentered("HEALTH", ax + 62, ay + 18, fonts.small, C.text)
        end,
    },
    {
        title = "THE CARDS",
        columns = {
            { suit = SPADE, value = 12, title = "MONSTERS", color = "red",
              text = "Clubs and spades deal damage equal to their value.\nJ = 11, Q = 12, K = 13, A = 14." },
            { suit = DIAMOND, value = 7, title = "WEAPONS", color = "orange",
              text = "Diamonds reduce a monster's damage by their value. Equipping one discards the old one." },
            { suit = HEART, value = 5, title = "POTIONS", color = "green",
              text = "Hearts heal their value, up to 20. Only one potion per room works: the next is wasted." },
        },
    },
    {
        title = "ROOMS",
        text = "Each room deals 4 cards from the dungeon. Resolve 3 of them, one at a time, in any order.\n\n" ..
            "The 4th card stays and becomes part of the next room, which is dealt automatically.\n\n" ..
            "Before resolving any card you may FLEE: the whole room goes to the bottom of the " ..
            "dungeon and a new one is dealt. You can never flee two rooms in a row.",
        cards = {
            { suit = CLUB, value = 9, x = -96, y = -34, s = 0.72 },
            { suit = HEART, value = 4, x = -32, y = -34, s = 0.72 },
            { suit = SPADE, value = 11, x = 32, y = -34, s = 0.72 },
            { suit = DIAMOND, value = 6, x = 96, y = -34, s = 0.72 },
        },
        extras = function(self, ax, ay)
            local C, fonts = UI.colors, self.assets.fonts
            for i, dx in ipairs({ -96, -32, 32 }) do
                UI.textCentered(tostring(i), ax + dx, ay + 12, fonts.medium, C.heal)
            end
            UI.textCentered("STAYS", ax + 96, ay + 12, fonts.small, C.gold)
            UI.box(ax - 40, ay + 42, 80, 24, C.red, { radius = 5, depth = 3 })
            UI.textCentered("FLEE", ax, ay + 54, fonts.medium, C.text)
            UI.textCentered("skip the whole room (not twice in a row)", ax, ay + 80, fonts.small, C.text)
        end,
    },
    {
        title = "COMBAT",
        text = "Barehanded, a monster hits you for its full value.\n\n" ..
            "With a weapon you take the monster's value minus the weapon's (never below 0) " ..
            "and the monster is stacked on the weapon.\n\n" ..
            "From then on, the weapon only slays monsters weaker than the last one it killed. " ..
            "You can always fight barehanded instead to keep your weapon fresh.",
        cards = {
            { suit = DIAMOND, value = 5, x = -78, y = -8 },
            { suit = SPADE, value = 12, x = -54, y = -6, r = 0.03 },
            { suit = CLUB, value = 11, x = 70, y = -52, s = 0.62 },
            { suit = SPADE, value = 13, x = 70, y = 40, s = 0.62 },
        },
        extras = function(self, ax, ay)
            local C, fonts = UI.colors, self.assets.fonts
            UI.textCentered("a 5 that slew a Q", ax - 66, ay + 52, fonts.small, C.text)
            UI.box(ax + 30, ay - 18, 80, 16, C.orange, { radius = 4, depth = 2 })
            UI.textCentered("WEAPON -6", ax + 70, ay - 10, fonts.small, C.text)
            UI.box(ax + 30, ay + 74, 80, 16, C.red, { radius = 4, depth = 2 })
            UI.textCentered("FISTS -13", ax + 70, ay + 82, fonts.small, C.text)
            UI.textCentered("J < Q: weapon works", ax + 70, ay - 94, fonts.small, C.text)
            UI.textCentered("K > Q: too strong", ax + 70, ay + 100, fonts.small, C.text)
        end,
    },
    {
        title = "CONTROLS & SCORE",
        text = "Hover a card to see exactly what it will do. Click it to play it.\n\n" ..
            "Monsters: click the card to use your weapon, or click FISTS (or right-click the card) " ..
            "to fight barehanded.\n\n" ..
            "UNDO (U) takes back cards resolved in the current room. ESC opens the menu.\n\n" ..
            "Score: escaping scores your remaining health (plus the potion if your last card was one, " ..
            "drunk at full health). Dying scores your health minus every monster left.",
        cards = {
            { suit = CLUB, value = 9, x = 0, y = -46 },
        },
        extras = function(self, ax, ay)
            local C, fonts = UI.colors, self.assets.fonts
            UI.box(ax - 38, ay + 8, 77, 18, C.orange, { radius = 4, depth = 2 })
            UI.text("WEAPON", ax - 33, ay + 11, fonts.small, C.text)
            UI.text("-4", ax + 33 - fonts.small:getWidth("-4"), ay + 11, fonts.small, C.text)
            UI.box(ax - 38, ay + 29, 77, 18, C.red, { radius = 4, depth = 2 })
            UI.text("FISTS", ax - 33, ay + 32, fonts.small, C.text)
            UI.text("-9", ax + 33 - fonts.small:getWidth("-9"), ay + 32, fonts.small, C.text)
            UI.textCentered("click the card = main action", ax, ay + 66, fonts.small, C.text)
            UI.textCentered("click a tab = that action", ax, ay + 80, fonts.small, C.text)
        end,
    },
}

function RulesView:new(context)
    local o = setmetatable({}, self)
    o.assets        = context.assets
    o.eventBus      = context.eventBus
    o.mouseProvider = context.mouseProvider
    o.appear        = 0
    o.page          = 1
    o.cards         = {}
    o.pageJuice     = nil

    o.panel = {
        x = math.floor((o.assets.WIDTH - PANEL_W) / 2),
        y = math.floor((o.assets.HEIGHT - PANEL_H) / 2),
        w = PANEL_W,
        h = PANEL_H,
    }
    local p = o.panel
    local function button(params)
        local b = Button:new(params, o.assets, o.mouseProvider)
        b.baseY = params.y
        return b
    end
    o.prevButton = button({
        x = p.x + 18, y = p.y + p.h - 42, width = 96, height = 28, text = "< PREV", color = UI.colors.grey,
        onClick = function() o:goTo(o.page - 1) end,
    })
    o.nextButton = button({
        x = p.x + p.w - 114, y = p.y + p.h - 42, width = 96, height = 28, text = "NEXT >", color = UI.colors.blue,
        onClick = function() o:goTo(o.page + 1) end,
    })
    o.closeButton = button({
        x = p.x + p.w - 74, y = p.y + 10, width = 60, height = 20, text = "CLOSE", color = UI.colors.red,
        font = o.assets.fonts.small,
        onClick = function() o:close() end,
    })
    o.buttons = { o.prevButton, o.nextButton, o.closeButton }
    o:buildPage()
    return o
end

function RulesView:artCenter()
    return self.panel.x + 465, self.panel.y + 168
end

function RulesView:buildPage()
    local page = PAGES[self.page]
    local p = self.panel
    local specs = {}
    if page.columns then
        for i, column in ipairs(page.columns) do
            table.insert(specs, { suit = column.suit, value = column.value, x = p.x + 110 + (i - 1) * 200, y = p.y + 112 })
        end
    else
        local ax, ay = self:artCenter()
        for _, spec in ipairs(page.cards or {}) do
            table.insert(specs, { suit = spec.suit, value = spec.value, faceUp = spec.faceUp, r = spec.r, s = spec.s,
                x = ax + spec.x, y = ay + spec.y })
        end
    end

    self.cards = {}
    for i, spec in ipairs(specs) do
        local faceUp = spec.faceUp ~= false
        local card = faceUp and Card:new(spec.suit, spec.value) or nil
        local view = CardView:new(card, self.assets, spec.x, spec.y + 40, { s = spec.s })
        view:setTarget(spec.x, spec.y, spec.r or 0, spec.s or 1)
        view.faceUp = faceUp
        view.flip = -1
        view.delay = (i - 1) * 0.06
        table.insert(self.cards, view)
    end
end

function RulesView:goTo(page)
    if page < 1 then
        return
    end
    if page > #PAGES then
        self:close()
        return
    end
    self.page = page
    self.pageJuice = Anim.newJuice(0.12, 0.02, 0.3)
    self.assets.audio:play("deal")
    self:buildPage()
end

function RulesView:close()
    self.eventBus:publish("navigate", "back")
end

function RulesView:offset()
    return (1 - Anim.easeOutBack(self.appear)) * 40
end

function RulesView:update(dt, hasFocus)
    self.appear = Anim.moveTowards(self.appear, 1, dt * 5)
    self.pageJuice = Anim.updateJuice(self.pageJuice, dt)
    self.prevButton.disabled = self.page == 1
    self.nextButton.text = self.page == #PAGES and "DONE" or "NEXT >"

    local mouseX, mouseY = self.mouseProvider()
    if not hasFocus then
        mouseX, mouseY = -1000, -1000
    end
    for _, card in ipairs(self.cards) do
        local hovered = card:contains(mouseX, mouseY)
        if hovered and not card.hovered then
            card:juiceUp(0.06, 0.02)
        end
        card.hovered = hovered
        card:update(dt, mouseX, mouseY)
    end
    for _, button in ipairs(self.buttons) do
        button.pos.y = button.baseY + self:offset()
        button:update(dt, hasFocus)
    end
end

function RulesView:render()
    local C, fonts = UI.colors, self.assets.fonts
    local p = self.panel
    local page = PAGES[self.page]

    UI.dim(self.assets, 0.6 * self.appear)
    love.graphics.push()
    love.graphics.translate(0, self:offset())

    UI.panel(p.x, p.y, p.w, p.h)
    UI.text("HOW TO PLAY", p.x + 16, p.y + 12, fonts.small, C.textDim)
    local juice = self.pageJuice
    UI.textCentered(page.title, p.x + p.w / 2, p.y + 24, fonts.big, C.gold,
        { scale = 1 + (juice and juice.scale or 0), r = juice and juice.r or 0, shadowDepth = 2 })

    local font = fonts.small
    font:setLineHeight(1.3)
    if page.columns then
        for i, column in ipairs(page.columns) do
            local cx = p.x + 110 + (i - 1) * 200
            UI.textCentered(column.title, cx, p.y + 184, fonts.medium, C[column.color])
            UI.text(column.text, cx - 88, p.y + 200, font, C.text, { width = 176, align = "center" })
        end
        UI.textCentered("During a run, hover any card to see exactly what it will do.", p.x + p.w / 2, p.y + 282,
            font, C.textDim)
    else
        UI.text(page.text, p.x + 22, p.y + 56, font, C.text, { width = TEXT_W })
        local ax, ay = self:artCenter()
        UI.box(ax - 140, ay - 118, 280, 236, C.panelDark, { radius = 8, alpha = 0.5 })
    end
    font:setLineHeight(1)

    for _, card in ipairs(self.cards) do
        card:draw()
    end
    if page.extras then
        local ax, ay = self:artCenter()
        page.extras(self, ax, ay)
    end
    for i = 1, #PAGES do
        local dotX = p.x + p.w / 2 + (i - (#PAGES + 1) / 2) * 14
        UI.setColor(i == self.page and C.gold or C.panelLight)
        love.graphics.circle("fill", dotX, p.y + p.h - 28, i == self.page and 4 or 3)
    end
    love.graphics.pop()

    for _, button in ipairs(self.buttons) do
        button:render()
    end
end

function RulesView:onMouseClick(mouseX, mouseY, button)
    for _, b in ipairs(self.buttons) do
        if b:onMouseClick(mouseX, mouseY) then
            return
        end
    end
    for _, card in ipairs(self.cards) do
        if card:contains(mouseX, mouseY) then
            card:juiceUp(0.2)
        end
    end
end

function RulesView:onKeyPressed(key)
    if key == "escape" then
        self:close()
    elseif key == "right" or key == "return" or key == "space" then
        self:goTo(self.page + 1)
    elseif key == "left" then
        self:goTo(self.page - 1)
    end
end

return RulesView
