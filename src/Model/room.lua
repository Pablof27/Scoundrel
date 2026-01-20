

local _ = require("src.utils")
local Room = {}

function Room:new(cards)
    self.cards = cards
    self.n = #cards
    return self
end

function Room:replenishRoom(newCards)
    if #newCards + 1 ~= self.n then
        error("Replenish room must receive exactly " .. (self.n - #newCards) .. " cards")
    end

    self.cards = {}
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