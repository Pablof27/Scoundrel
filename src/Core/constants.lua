--[[
    Constants
    Single source of truth for all game configuration values.
]]

Constants = {}

-- Display
Constants.WIDTH  = 400 * 16 / 9
Constants.HEIGHT = 400
Constants.SCALE  = 2

-- Background shader colours
Constants.BACKGROUND_COLOR1 = "FF56CDAD"
Constants.BACKGROUND_COLOR2 = "FF428D74"
Constants.BACKGROUND_COLOR3 = "FF3A594D"
Constants.BACKGROUND_COLOR  = "FF57695C"

-- Gameplay
Constants.MAX_LIFES      = 20
Constants.CARDS_PER_ROOM = 4

-- UI / Layout
Constants.ROOM_SPACING        = 8
Constants.PLAYER_AREA_SIZE    = { width = 350, height = 100 }
Constants.PLAYER_AREA_SPACING = 32