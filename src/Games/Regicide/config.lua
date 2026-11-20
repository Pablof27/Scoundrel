--[[
    Regicide configuration: deck sizes, royal stats, suit powers and victory tiers.
]]

local Card = require("src.Model.card")

local Config = {}

Config.HAND_SIZE = 8

-- Royals in the Castle deck: rank -> { name, plural, attack, health }
Config.ROYALS = {
    [11] = { name = "Jack",  plural = "Jacks",  attack = 10, health = 20 },
    [12] = { name = "Queen", plural = "Queens", attack = 15, health = 30 },
    [13] = { name = "King",  plural = "Kings",  attack = 20, health = 40 },
}
Config.ROYAL_RANKS = { 11, 12, 13 }
Config.TOTAL_ROYALS = 12

-- Suit order in the sidebar and rules. Note: when resolving powers, Hearts always go before Diamonds.
Config.SUITS = {
    { suit = Card.SUITS.HEART,   name = "Hearts",   icon = "heart",   color = "heal",   short = "Heal discard" },
    { suit = Card.SUITS.DIAMOND, name = "Diamonds", icon = "diamond", color = "blue",   short = "Draw cards" },
    { suit = Card.SUITS.CLUB,    name = "Clubs",    icon = "club",    color = "orange", short = "Double damage" },
    { suit = Card.SUITS.SPADE,   name = "Spades",   icon = "spade",   color = "purple", short = "Shield attack" },
}

Config.SUIT_BY_ID = {}
for _, info in ipairs(Config.SUITS) do
    Config.SUIT_BY_ID[info.suit] = info
end

-- Starting Solo Jesters, chosen in Settings.
Config.JESTER_COUNTS  = { 2, 1, 0 }
Config.JESTER_NAMES   = { "2 (Standard)", "1 (Silver)", "0 (Gold)" }
Config.JESTER_DETAILS = {
    "Standard solo rules: two Jesters set aside. Flip one before attacking or defending to discard your hand and draw 8 cards.",
    "Start with only one Jester: every win is at least a Silver Victory.",
    "No Jesters at all: no second chances, and every win is a Gold Victory.",
}
Config.DEFAULT_JESTERS = 2

-- Victory tier by Jesters used (3 = Gold, 2 = Silver, 1 = Bronze).
Config.TIERS = {
    [3] = { name = "Gold",   title = "GOLD VICTORY!",   color = "gold" },
    [2] = { name = "Silver", title = "SILVER VICTORY!", color = "blue" },
    [1] = { name = "Bronze", title = "BRONZE VICTORY!", color = "orange" },
}

function Config.tierForJokersUsed(used)
    if used <= 0 then
        return 3
    elseif used == 1 then
        return 2
    end
    return 1
end

return Config
