--[[
    GameView
    Main gameplay screen. Renders room cards, player area, deck, and undo button.
    Receives assets, eventBus, and mouseProvider via init(). No global dependencies.
]]

local CardView = require("src.View.cardView")
local DeckView = require("src.View.deckView")
local Button   = require("src.View.buttonView")
local Actions   = require("src.Controller.playerAction")

local GameView = {}
GameView.__index = GameView

local ROOM_SPACING        = Constants.ROOM_SPACING
local PLAYER_AREA_SIZE    = Constants.PLAYER_AREA_SIZE
local PLAYER_AREA_SPACING = Constants.PLAYER_AREA_SPACING

function GameView:new()
    local o = setmetatable({}, self)
    o.state           = nil
    o.assets          = nil
    o.eventBus        = nil
    o.mouseProvider   = nil
    o.gameStateQuery  = nil
    o.roomCardViews   = {}
    o.playerCards     = {}
    o.selectedCardIdx = -1
    o.lifes           = 0
    o.deckView        = nil
    o.undoButton      = nil
    return o
end

function GameView:init(gameState, assets, eventBus, mouseProvider, gameStateQuery)
    self.state          = gameState
    self.assets         = assets
    self.eventBus       = eventBus
    self.mouseProvider  = mouseProvider
    self.gameStateQuery = gameStateQuery
    self.lifes          = gameState.player.lifes

    local WIDTH  = assets.WIDTH
    local HEIGHT = assets.HEIGHT
    self:initPlayArea(0, 16, WIDTH, HEIGHT - 16, gameState.room, gameState.player)
    self:initUndoButton()

    -- Subscribe to game events
    eventBus:subscribe("roomChanged", function(gs)
        self:onRoomChanged(gs)
    end)
    eventBus:subscribe("playerChanged", function(gs)
        self:onPlayerChanged(gs)
    end)
    eventBus:subscribe("cardPlayed", function(card)
        self:onCardPlayed(card)
    end)
end

function GameView:onRoomChanged(gameState)
    self.state = gameState
    self.selectedCardIdx = -1
    local WIDTH  = self.assets.WIDTH
    local HEIGHT = self.assets.HEIGHT
    local x, y, width, height = 0, 16, WIDTH, HEIGHT - 16
    self:initRoomCardViews(gameState.room, { x = x + width / 2, y = y + height / 2 - 64 })
end

function GameView:onPlayerChanged(gameState)
    self.state = gameState
    self.lifes = gameState.player.lifes
    self.selectedCardIdx = -1
    local WIDTH  = self.assets.WIDTH
    local HEIGHT = self.assets.HEIGHT
    local x, y, width, height = 0, 16, WIDTH, HEIGHT - 16
    self:initPlayerCardViews(gameState.player.armor, { x = x + width / 2, y = y + height / 2 + 64 })
end

function GameView:onCardPlayed(card)
    self.selectedCardIdx = -1
    for _, cardView in ipairs(self.roomCardViews) do
        if cardView.card == card then
            cardView.visible = false
        end
    end
    self:onPlayerChanged(self.state)
end

function GameView:render()
    local WIDTH  = self.assets.WIDTH
    local HEIGHT = self.assets.HEIGHT
    self:renderBackground()
    self:renderLifes(self.lifes)
    self:renderPlayArea(0, 16, WIDTH, HEIGHT - 16)
end

function GameView:update(dt)
    for _, cardView in ipairs(self.roomCardViews) do
        cardView:update(dt)
    end
    self.deckView:update(dt)
    self.undoButton:update(dt)
    self:updateUndoButton()
end

function GameView:onMouseClick(mouseX, mouseY)
    if self.undoButton:onMouseClick(mouseX, mouseY) then
        return
    end
    if self.deckView:onClick(mouseX, mouseY) then
        return
    end
    if #self.state.room.cards == 1 then
        return
    end
    if self.selectedCardIdx ~= -1 and
       self.roomCardViews[self.selectedCardIdx]:onClickButton(mouseX, mouseY) then
        return
    end
    for i, cardView in ipairs(self.roomCardViews) do
        if cardView.visible and cardView:isInside(mouseX, mouseY) then
            self.selectedCardIdx = i
            cardView:onSelected()
        else
            cardView:onUnselected()
        end
    end
end

