
_ = require("src.dependencies")
Game = require("src.Controller.game")
StateStack = require("src.Controller.stateStack")

local GameView = require("src.View.states.gameView")

local function setupShaders()
    Shaders["background"]:send("colour_1", {HexToRgb(BACKGROUND_COLOR1)})
    Shaders["background"]:send("colour_2", {HexToRgb(BACKGROUND_COLOR2)})
    Shaders["background"]:send("colour_3", {HexToRgb(BACKGROUND_COLOR3)})
    Shaders["background"]:send("contrast", 1)
    Shaders["background"]:send("spin_amount", 0.1)
    Shaders["CRT"]:send("distortion_fac", {1.02, 1.02})
    Shaders["CRT"]:send("scale_fac", {0.95, 0.95})
    Shaders["CRT"]:send("feather_fac", 0.02)
    Shaders["CRT"]:send("noise_fac", 0.001)
    Shaders["CRT"]:send("bloom_fac", 0.0)
    Shaders["CRT"]:send("crt_intensity", 0.03)
    Shaders["CRT"]:send("glitch_intensity", 0)
    Shaders["CRT"]:send("scanlines", 450.0)
end

function love.load()

    love.graphics.setDefaultFilter('nearest', 'nearest')
    Game:start(GameView)

    love.window.setTitle("Scoundrel")

    math.randomseed(os.time())

    Textures = {
        ["pips"] = love.graphics.newImage("resources/8BitDeck_small.png"),
        ["cardFrames"] = love.graphics.newImage("resources/Enhancers.png"),
        ["ui_assets"] = love.graphics.newImage("resources/ui_assets.png")
    }

    Frames = {
        ["pips"] = GenerateQuads(Textures["pips"], Textures["pips"]:getWidth() / 13, Textures["pips"]:getHeight() / 4),
        ["cardFrames"] = GenerateQuads(Textures["cardFrames"], Textures["cardFrames"]:getWidth() / 7, Textures["cardFrames"]:getHeight() / 5),
        ["ui_assets"] = GenerateQuads(Textures["ui_assets"], Textures["ui_assets"]:getWidth() / 4, Textures["ui_assets"]:getHeight() / 2)
    }

    Fonts = {
        ["small"] = love.graphics.newFont("resources/m6x11plus.ttf", 8),
        ["medium"] = love.graphics.newFont("resources/m6x11plus.ttf", 16),
        ["large"] = love.graphics.newFont("resources/m6x11plus.ttf", 32)
    }

    Shaders = {
        ["background"] = love.graphics.newShader("shaders/background.fs"),
        ["CRT"] = love.graphics.newShader("shaders/CRT.fs")
    }
    setupShaders()

    push:setupScreen(WIDTH, HEIGHT, WIDTH * SCALE, HEIGHT * SCALE, {
        vsync = true,
        fullscreen = false,
        resizable = false
    })

    GameView:init(Game.gameState)
    StateStack:push(GameView)
end

function love.update(dt)
    Shaders["background"]:send("time", love.timer.getTime())
    Shaders["background"]:send("spin_time", 0)
    Shaders["CRT"]:send("time", love.timer.getTime())
    Timer.update(dt)

    StateStack:update(dt)
end

function love.mousepressed(x, y, button)
    local mouseX, mouseY = push:toGame(x, y)
    StateStack:onMouseClick(mouseX, mouseY)
end

function love.draw()
    push:apply("start")

    StateStack:render()

    DisplayFPS()

    push:apply("end", Shaders["CRT"])
end

function DisplayFPS()
    love.graphics.setFont(Fonts["small"])
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.print('FPS: ' .. tostring(love.timer.getFPS()), 15, 10)
end