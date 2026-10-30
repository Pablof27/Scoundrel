--[[
    Constants
    Single source of truth for all game configuration values.
]]

Constants = {}

-- Display
Constants.WIDTH  = 400 * 16 / 9
Constants.HEIGHT = 400
Constants.SCALE  = 2

-- Browser build (love.js, see web/): the page owns the window, so the game can't quit or go fullscreen.
Constants.IS_WEB = love.system.getOS() == "Web"

-- Background shader colours
Constants.BACKGROUND_COLOR1 = "FF56CDAD"
Constants.BACKGROUND_COLOR2 = "FF428D74"
Constants.BACKGROUND_COLOR3 = "FF3A594D"
Constants.BACKGROUND_COLOR  = "FF57695C"

-- Gameplay
Constants.MAX_LIFES      = 20
Constants.CARDS_PER_ROOM = 4

--[[
    Difficulty levels, easiest first. Chosen in the settings (by `key`) and applied when a run starts.
      clearDungeon:     every card must be resolved to escape. Otherwise the run is won as soon as the
                        room needs refilling and the dungeon has too few cards left to fill it.
      weaponSlaysEqual: weapons can also slay a monster as strong as the last one they slew.
      ranked:           the run can set a new best score.
      color:            UI.colors entry used to tag the difficulty.
]]
Constants.DIFFICULTIES = {
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
-- Each level is also reachable by its key, e.g. Constants.DIFFICULTIES.easy.
for _, difficulty in ipairs(Constants.DIFFICULTIES) do
    Constants.DIFFICULTIES[difficulty.key] = difficulty
end
Constants.DEFAULT_DIFFICULTY = "difficult"

-- UI / Layout
-- The CRT post-process zooms in slightly, so keep important UI inside this margin.
Constants.SAFE_X        = 26
Constants.SAFE_Y        = 16
Constants.SIDEBAR_WIDTH = 160
Constants.ROOM_SPACING  = 12
Constants.STACK_SPACING = 24