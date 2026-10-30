--[[
    Card
    A playing card. Shared by every game, which give the suits and values their meaning.
      suit:     0 hearts, 1 clubs, 2 diamonds, 3 spades, 4 gold spades (an extra suit, see AssetManager)
      rank:     printed rank, 2-14 (J = 11, Q = 12, K = 13, A = 14). It picks the card's sprite.
      value:    what the card is worth in the game; the rank unless the game says otherwise
                (e.g. Lobo counts aces as 1).
      position: unique per suit and rank. It identifies the card and its cell in the card atlas.
]]

local Card = {}
Card.__index = Card

Card.SUITS = { HEART = 0, CLUB = 1, DIAMOND = 2, SPADE = 3, GOLD_SPADE = 4 }
Card.ACE = 14

function Card:new(suit, rank, value)
    local o = setmetatable({}, self)
    o.suit     = suit
    o.rank     = rank
    o.value    = value or rank
    o.position = rank - 1 + 13 * suit
    return o
end

function Card:isHeart()
    return self.suit == Card.SUITS.HEART
end

function Card:isClub()
    return self.suit == Card.SUITS.CLUB
end

function Card:isDiamond()
    return self.suit == Card.SUITS.DIAMOND
end

function Card:isSpade()
    return self.suit == Card.SUITS.SPADE
end

function Card.__eq(card1, card2)
    return card1.rank == card2.rank and card1.suit == card2.suit
end

return Card
