local Button = require("src.View.buttonView")

local CardView = {}

function CardView:new(card, x, y, interactive, visible)
    local o = {}
    setmetatable(o, self)
    self.__index = self

    o.card = card
    o.pos = { x = x, y = y }
    o.targetPos = { x = x, y = y }
    o.anchor = { x = x, y = y}
    o.size = GetQuadDimensions(Frames["cardFrames"][1])
    o.quad = Frames["pips"][card.position]
    o.hoovered = false
    o.interactive = interactive ~= false
    o.visible = visible ~= false
    o.actionButtons = {
        Button:new {
            x = o.pos.x + o.size.width / 2 - 20,
            y = o.pos.y + 36,
            width = 40,
            height = 24,
            text = "Play",
            color = {HexToRgb("FFE97F7F")},
            onClick = function()
                Game:perform(Actions.PlayCardAction:new(card))
            end
        },
        Button:new {
            x = o.pos.x + o.size.width / 2 - 20,
            y = o.pos.y + 65,
            width = 40,
            height = 24,
            text = "Info",
            color = {HexToRgb("FF6F9BED")},
            onClick = function()
                -- Placeholder for info action
            end,
            visible = card.suit ~= 0 and card.suit ~= 2
        }
    }
    return o
end

function CardView:render()
    if not self.visible then
        return
    end

    self:drawActionButtons()

    local yOffset = 0
    local xOffset = 0
    local scale = 1
    if self.hoovered then
        scale = 1.04
        yOffset = -(scale - 1) * self.size.height / 2
        xOffset = -(scale - 1) * self.size.width / 2
    end

    local luminosity = 0.9
    love.graphics.setColor(luminosity, luminosity, luminosity, 1)
    love.graphics.draw(Textures["cardFrames"], Frames["cardFrames"][2], self.pos.x + xOffset, self.pos.y + yOffset, 0, scale)
    love.graphics.draw(Textures["pips"], self.quad, self.pos.x + xOffset, self.pos.y + yOffset, 0, scale)
end

function CardView:drawActionButtons()
    if Game.gameState.player.armor == nil then
        self.actionButtons[2].visible = false
    end
    for _, button in ipairs(self.actionButtons) do
        button:render()
    end
end

function CardView:onClickButtons(mouseX, mouseY)
    for _, button in ipairs(self.actionButtons) do
        button:onMouseClick(mouseX, mouseY)
    end
end

function CardView:onClick(i)
    if i == -1 then
        self.targetPos.y = self.anchor.y
        return
    end
    self.targetPos.y = self.anchor.y - 64
end

function CardView:update(dt)
    local speed = 10
    self.pos.x = self.pos.x + (self.targetPos.x - self.pos.x) * math.min(dt * speed, 1)
    self.pos.y = self.pos.y + (self.targetPos.y - self.pos.y) * math.min(dt * speed, 1)

    if not self.interactive then
        return
    end
    -- if self.pos.x - self.targetPos.x >= 0.1 or self.pos.y - self.targetPos.y >= 0.1 then
    --     return
    -- end

    self.hoovered = false
    local mouseX, mouseY = push:toGame(love.mouse.getPosition())
    if self:isInside(mouseX, mouseY) then
        self.hoovered = true
    end
end

function CardView:isInside(x, y)
    return x >= self.pos.x and x <= self.pos.x + self.size.width and
           y >= self.pos.y and y <= self.pos.y + self.size.height
end

return CardView