--[[
    RulesView
    "How to play" overlay: a short illustrated tutorial split into pages, given by the game
    (see the `rules` of each game in src/Games).
    Can be opened from the game's home screen, the pause menu or the in-game RULES button.
]]

local Card     = require("src.Model.card")
local CardView = require("src.View.cardView")
local Button   = require("src.View.buttonView")
local Anim     = require("src.View.anim")
local UI       = require("src.View.ui")

local RulesView = {}
RulesView.__index = RulesView

local PANEL_W, PANEL_H = 620, 352
local TEXT_W = 290

--[[
    Each page has a title and either `text` (left column) plus an illustration on the right
    (`cards` and `extras`, positioned relative to the illustration center), or `columns`
    (one card, title and text each) with an optional `footer`.
    Cards: { suit, rank, faceUp, x, y, r, s }. extras(view, ax, ay) draws the rest of the illustration.
]]
function RulesView:new(context, game)
    local o = setmetatable({}, self)
    o.assets        = context.assets
    o.eventBus      = context.eventBus
    o.settings      = context.settings
    o.mouseProvider = context.mouseProvider
    o.pages         = game.rules
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
    local page = self.pages[self.page]
    local p = self.panel
    local specs = {}
    if page.columns then
        for i, column in ipairs(page.columns) do
            table.insert(specs, { suit = column.suit, rank = column.rank, x = p.x + 110 + (i - 1) * 200, y = p.y + 112 })
        end
    else
        local ax, ay = self:artCenter()
        for _, spec in ipairs(page.cards or {}) do
            table.insert(specs, { suit = spec.suit, rank = spec.rank, faceUp = spec.faceUp, r = spec.r, s = spec.s,
                x = ax + spec.x, y = ay + spec.y })
        end
    end

    self.cards = {}
    for i, spec in ipairs(specs) do
        local faceUp = spec.faceUp ~= false
        local card = faceUp and Card:new(spec.suit, spec.rank) or nil
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
    if page > #self.pages then
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
    self.nextButton.text = self.page == #self.pages and "DONE" or "NEXT >"

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
    local page = self.pages[self.page]

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
        if page.footer then
            UI.textCentered(page.footer, p.x + p.w / 2, p.y + 282, font, C.textDim)
        end
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
    local pageCount = #self.pages
    for i = 1, pageCount do
        local dotX = p.x + p.w / 2 + (i - (pageCount + 1) / 2) * 14
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
