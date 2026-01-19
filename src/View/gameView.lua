
CardView = require("src.View.cardView")
DeckView = require("src.View.deckView")

local GameView = {}

ROOM_SPACING = 8
PLAYER_AREA_SIZE = { width = 350, height = 100 }
PLAYER_AREA_SPACING = 32

function GameView:init(game)
    self.lifes = game.player.lifes
    GameView:initPlayArea(0, 16, WIDTH, HEIGHT - 16, game.room, game.player)
    self.selectedCardIdx = -1
end

function GameView:onRoomChanged(game)
    self.selectedCardIdx = -1
    local x, y, width, height = 0, 16, WIDTH, HEIGHT - 16
    GameView:initRoomCardViews(game.room, { x = x + width / 2, y = y + height / 2 - 64 })
end

function GameView:onPlayerChanged(game)
    self.lifes = game.player.lifes
    self.selectedCardIdx = -1
    local x, y, width, height = 0, 16, WIDTH, HEIGHT - 16
    GameView:initPlayerCardViews(game.player.armor, { x = x + width / 2, y = y + height / 2 + 64 })
end

function GameView:render()
    GameView.renderBackground()
    GameView.renderLifes(self.lifes)
    GameView:renderPlayArea(0, 16, WIDTH, HEIGHT - 16)
end

function GameView:update(dt)
    for i, cardView in ipairs(self.roomCardViews) do
        cardView:update(dt)
    end
    self.deckView:update(dt)
end

function GameView:onMouseClick(mouseX, mouseY)
    for i, cardView in ipairs(self.roomCardViews) do
        cardView.targetPos.y = cardView.anchor.y
        if cardView.visible and cardView:isInside(mouseX, mouseY) then
            self.selectedCardIdx = i == self.selectedCardIdx and -1 or i
            cardView:onClick(self.selectedCardIdx)
        end
    end
end

function GameView:initPlayArea(x, y, width, height, room, player)
    local center = { x = x + width / 2, y = y + height / 2  }
    GameView:initRoomCardViews(room, { x = center.x, y = center.y - 64 })
    GameView:initPlayerCardViews(player.armor, { x = center.x, y = center.y + 64 })
    self.deckView = DeckView:new(center.x + PLAYER_AREA_SIZE.width / 2 + 16, center.y + 64)
end

function GameView:initRoomCardViews(room, center)
    local size = GetQuadDimensions(Frames["cardFrames"][1])
    local spacing = ROOM_SPACING + size.width
    local xOffset =  (spacing * (room.n - 1) + size.width) / 2
    local yOffset = size.height / 2
    self.roomCardViews = {}
    for i, card in ipairs(room.cards) do
        local x = center.x - xOffset
        local y = center.y - yOffset
        table.insert(self.roomCardViews, CardView:new(card, x, y))
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
    local length = GetQuadDimensions(Frames["cardFrames"][1]).width + PLAYER_AREA_SPACING * n
    local xOffset = (PLAYER_AREA_SIZE.width - length) / 2
    local yOffset = 3
    self.playerCards = {}
    table.insert(self.playerCards, CardView:new(armor.card, x + xOffset, y + yOffset, false))
    xOffset = xOffset + PLAYER_AREA_SPACING
    for _, card in ipairs(armor.defendedCards) do
        table.insert(self.playerCards, CardView:new(card, x + xOffset, y + yOffset, false))
        xOffset = xOffset + PLAYER_AREA_SPACING
    end
end

function GameView.renderBackground()
    love.graphics.setShader(Shaders["background"])
    love.graphics.rectangle("fill", 0, 0, WIDTH, HEIGHT)
    love.graphics.setShader()
end

function GameView.renderLifes(lifes)
    local x = WIDTH - 74
    local y = 16
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.draw(Textures["ui_assets"], Frames["ui_assets"][5], x, y)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(Fonts["medium"])
    love.graphics.print(tostring(lifes), x + 11, y + 8)
end

function GameView:renderPlayArea(x, y, width, height)
    local center = { x = x + width / 2, y = y + height / 2  }
    self:renderRoomCards()
    self:renderPlayerArea({ x = center.x, y = center.y + 64 })
    self.deckView:render()
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

return GameView