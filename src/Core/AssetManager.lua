--[[
    AssetManager
    Centralizes loading and access to all game assets (textures, quads, fonts, shaders, audio).
    Replaces the old global Textures/Frames/Fonts/Shaders tables.
]]

require("src.Core.utils")

local Audio = require("src.Core.audio")
local Font  = require("src.Core.font")

local AssetManager = {}
AssetManager.__index = AssetManager

AssetManager.WIDTH  = Constants.WIDTH
AssetManager.HEIGHT = Constants.HEIGHT
AssetManager.SCALE  = Constants.SCALE

AssetManager.BACKGROUND_COLOR1 = Constants.BACKGROUND_COLOR1
AssetManager.BACKGROUND_COLOR2 = Constants.BACKGROUND_COLOR2
AssetManager.BACKGROUND_COLOR3 = Constants.BACKGROUND_COLOR3
AssetManager.BACKGROUND_COLOR  = Constants.BACKGROUND_COLOR

-- Card backs (indices into Enhancers.png), in the same order as the "Card back" setting.
local CARD_BACK_FRAMES = { 1, 15, 16, 17, 18, 20, 4, 32 }
local BACK_ROW = 4

-- Indices into ui_assets.png
AssetManager.ICONS = { sun = 1, letter = 2, torch = 3, hash = 4, heart = 5, diamond = 6, club = 7, spade = 8 }

function AssetManager:new()
    local o = setmetatable({}, self)
    o.textures = {}
    o.frames   = {}
    o.fonts    = {}
    o.shaders  = {}
    o.audio    = Audio:new()
    o.time     = 0
    o.cardBack = 1
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
    self:composeCardAtlas()

    self.fonts.tiny   = Font:new("resources/m6x11plus.ttf", 8)
    self.fonts.small  = Font:new("resources/m6x11plus.ttf", 12)
    self.fonts.medium = Font:new("resources/m6x11plus.ttf", 16)
    self.fonts.big    = Font:new("resources/m6x11plus.ttf", 24)
    self.fonts.large  = Font:new("resources/m6x11plus.ttf", 32)
    self.fonts.title  = Font:new("resources/m6x11plus.ttf", 64)

    self.shaders.background = love.graphics.newShader("shaders/background.fs")
    self.shaders.CRT        = love.graphics.newShader("shaders/CRT.fs")
    self.shaders.card       = love.graphics.newShader("shaders/card.fs")
    self:setupShaders()

    self.audio:load()

    return self
end

-- Bakes every card face (frame + pips) and every card back into a single atlas,
-- so a card is one quad and the card shader can dissolve it as a whole.
function AssetManager:composeCardAtlas()
    local size = self:getCardSize()
    local w, h = size.width, size.height
    local canvas = love.graphics.newCanvas(w * 13, h * (BACK_ROW + 1), { dpiscale = 1 })

    love.graphics.push("all")
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setColor(1, 1, 1, 1)
    for position = 1, 52 do
        local col, row = (position - 1) % 13, math.floor((position - 1) / 13)
        love.graphics.draw(self.textures.cardFrames, self.frames.cardFrames[2], col * w, row * h)
        love.graphics.draw(self.textures.pips, self.frames.pips[position], col * w, row * h)
    end
    for i, frame in ipairs(CARD_BACK_FRAMES) do
        love.graphics.draw(self.textures.cardFrames, self.frames.cardFrames[frame], (i - 1) * w, BACK_ROW * h)
    end
    love.graphics.pop()

    self.textures.cards = love.graphics.newImage(canvas:newImageData())
    self.textures.cards:setFilter("nearest", "nearest")

    local atlasW, atlasH = self.textures.cards:getDimensions()
    self.frames.cardFaces = {}
    for position = 1, 52 do
        local col, row = (position - 1) % 13, math.floor((position - 1) / 13)
        self.frames.cardFaces[position] = love.graphics.newQuad(col * w, row * h, w, h, atlasW, atlasH)
    end
    self.frames.cardBacks = {}
    for i = 1, #CARD_BACK_FRAMES do
        self.frames.cardBacks[i] = love.graphics.newQuad((i - 1) * w, BACK_ROW * h, w, h, atlasW, atlasH)
    end
end

-- Atlas cell (column, row) of a card face, or of the current card back when position is nil.
function AssetManager:cardCell(position)
    if position == nil then
        return self.cardBack - 1, BACK_ROW
    end
    return (position - 1) % 13, math.floor((position - 1) / 13)
end

function AssetManager:cardQuad(position)
    if position == nil then
        return self.frames.cardBacks[self.cardBack]
    end
    return self.frames.cardFaces[position]
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
    self.shaders.card:send("image_details", { self.textures.cards:getDimensions() })
end

-- Screen pixels per game pixel. Fonts are rasterized at this density to keep text sharp (see Font).
function AssetManager:setPixelDensity(density)
    for _, font in pairs(self.fonts) do
        font:setPixelDensity(density)
    end
end

function AssetManager:update(dt)
    self.time = self.time + dt
    self.audio:update()
    self.shaders.background:send("time", self.time)
    self.shaders.background:send("spin_time", 0)
    self.shaders.CRT:send("time", self.time)
    self.shaders.card:send("time", self.time)
end

function AssetManager:getCardSize()
    return GetQuadDimensions(self.frames.cardFrames[1])
end

return AssetManager
