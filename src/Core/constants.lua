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

-- UI / Layout
-- The CRT post-process zooms in slightly, so keep important UI inside this margin.
Constants.SAFE_X        = 26
Constants.SAFE_Y        = 16
Constants.SIDEBAR_WIDTH = 160
Constants.ROOM_SPACING  = 12
Constants.STACK_SPACING = 24