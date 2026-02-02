
local utils = require("src.utils")
local Card = require("src.Model.card")

local Deck = {}

local suits = {
    heart = 0,
    club = 1,
    diamond = 2,
    spade = 3
}

function Deck:new()
    self.cards = {}
    for i = 0, 3 do
        for value = 2, 14 do
            if (i == suits.heart or i == suits.diamond) and value > 10 then
                goto continue
            end
            table.insert(self.cards, Card:new(i, value))
            ::continue::
        end
    end
    self:shuffle()
    return self
end

function Deck:shuffle()
    table.shuffle(self.cards)
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

function Deck:render(x, y)
    
end

return Deck