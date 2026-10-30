--[[
    Deck
    A pile of cards, top first. Each game builds the cards it plays with.
]]

local Deck = {}
Deck.__index = Deck

-- cards: list of Card, top first (not shuffled).
function Deck:new(cards)
    local o = setmetatable({}, self)
    o.cards = cards or {}
    return o
end

function Deck:shuffle()
    table.shuffle(self.cards)
end

function Deck:top()
    return self.cards[1]
end

function Deck:drawCards(n)
    local drawnCards = {}
    for i = 1, n do
        if #self.cards == 0 then
            break
        end
        table.insert(drawnCards, table.remove(self.cards, 1))
    end
    return drawnCards
end

function Deck:addToBottom(cards)
    for _, card in ipairs(cards) do
        table.insert(self.cards, card)
    end
end

function Deck:isEmpty()
    return #self.cards == 0
end

function Deck:remainingCards()
    return #self.cards
end

return Deck
