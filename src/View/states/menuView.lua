--[[
    MenuView
    Home screen: animated title, a fan of floating cards and the main navigation buttons.
    Publishes "navigate" events; it knows nothing about the other screens.
]]

local Card     = require("src.Model.card")
local CardView = require("src.View.cardView")
local Button   = require("src.View.buttonView")
local Anim     = require("src.View.anim")
local UI       = require("src.View.ui")

local MenuView = {}
MenuView.__index = MenuView

local TITLE = "SCOUNDREL"
-- suit, value: A of spades, K of clubs, 10 of diamonds, 7 of hearts, Q of spades
local SHOWCASE = { { 3, 14 }, { 1, 13 }, { 2, 10 }, { 0, 7 }, { 3, 12 } }
local BUTTONS = {
    { text = "PLAY",        color = "blue",   width = 110, target = "newGame" },
    { text = "HOW TO PLAY", color = "orange", width = 140, target = "rules" },
    { text = "SETTINGS",    color = "green",  width = 120, target = "settings" },
}
-- A web page can't be closed by the game.
if not Constants.IS_WEB then
    table.insert(BUTTONS, { text = "QUIT", color = "red", width = 90, target = "quit" })
end

function MenuView:new(context)
    local o = setmetatable({}, self)
    o.assets        = context.assets
    o.eventBus      = context.eventBus
    o.records       = context.records
    o.mouseProvider = context.mouseProvider
    o.time          = 0
    o.titleDrop     = -90
    o.titleVel      = 0
    o.cards         = {}
    o.buttons       = {}

    local W, H = o.assets.WIDTH, o.assets.HEIGHT
    for i, spec in ipairs(SHOWCASE) do
        local offset = i - (#SHOWCASE + 1) / 2
        local x = W / 2 + offset * 64
        local view = CardView:new(Card:new(spec[1], spec[2]), o.assets, x, H + 120)
        view:setTarget(x, 206 + math.abs(offset) * 8, offset * 0.09)
        view.delay = 0.1 + i * 0.07
        view.flip = -1
        table.insert(o.cards, view)
    end

    local gap = 10
    local total = -gap
    for _, spec in ipairs(BUTTONS) do
        total = total + spec.width + gap
    end
    local x = (W - total) / 2
    for i, spec in ipairs(BUTTONS) do
        local button = Button:new({
            x = x, y = 306, width = spec.width, height = 34,
            text = spec.text, color = UI.colors[spec.color], font = o.assets.fonts.big,
            onClick = function() o.eventBus:publish("navigate", spec.target) end,
        }, o.assets, o.mouseProvider)
        button.visible = false
        button.showAt = 0.45 + i * 0.08
        table.insert(o.buttons, button)
        x = x + spec.width + gap
    end

    return o
end

function MenuView:update(dt, hasFocus)
    self.time = self.time + dt
    self.titleDrop, self.titleVel = Anim.spring(self.titleDrop, self.titleVel, 0, 120, 9, dt)

    local mouseX, mouseY = self.mouseProvider()
    if not hasFocus then
        mouseX, mouseY = -1000, -1000
    end
    local hovered = self:cardAt(mouseX, mouseY)
    for _, card in ipairs(self.cards) do
        if card == hovered and not card.hovered then
            card:juiceUp(0.08, 0.03)
            self.assets.audio:play("hover", { pitch = 0.7, variation = 0.1 })
        end
        card.hovered = card == hovered
        card:update(dt, mouseX, mouseY)
    end

    for _, button in ipairs(self.buttons) do
        if not button.visible and self.time >= button.showAt then
            button.visible = true
            button.juice = Anim.newJuice(0.15, 0.03, 0.4)
        end
        button:update(dt, hasFocus)
    end
end

function MenuView:cardAt(x, y)
    for i = #self.cards, 1, -1 do
        if self.cards[i]:contains(x, y) then
            return self.cards[i]
        end
    end
    return nil
end

function MenuView:render()
    local assets = self.assets
    local W, H = assets.WIDTH, assets.HEIGHT
    UI.renderBackground(assets)

    local font = assets.fonts.title
    local x = W / 2 - font:getWidth(TITLE) / 2
    for i = 1, #TITLE do
        local letter = TITLE:sub(i, i)
        local letterW = font:getWidth(letter)
        local wave = math.sin(self.time * 2 + i * 0.55) * 3
        local tilt = math.sin(self.time * 1.3 + i) * 0.04
        UI.textCentered(letter, x + letterW / 2, 70 + wave + self.titleDrop, font, UI.colors.text,
            { r = tilt, shadowDepth = 4 })
        x = x + letterW
    end
    UI.textCentered("A roguelike dungeon crawl played with a deck of cards", W / 2, 118 + self.titleDrop * 0.5,
        assets.fonts.small, UI.colors.text)

    local hovered = nil
    for _, card in ipairs(self.cards) do
        if card.hovered then
            hovered = card
        else
            card:draw()
        end
    end
    if hovered then
        hovered:draw()
    end

    for _, button in ipairs(self.buttons) do
        button:render()
    end

    UI.textCentered(self:recordsText(), W / 2, H - 28, assets.fonts.small, UI.colors.text, { alpha = 0.85 })
end

function MenuView:recordsText()
    local played = self.records:get("gamesPlayed")
    if played == 0 then
        return "Survive all 44 cards of the dungeon. Good luck, scoundrel."
    end
    return "Runs " .. played .. "     Escaped " .. self.records:get("gamesWon") ..
        "     Best score " .. self.records:get("bestScore")
end

function MenuView:onMouseClick(mouseX, mouseY, button)
    for _, b in ipairs(self.buttons) do
        if b:onMouseClick(mouseX, mouseY) then
            return
        end
    end
    local card = self:cardAt(mouseX, mouseY)
    if card then
        card.faceUp = not card.faceUp
        card:juiceUp(0.2)
        self.assets.audio:play("deal", { variation = 0.2 })
    end
end

function MenuView:onKeyPressed(key)
    if key == "return" or key == "space" then
        self.eventBus:publish("navigate", "newGame")
    elseif key == "escape" and not Constants.IS_WEB then
        self.eventBus:publish("navigate", "quit")
    end
end

return MenuView
