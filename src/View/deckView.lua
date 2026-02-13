--[[
    DeckView
    Renders the draw pile and handles next-room/skip-room clicks.
    Receives assets, eventBus, mouseProvider, and gameStateQuery.
    No global dependencies.
]]

local Actions = require("src.Controller.playerAction")

local DeckView = {}
DeckView.__index = DeckView

function DeckView:new(x, y, context)
    local o = setmetatable({}, self)
    o.assets          = context.assets
    o.eventBus        = context.eventBus
    o.mouseProvider   = context.mouseProvider
    o.gameStateQuery  = context.gameStateQuery
    o.size     = o.assets:getCardSize()
    o.pos      = { x = x, y = y - o.size.height / 2 + 2 }
    o.hoovered = false
    return o
end

function DeckView:render()
    local xOffset = 0
    local yOffset = 0
    love.graphics.setColor(0.65, 0.65, 0.65, 1)
    for i = 0, 3 do
        love.graphics.draw(self.assets.textures.cardFrames, self.assets.frames.cardFrames[1], self.pos.x + xOffset, self.pos.y - yOffset)
        xOffset = xOffset + 2
        yOffset = yOffset + 2
    end

    local scale = 1
    if self.hoovered then
        scale = 1.04
        yOffset = yOffset + (scale - 1) * self.size.height / 2
        xOffset = xOffset - (scale - 1) * self.size.width / 2
    end

    love.graphics.setColor(0.85, 0.85, 0.85, 1)
    love.graphics.draw(self.assets.textures.cardFrames, self.assets.frames.cardFrames[1], self.pos.x + xOffset, self.pos.y - yOffset, 0, scale)

    if not self.hoovered then
        return
    end

    local squareSize = self.size.width * 0.75
    xOffset = xOffset + (self.size.width - squareSize) / 2 + (scale - 1) * self.size.width / 2
    yOffset = yOffset - (self.size.height - squareSize) / 2 - (scale - 1) * self.size.height / 2 - 4
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.rectangle("fill", self.pos.x + xOffset, self.pos.y - yOffset, squareSize, squareSize * 0.85, 4, 4)
    love.graphics.setColor(0.9, 0.9, 0.9, 1)
    love.graphics.setFont(self.assets.fonts.medium)

    local gameState = self.gameStateQuery()
    if gameState:canGoNextRoom() then
        love.graphics.printf("Next", self.pos.x + xOffset, self.pos.y - yOffset + 3, squareSize, "center")
        love.graphics.printf("Room", self.pos.x + xOffset, self.pos.y - yOffset + 23, squareSize, "center")
        return
    end
    if gameState:canSkipRoom() then
        love.graphics.printf("Skip", self.pos.x + xOffset, self.pos.y - yOffset + 3, squareSize, "center")
        love.graphics.printf("Room", self.pos.x + xOffset, self.pos.y - yOffset + 23, squareSize, "center")
        return
    end
    love.graphics.printf("No", self.pos.x + xOffset, self.pos.y - yOffset + 3, squareSize, "center")
    love.graphics.printf("Skip", self.pos.x + xOffset, self.pos.y - yOffset + 23, squareSize, "center")
end

function DeckView:onClick(mouseX, mouseY)
    if not self:isInside(mouseX, mouseY) then
        return false
    end
    local gameState = self.gameStateQuery()
    if gameState:canGoNextRoom() then
        self.eventBus:publish("action", Actions.NextRoomAction:new())
        return true
    end
    if gameState:canSkipRoom() then
        self.eventBus:publish("action", Actions.SkipRoomAction:new())
        return true
    end
    return true
end

function DeckView:update(dt)
    self.hoovered = false
    local mouseX, mouseY = self.mouseProvider()
    if self:isInside(mouseX, mouseY) then
        self.hoovered = true
    end
end

function DeckView:isInside(mouseX, mouseY)
    local cardWidth = self.size.width
    local cardHeight = self.size.height
    local xOffset = 2 * 4
    local yOffset = 2 * 4
    return mouseX >= self.pos.x + xOffset and mouseX <= self.pos.x + xOffset + cardWidth and
           mouseY >= self.pos.y - yOffset and mouseY <= self.pos.y - yOffset + cardHeight
end

return DeckView