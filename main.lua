--[[
    main.lua — Composition Root
    This is the single place where all modules are wired together.
    No other module imports from here; all dependencies flow downward.
]]

-- Utility functions used across the project (table.shuffle, HexToRgb, etc.)
require("src.Core.utils")
require("src.Core.constants")

-- External libraries
local push  = require("lib.push")
local Timer = require("lib.timer")

-- Core infrastructure
local AssetManager = require("src.Core.AssetManager")
local EventBus     = require("src.Core.EventBus")

-- Controller
local Game       = require("src.Controller.game")
local StateStack = require("src.Controller.stateStack")
local Actions    = require("src.Controller.playerAction")

-- Views
local GameView    = require("src.View.states.gameView")
local EndGameView = require("src.View.states.endGameView")

-- Module-level references (local, not global)
local assets
local eventBus
local game
local stateStack
local gameView

-- Provides normalised mouse position; injected into Views so they don't depend on `push`
local function mouseProvider()
    return push:toGame(love.mouse.getPosition())
end

-- Returns the current game state; injected into Views so they don't depend on `game`
local function gameStateQuery()
    return game.gameState
end

-- Start (or restart) a full game session
local function startGame()
    game:start()

    gameView = GameView:new()
    gameView:init(game.gameState, assets, eventBus, mouseProvider, gameStateQuery)

    stateStack = StateStack:new()
    stateStack:push(gameView)
end

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    love.window.setTitle("Scoundrel")
    math.randomseed(os.time())

    -- 1. Load assets
    assets = AssetManager:new()
    assets:load()

    -- 2. Create the event bus
    eventBus = EventBus:new()

    -- 3. Create the game controller (subscribes to "action" events internally)
    game = Game:new(eventBus)

    -- 4. Subscribe to end-game events
    eventBus:subscribe("endGame", function(didWin)
        stateStack:pop()
        stateStack:push(EndGameView:new(didWin, function()
            stateStack:pop()
            startGame()
        end, assets))
    end)

    -- 5. Start the first game session
    startGame()

    -- 6. Set up the virtual screen
    push:setupScreen(assets.WIDTH, assets.HEIGHT, assets.WIDTH * assets.SCALE, assets.HEIGHT * assets.SCALE, {
        vsync = true,
        fullscreen = false,
        resizable = false
    })
end

function love.update(dt)
    assets:updateShaderTime()
    Timer.update(dt)
    stateStack:update(dt)
end

function love.mousepressed(x, y, button)
    local mouseX, mouseY = push:toGame(x, y)
    stateStack:onMouseClick(mouseX, mouseY)
end

function love.draw()
    push:apply("start")

    stateStack:render()
    displayFPS()

    push:apply("end", assets.shaders.CRT)
end

function displayFPS()
    love.graphics.setFont(assets.fonts.small)
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.print("FPS: " .. tostring(love.timer.getFPS()), 15, 10)
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
    if key == "u" then
        print("Undoing last action")
        eventBus:publish("action", Actions.UndoAction:new())
    end
end