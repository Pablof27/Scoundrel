--[[
    Lobo configuration: deck, dealing and match rules.
]]

local Config = {}

Config.HAND_SIZE     = 4  -- cards dealt to you and to the Wolf
Config.SUITS         = 5  -- aces (worth 1) to 10 in each suit: 50 cards
Config.SHUFFLE_EVERY = 3  -- hands dealt from one shuffle (the house rule)

-- Points that win a match: the rules' 100, or a shorter match. Chosen in the settings.
Config.TARGETS        = { 100, 50 }
Config.TARGET_NAMES   = { "100 points", "50 points" }
Config.TARGET_DETAILS = {
    "The classic match: hands are played until you or the Wolf reach 100 points.",
    "A shorter match: the first to reach 50 points wins.",
}
Config.DEFAULT_TARGET = 100

return Config
