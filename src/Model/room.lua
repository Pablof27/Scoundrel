--[[
    Room
    Represents the current room of cards the player is interacting with.
]]

local Room = {}
Room.__index = Room

function Room:new(cards)
    local o = setmetatable({}, self)
    o.cards = cards
    o.n = #cards
    return o
end

function Room:replaceCards(cards)
    self.cards = cards
    self.n = #cards
end

function Room:replenishRoom(newCards)
    for _, card in ipairs(newCards) do
        table.insert(self.cards, card)
    end
end

function Room:removeCard(card)
    for i, c in ipairs(self.cards) do
        if c == card then
            table.remove(self.cards, i)
            return true
        end
    end
    return false
end

function Room:shuffledRoom()
    local cards = {}
    for _, card in ipairs(self.cards) do
        table.insert(cards, card)
    end
    table.shuffle(cards)
    return cards
end

function Room:isRoomComplete()
    return #self.cards == self.n
end

return Room