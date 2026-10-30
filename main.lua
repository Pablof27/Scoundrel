--[[
    main.lua — Composition Root
    This is the single place where all modules are wired together.
    No other module imports from here; all dependencies flow downward.
    Screens never know about each other: they ask for navigation by publishing
    "navigate" events, which are resolved here. The game being played (one of src/Games)
    is picked on the library screen and handed to the screens that depend on it.
]]

require("src.Core.utils")
require("src.Core.constants")

local push  = require("lib.push")
local Timer = require("lib.timer")

local AssetManager = require("src.Core.AssetManager")
local EventBus     = require("src.Core.EventBus")
local Settings     = require("src.Core.settings")
local Records      = require("src.Core.records")

local Game       = require("src.Controller.game")
local StateStack = require("src.Controller.stateStack")
local Games      = require("src.Games")

local LibraryView    = require("src.View.states.libraryView")
local MenuView       = require("src.View.states.menuView")
local PauseView      = require("src.View.states.pauseView")
local RulesView      = require("src.View.states.rulesView")
local SettingsView   = require("src.View.states.settingsView")
local EndGameView    = require("src.View.states.endGameView")
local TransitionView = require("src.View.states.transitionView")

local assets
local eventBus
local settings
local records     -- game id -> Records
local game
local stateStack
local transition
local context
local lastRecord
local activeGame  -- descriptor of the game picked in the library, nil on the library screen

local function mouseProvider()
    local x, y = push:toGame(love.mouse.getPosition())
    -- push returns nil outside the game area (letterbox bars in fullscreen)
    return x or -1, y or -1
end

-- Fades out, replaces every screen with the ones built by `buildScreens`, then fades back in.
local function transitionTo(buildScreens)
    if transition then
        return
    end
    transition = TransitionView:new(function()
        stateStack:clear()
        buildScreens()
    end, function()
        transition = nil
    end)
end

-- New games use the rules currently chosen in the settings (e.g. Scoundrel's difficulty).
local function startGame()
    transitionTo(function()
        game:start(activeGame.newState(settings))
        stateStack:push(activeGame.newView(context, game.gameState))
    end)
end

-- Home screen of the game being played.
local function showMenu()
    transitionTo(function()
        stateStack:push(MenuView:new(context, activeGame))
    end)
end

local function showLibrary()
    transitionTo(function()
        activeGame = nil
        stateStack:push(LibraryView:new(context, Games))
    end)
end

local function selectGame(id)
    if transition then
        return
    end
    activeGame = Games.byId[id]
    showMenu()
end

local navigation = {
    library    = showLibrary,
    selectGame = selectGame,
    menu       = showMenu,
    newGame    = startGame,
    pause      = function() stateStack:push(PauseView:new(context, activeGame)) end,
    rules      = function() stateStack:push(RulesView:new(context, activeGame)) end,
    settings   = function() stateStack:push(SettingsView:new(context, activeGame)) end,
    back       = function() stateStack:pop() end,
    endGame    = function(result) stateStack:push(EndGameView:new(context, activeGame, result, lastRecord)) end,
    quit       = function() love.event.quit() end,
}

local function onSettingChanged(key, value)
    if key == "fullscreen" and (love.window.getFullscreen()) ~= value then
        push:switchFullscreen()
    elseif key == "cardBack" then
        assets.cardBack = value
    elseif key == "music" then
        assets.audio:setMusicVolume(value)
    elseif key == "sound" then
        assets.audio:setSoundVolume(value)
    end
end

local function displayFPS()
    love.graphics.setColor(1, 1, 1, 0.8)
    assets.fonts.tiny:print("FPS: " .. tostring(love.timer.getFPS()), assets.WIDTH - 44, 2)
end

function love.load()
    -- The save directory predates the library: it keeps its name so saved settings and records stay.
    love.filesystem.setIdentity("scoundrel")
    love.graphics.setDefaultFilter("nearest", "nearest")
    love.window.setTitle(Constants.TITLE)
    love.window.setIcon(love.image.newImageData("resources/icon.png"))
    math.randomseed(os.time())

    assets = AssetManager:new()
    assets:load()

    eventBus = EventBus:new()
    settings = Settings:new(eventBus, Games.options())
    records  = {}
    for _, g in ipairs(Games) do
        records[g.id] = Records:new(g.records.file, g.records.defaults)
    end
    assets.cardBack = settings:get("cardBack")
    assets.audio:setSoundVolume(settings:get("sound"))
    assets.audio:setMusicVolume(settings:get("music"))

    game = Game:new(eventBus)
    stateStack = StateStack:new()
    context = {
        assets        = assets,
        eventBus      = eventBus,
        settings      = settings,
        records       = records,
        mouseProvider = mouseProvider,
    }

    eventBus:subscribe("navigate", function(target, payload)
        navigation[target](payload)
    end)
    eventBus:subscribe("endGame", function(didWin, gameState)
        lastRecord = activeGame.registerResult(records[activeGame.id], didWin, gameState)
    end)
    eventBus:subscribe("settingChanged", onSettingChanged)

    push:setupScreen(assets.WIDTH, assets.HEIGHT, assets.WIDTH * assets.SCALE, assets.HEIGHT * assets.SCALE, {
        vsync = true,
        fullscreen = false,
        -- On the web the canvas follows the size of the page (see web/index.html).
        resizable = Constants.IS_WEB
    })
    if Constants.IS_WEB then
        -- The canvas takes the page's size when the window is created, without a resize event.
        push:resize(love.graphics.getDimensions())
    end
    if settings:get("fullscreen") then
        push:switchFullscreen()
    end

    stateStack:push(LibraryView:new(context, Games))
end

function love.update(dt)
    dt = math.min(dt, 1 / 20)
    local animationDt = dt * settings:get("animSpeed")
    assets:update(dt)
    Timer.update(animationDt)
    stateStack:update(animationDt)
end

function love.mousepressed(x, y, button)
    if transition then
        return
    end
    local mouseX, mouseY = push:toGame(x, y)
    if mouseX and mouseY then
        stateStack:onMouseClick(mouseX, mouseY, button)
    end
end

function love.keypressed(key)
    if transition then
        return
    end
    stateStack:onKeyPressed(key)
end

function love.resize(width, height)
    push:resize(width, height)
end

function love.draw()
    push:apply("start")
    -- push renders at the screen's pixel density (it changes with the window size and the screen),
    -- and the text must be rasterized at that same density.
    assets:setPixelDensity(push:getPixelDensity())

    stateStack:render()
    if transition then
        transition:render()
    end
    if settings:get("showFps") then
        displayFPS()
    end

    push:apply("end", settings:get("crt") and assets.shaders.CRT or nil)
end
