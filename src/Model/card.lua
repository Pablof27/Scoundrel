
local Card = {}

local values = {
   "2", "3", "4", "5", "6", "7", "8", "9", "T",
   "J", "Q", "K", "A"
}

function Card:new(suit, value)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.value = value
    o.suit = suit
    o.position = value - 1 + 13 * suit
    return o
end

function Card:isHeart()
    return self.suit == 0
end

function Card:isClub()
    return self.suit == 1
end

function Card:isDiamond()
    return self.suit == 2
end

function Card:isSpade()
    return self.suit == 3
end

function Card.__eq(card1, card2)
    return card1.value == card2.value and card1.suit == card2.suit
end

return Card