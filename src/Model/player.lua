
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
    if not useArmor or not self:canUseArmor(card) then
        self.lifes = self.lifes - card.value
        return card
    end

    table.insert(self.armor.defendedCards, card)
    self.lifes = self.lifes - math.max(0, card.value - self.armor.card.value)
    return {}
end

function Player:hasArmor()
    return self.armor ~= nil and self.armor.card ~= nil
end

function Player:canUseArmor(card)
    if not self:hasArmor() then
        return false
    end
    if #self.armor.defendedCards == 0 then
        return true
    end
    return self.armor.defendedCards[#self.armor.defendedCards].value > card.value
end

return Player