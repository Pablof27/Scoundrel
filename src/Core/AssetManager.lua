--[[
    AssetManager
    Centralizes loading and access to all game assets (textures, quads, fonts, shaders).
    Replaces the old global Textures/Frames/Fonts/Shaders tables.
]]

local utils = require("src.Core.utils")

local AssetManager = {}
AssetManager.__index = AssetManager

-- Re-export display constants from the shared constants module
AssetManager.WIDTH  = Constants.WIDTH
AssetManager.HEIGHT = Constants.HEIGHT
AssetManager.SCALE  = Constants.SCALE

AssetManager.BACKGROUND_COLOR1 = Constants.BACKGROUND_COLOR1
AssetManager.BACKGROUND_COLOR2 = Constants.BACKGROUND_COLOR2
AssetManager.BACKGROUND_COLOR3 = Constants.BACKGROUND_COLOR3
AssetManager.BACKGROUND_COLOR  = Constants.BACKGROUND_COLOR

function AssetManager:new()
    local o = setmetatable({}, self)
    o.textures = {}
    o.frames   = {}
    o.fonts    = {}
    o.shaders  = {}
    return o
end

function AssetManager:load()

    self.textures.pips       = love.graphics.newImage("resources/8BitDeck_small.png")
    self.textures.cardFrames = love.graphics.newImage("resources/Enhancers.png")
    self.textures.uiAssets   = love.graphics.newImage("resources/ui_assets.png")

    self.frames.pips = GenerateQuads(
        self.textures.pips,
        self.textures.pips:getWidth() / 13,
        self.textures.pips:getHeight() / 4
    )
    self.frames.cardFrames = GenerateQuads(
        self.textures.cardFrames,
        self.textures.cardFrames:getWidth() / 7,
        self.textures.cardFrames:getHeight() / 5
    )
    self.frames.uiAssets = GenerateQuads(
        self.textures.uiAssets,
        self.textures.uiAssets:getWidth() / 4,
        self.textures.uiAssets:getHeight() / 2
    )

    self.fonts.small  = love.graphics.newFont("resources/m6x11plus.ttf", 8)
    self.fonts.medium = love.graphics.newFont("resources/m6x11plus.ttf", 16)
    self.fonts.large  = love.graphics.newFont("resources/m6x11plus.ttf", 32)

    self.shaders.background = love.graphics.newShader("shaders/background.fs")
    self.shaders.CRT        = love.graphics.newShader("shaders/CRT.fs")
    self:setupShaders()

    return self
end

function AssetManager:setupShaders()
    self.shaders.background:send("colour_1", {HexToRgb(self.BACKGROUND_COLOR1)})
    self.shaders.background:send("colour_2", {HexToRgb(self.BACKGROUND_COLOR2)})
    self.shaders.background:send("colour_3", {HexToRgb(self.BACKGROUND_COLOR3)})
    self.shaders.background:send("contrast", 1)
    self.shaders.background:send("spin_amount", 0.1)
    self.shaders.CRT:send("distortion_fac", {1.02, 1.02})
    self.shaders.CRT:send("scale_fac", {0.95, 0.95})
    self.shaders.CRT:send("feather_fac", 0.02)
    self.shaders.CRT:send("noise_fac", 0.001)
    self.shaders.CRT:send("bloom_fac", 0.0)
    self.shaders.CRT:send("crt_intensity", 0.03)
    self.shaders.CRT:send("glitch_intensity", 0)
    self.shaders.CRT:send("scanlines", 450.0)
end

function AssetManager:updateShaderTime()
    self.shaders.background:send("time", love.timer.getTime())
    self.shaders.background:send("spin_time", 0)
    self.shaders.CRT:send("time", love.timer.getTime())
end

function AssetManager:getCardSize()
    return GetQuadDimensions(self.frames.cardFrames[1])
end

return AssetManager
