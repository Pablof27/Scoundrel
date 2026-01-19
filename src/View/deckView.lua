Game = require("src.Controller.game")
Actions = require("src.Controller.playerAction")

local DeckView = { hoovered = false }

function DeckView:new(x, y)
    self.pos = { x = x, y = y - GetQuadDimensions(Frames["cardFrames"][1]).height / 2 + 2 }
    self.size = GetQuadDimensions(Frames["cardFrames"][1])
    return self
end

function DeckView:render()
    local xOffset = 0
    local yOffset = 0
    love.graphics.setColor(0.65, 0.65, 0.65, 1)
    for i = 0, 3 do
        love.graphics.draw(Textures["cardFrames"], Frames["cardFrames"][1], self.pos.x + xOffset, self.pos.y - yOffset)
        xOffset = xOffset + 2
        yOffset = yOffset + 2
    end

    local scale = 1
    if self.hoovered then
        scale = 1.04
        yOffset = yOffset+(scale - 1) * self.size.height / 2
        xOffset = xOffset-(scale - 1) * self.size.width / 2
    end

    love.graphics.setColor(0.85, 0.85, 0.85, 1)
    love.graphics.draw(Textures["cardFrames"], Frames["cardFrames"][1], self.pos.x + xOffset, self.pos.y - yOffset, 0, scale)

    if not self.hoovered then
        return
    end

    local squareSize = self.size.width * 0.75
    xOffset = xOffset + (self.size.width - squareSize) / 2 + (scale - 1) * self.size.width / 2
    yOffset = yOffset - (self.size.height - squareSize) / 2 - (scale - 1) * self.size.height / 2 - 4
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.rectangle("fill", self.pos.x + xOffset, self.pos.y - yOffset, squareSize, squareSize * 0.85, 4, 4)
    love.graphics.setColor(0.9, 0.9, 0.9, 1)
    love.graphics.setFont(Fonts["medium"])
    if Game.gameState.skippedLast then
        love.graphics.printf("No", self.pos.x + xOffset, self.pos.y - yOffset + 3, squareSize, "center")
        love.graphics.printf("Skip", self.pos.x + xOffset, self.pos.y - yOffset + 23, squareSize, "center")
    else
        love.graphics.printf("Skip", self.pos.x + xOffset, self.pos.y - yOffset + 3, squareSize, "center")
        love.graphics.printf("Room", self.pos.x + xOffset, self.pos.y - yOffset + 23, squareSize, "center")
    end

end

function DeckView:update(dt)
    self.hoovered = false
    local mouseX, mouseY = push:toGame(love.mouse.getPosition())
    if self:isInside(mouseX, mouseY) then
        self.hoovered = true
    end
end

function DeckView:isInside(mouseX, mouseY)
    local cardWidth = GetQuadDimensions(Frames["cardFrames"][1]).width
    local cardHeight = GetQuadDimensions(Frames["cardFrames"][1]).height
    local xOffset = 2 * 4
    local yOffset = 2 * 4
    return mouseX >= self.pos.x + xOffset and mouseX <= self.pos.x + xOffset + cardWidth and
           mouseY >= self.pos.y - yOffset and mouseY <= self.pos.y - yOffset + cardHeight
end

return DeckView