function GameView:initPlayArea(x, y, width, height, room, player)
    local center = { x = x + width / 2, y = y + height / 2 }
    local context = self:makeContext()
    self:initRoomCardViews(room, { x = center.x, y = center.y - 64 })
    self:initPlayerCardViews(player.armor, { x = center.x, y = center.y + 64 })
    self.deckView = DeckView:new(center.x + PLAYER_AREA_SIZE.width / 2 + 16, center.y + 64, context)
end

function GameView:makeContext()
    return {
        assets         = self.assets,
        eventBus       = self.eventBus,
        mouseProvider  = self.mouseProvider,
        gameStateQuery = self.gameStateQuery,
    }
end

function GameView:initRoomCardViews(room, center)
    local size = self.assets:getCardSize()
    local spacing = ROOM_SPACING + size.width
    local xOffset = (spacing * (room.n - 1) + size.width) / 2
    local yOffset = size.height / 2
    self.selectedCardIdx = -1
    self.roomCardViews = {}
    local context = self:makeContext()
    for _, card in ipairs(room.cards) do
        local x = center.x - xOffset
        local y = center.y - yOffset
        table.insert(self.roomCardViews, CardView:new(card, x, y, context))
        xOffset = xOffset - spacing
    end
end

function GameView:initPlayerCardViews(armor, center)
    if armor == nil then
        self.playerCards = {}
        return
    end
    local x = center.x - PLAYER_AREA_SIZE.width / 2
    local y = center.y - PLAYER_AREA_SIZE.height / 2
    local n = #armor.defendedCards
    local cardSize = self.assets:getCardSize()
    local length = cardSize.width + PLAYER_AREA_SPACING * n
    local xOffset = (PLAYER_AREA_SIZE.width - length) / 2
    local yOffset = 3
    local context = self:makeContext()
    self.playerCards = {}
    table.insert(self.playerCards, CardView:new(armor.card, x + xOffset, y + yOffset, context, false))
    xOffset = xOffset + PLAYER_AREA_SPACING
    for _, card in ipairs(armor.defendedCards) do
        table.insert(self.playerCards, CardView:new(card, x + xOffset, y + yOffset, context, false))
        xOffset = xOffset + PLAYER_AREA_SPACING
    end
end

function GameView:renderBackground()
    love.graphics.setShader(self.assets.shaders.background)
    love.graphics.rectangle("fill", 0, 0, self.assets.WIDTH, self.assets.HEIGHT)
    love.graphics.setShader()
end

function GameView:renderLifes(lifes)
    local x = self.assets.WIDTH - 74
    local y = 16
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.draw(self.assets.textures.uiAssets, self.assets.frames.uiAssets[5], x, y)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(self.assets.fonts.medium)
    if lifes < 10 then
        love.graphics.print("0" .. tostring(lifes), x + 11, y + 8)
        return
    end
    love.graphics.print(tostring(lifes), x + 11, y + 8)
end

function GameView:renderPlayArea(x, y, width, height)
    local center = { x = x + width / 2, y = y + height / 2 }
    self:renderRoomCards()
    self:renderPlayerArea({ x = center.x, y = center.y + 64 })
    self.deckView:render()
    self.undoButton:render()
end

function GameView:renderRoomCards()
    for i, cardView in ipairs(self.roomCardViews) do
        cardView:render(self.selectedCardIdx == i)
    end
    if self.selectedCardIdx == -1 then
        return
    end
    self.roomCardViews[self.selectedCardIdx]:render(true)
end

function GameView:renderPlayerArea(center)
    love.graphics.setColor(0, 0, 0, 0.08)
    local x = center.x - PLAYER_AREA_SIZE.width / 2
    local y = center.y - PLAYER_AREA_SIZE.height / 2
    love.graphics.rectangle("fill", x, y, PLAYER_AREA_SIZE.width, PLAYER_AREA_SIZE.height, 10, 10)
    for _, cardView in ipairs(self.playerCards) do
        cardView:render()
    end
end

function GameView:initUndoButton()
    self.undoButton = Button:new({
        x = 16,
        y = 16,
        width = 60,
        height = 30,
        text = "Undo",
        color = {0.4, 0.4, 0.5, 0.9},
        disabled = not self.state.canUndo,
        onClick = function()
            self.eventBus:publish("action", Actions.UndoAction:new())
        end
    }, self.assets, self.mouseProvider)
end

function GameView:updateUndoButton()
    self.undoButton.disabled = not self.state.canUndo
end

return GameView