--[[
    Player
    Manages health, armor, and damage calculations.
]]

local Player = {}
Player.__index = Player

local MAX_LIFES = Constants.MAX_LIFES

function Player:new()
    local o = setmetatable({}, self)
    o.lifes = MAX_LIFES
    o.armor = nil
    return o
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

-- Damage a monster would deal, and whether the weapon would be used against it.
function Player:damageFrom(card, useArmor)
    if useArmor and self:canUseArmor(card) then
        return math.max(0, card.value - self.armor.card.value), true
    end
    return card.value, false
end

-- Returns the discarded cards, the damage taken and whether the weapon was used.
function Player:takeDamage(card, useArmor)
    local damage, usedArmor = self:damageFrom(card, useArmor)
    self.lifes = self.lifes - damage
    if usedArmor then
        table.insert(self.armor.defendedCards, card)
        return {}, damage, true
    end
    return { card }, damage, false
end

-- Monsters must be strictly below this value to be fought with the weapon (nil = any monster).
function Player:armorLimit()
    if not self:hasArmor() or #self.armor.defendedCards == 0 then
        return nil
    end
    return self.armor.defendedCards[#self.armor.defendedCards].value
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