--[[
    Scoundrel configuration: rule values, layout spacing and difficulty levels.
]]

local Config = {}

Config.MAX_LIFES      = 20
Config.CARDS_PER_ROOM = 4

-- Layout of the board
Config.ROOM_SPACING  = 12
Config.STACK_SPACING = 24

--[[
    Difficulty levels, easiest first. Chosen in the settings (by `key`) and applied when a run starts.
      clearDungeon:     every card must be resolved to escape. Otherwise the run is won as soon as the
                        room needs refilling and the dungeon has too few cards left to fill it.
      weaponSlaysEqual: weapons can also slay a monster as strong as the last one they slew.
      ranked:           the run can set a new best score.
      color:            UI.colors entry used to tag the difficulty.
]]
Config.DIFFICULTIES = {
    { key = "easy", name = "Easy", color = "green",
      clearDungeon = false, weaponSlaysEqual = true, ranked = false,
      description = "You escape when the dungeon has too few cards left to fill the next room. " ..
          "Weapons also slay monsters as strong as the last one they slew." },
    { key = "normal", name = "Normal", color = "blue",
      clearDungeon = false, weaponSlaysEqual = false, ranked = false,
      description = "You escape when the dungeon has too few cards left to fill the next room." },
    { key = "difficult", name = "Difficult", color = "red",
      clearDungeon = true, weaponSlaysEqual = false, ranked = true,
      description = "The classic rules: resolve every card of the dungeon to escape. " ..
          "Only Difficult runs can set a best score." },
}
-- Each level is also reachable by its key, e.g. Config.DIFFICULTIES.easy.
for _, difficulty in ipairs(Config.DIFFICULTIES) do
    Config.DIFFICULTIES[difficulty.key] = difficulty
end
Config.DEFAULT_DIFFICULTY = "difficult"

function Config.difficulty(key)
    return Config.DIFFICULTIES[key] or Config.DIFFICULTIES[Config.DEFAULT_DIFFICULTY]
end

return Config
