
local Player = {}

MAX_LIFES = 20

function Player:new()
    self.lifes = MAX_LIFES
    self.armor = nil
    return self
end

function Player:heal(amount)
    amount = amount or 1
    self.lifes = math.min(self.lifes + amount, MAX_LIFES)
end

function Player:addWeapon(card)

    if self.armor == nil then
        self.armor = {card = card, defendedCards = {}}
        return {}
    end

    local discards = {}
    table.insert(discards, self.armor.card)
    for _, c in ipairs(self.armor.defendedCards) do
        table.insert(discards, c)
    end

    self.armor.card = card
    self.armor.defendedCards = {}

    return discards
end

function Player:takeDamage(card, useArmor)
    if not useArmor then
        self.lifes = self.lifes - card.value
        return card
    end

    table.insert(self.armor.defendedCards, card)
    self.lifes = self.lifes - math.max(0, card.value - self.armor.card.value)
    return {}
end

function Player:render(x, y)
    love.graphics.setColor(0, 0, 0, 0.08)
    love.graphics.rectangle("fill", x, y, 350, 100, 10, 10)
    if self.armor == nil or self.armor.card == nil then
        return
    end
    local spacing = 32
    local n = #self.armor.defendedCards
    local length = GetQuadDimensions(Frames["cardFrames"][1]).width + spacing * n
    local xOffset = (350 - length) / 2
    local yOffset = 3
    self.armor.card:render(x + xOffset, y + yOffset)
    for i, card in ipairs(self.armor.defendedCards) do
        card:render(x + xOffset + spacing * i, y + yOffset)
    end
end

return Player