--[[
    main.lua — Composition Root
    This is the single place where all modules are wired together.
    No other module imports from here; all dependencies flow downward.
]]

require("src.Core.utils")
require("src.Core.constants")

local push  = require("lib.push")
local Timer = require("lib.timer")

local AssetManager = require("src.Core.AssetManager")
local EventBus     = require("src.Core.EventBus")

local Game       = require("src.Controller.game")
local StateStack = require("src.Controller.stateStack")
local Actions    = require("src.Controller.playerAction")

local GameView       = require("src.View.states.gameView")
local EndGameView    = require("src.View.states.endGameView")
local TransitionView = require("src.View.states.transitionView")
local assets
local eventBus
local game
local stateStack
local gameView

local function mouseProvider()
    return push:toGame(love.mouse.getPosition())
end

local function gameStateQuery()
    return game.gameState
end

local function startGame()
    game:start()

    gameView = GameView:new()
    gameView:init(game.gameState, assets, eventBus, mouseProvider, gameStateQuery)

    stateStack = StateStack:new()
    stateStack:push(gameView)
end

local function startTransition(onMidpoint, onComplete)
    stateStack:push(TransitionView:new(onMidpoint, onComplete))
end

local function restartGame()
    startTransition(
        function()
            if gameView then
                gameView:destroy()
            end
            game:start()
            gameView = GameView:new()
            gameView:init(game.gameState, assets, eventBus, mouseProvider, gameStateQuery)
            stateStack.stack[1] = gameView
        end,
        function()
            stateStack:pop()
        end
    )
end

local function showEndGame(didWin)
    startTransition(
        function()
            -- Pass restartGame as callback to EndGameView
            stateStack.stack[1] = EndGameView:new(didWin, restartGame, assets)
        end,
        function()
            stateStack:pop()
        end
    )
end

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    love.window.setTitle("Scoundrel")
    math.randomseed(os.time())

    assets = AssetManager:new()
    assets:load()

    eventBus = EventBus:new()

    game = Game:new(eventBus)
    eventBus:subscribe("endGame", showEndGame)

    startGame()

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