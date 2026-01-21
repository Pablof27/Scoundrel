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
    o.actionButtons = self.getActionButtons(o)
    return o
end

function CardView:render()
    if not self.visible then
        return
    end

    local yOffset = 0
    local xOffset = 0
    local scale = 1
    if self.hoovered then
        scale = 1.04
        yOffset = -(scale - 1) * self.size.height / 2
        xOffset = -(scale - 1) * self.size.width / 2
    end

    for _, buttons in ipairs(self.actionButtons) do
        buttons:render()
    end

    local luminosity = 0.9
    love.graphics.setColor(luminosity, luminosity, luminosity, 1)
    love.graphics.draw(Textures["cardFrames"], Frames["cardFrames"][2], self.pos.x + xOffset, self.pos.y + yOffset, 0, scale)
    love.graphics.draw(Textures["pips"], self.quad, self.pos.x + xOffset, self.pos.y + yOffset, 0, scale)
end

function CardView:onSelected()
    if self.targetPos.y < self.anchor.y then
        self:onUnselected()
        return
    end
    self.targetPos.y = self.anchor.y - 64
    for _, button in ipairs(self.actionButtons) do
        button.visible = true
    end
    if #self.actionButtons > 1 and not Game.gameState.player:canUseArmor(self.card) then
        self.actionButtons[2].visible = false
    end
end

function CardView:onUnselected()
    self.targetPos.y = self.anchor.y
    for _, button in ipairs(self.actionButtons) do
        button.visible = false
    end
end

function CardView:onClickButton(mouseX, mouseY)
    if not self.interactive then
        return false
    end
    for _, button in ipairs(self.actionButtons) do
        if button:onMouseClick(mouseX, mouseY) then
            return true
        end
    end
    return false
end

function CardView:update(dt)
    local speed = 10
    self.pos.x = self.pos.x + (self.targetPos.x - self.pos.x) * math.min(dt * speed, 1)
    self.pos.y = self.pos.y + (self.targetPos.y - self.pos.y) * math.min(dt * speed, 1)

    if not self.interactive then
        return
    end

    for _, button in ipairs(self.actionButtons) do
        button:update(dt)
    end

    local mouseX, mouseY = push:toGame(love.mouse.getPosition())
    self.hoovered = self:isInside(mouseX, mouseY)
end

function CardView:isInside(x, y)
    return x >= self.pos.x and x <= self.pos.x + self.size.width and
           y >= self.pos.y and y <= self.pos.y + self.size.height
end

function CardView.getActionButtons(o)
    local card = o.card
    local buttons = {}
    local bWidth = 50
    if card:isDiamond() or card:isHeart() then
        buttons = {
            Button:new({
                x = o.pos.x + o.size.width / 2 - bWidth / 2,
                y = o.pos.y + 36,
                width = bWidth,
                height = 24,
                text = "Play",
                color = {HexToRgb("FFE97F7F")},
                onClick = function ()
                   Game:perform(Actions.PlayCardAction:new(card))
                end,
                visible = false
            })
        }
    end

    if card:isSpade() or card:isClub() then
        buttons = {
            Button:new {
                x = o.pos.x + o.size.width / 2 - bWidth / 2,
                y = o.pos.y + 36,
                width = bWidth,
                height = 24,
                text = "Fight",
                color = {HexToRgb("FFE97F7F")},
                onClick = function()
                    Game:perform(Actions.PlayCardAction:new(card, true))
                end,
                visible = false
            },
            Button:new {
                x = o.pos.x + o.size.width / 2 - (bWidth + 20) / 2,
                y = o.pos.y + 65,
                width = bWidth + 20,
                height = 24,
                text = "No armor",
                color = {HexToRgb("FF6F9BED")},
                onClick = function()
                    Game:perform(Actions.PlayCardAction:new(card, false))
                end,
                visible = false
            }
        }
    end
    return buttons
end

return CardView