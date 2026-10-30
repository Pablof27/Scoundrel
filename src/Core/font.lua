--[[
    Font
    A font sized in game pixels but rasterized at the pixel density of the screen.
    m6x11plus is a pixel font drawn on a 16 px grid, so at 8, 12 or 24 px its pixels don't fall on whole
    pixels of the 711x400 game canvas. Rasterizing text at that resolution and then enlarging the canvas
    made some letters blurry and their strokes uneven, worst on screens with big pixels.
    Instead, glyphs are rasterized at size * density screen pixels and drawn scaled back by the density,
    on whole screen pixels. It offers the LÖVE Font methods the game uses (in game pixels) and draws with
    print/printf.
]]

local Font = {}
Font.__index = Font

function Font:new(path, size)
    local o = setmetatable({}, self)
    o.path       = path
    o.size       = size
    o.lineHeight = 1
    o:setPixelDensity(1)
    return o
end

-- density: screen pixels per game pixel (see push:getPixelDensity).
function Font:setPixelDensity(density)
    if density <= 0 or density == self.density then
        return
    end
    self.density = density
    local pixelSize = math.max(1, math.floor(self.size * density + 0.5))
    if pixelSize == self.pixelSize then
        return
    end
    if self.font then
        self.font:release()
    end
    self.pixelSize = pixelSize
    -- With a dpiscale above 1, LÖVE 11 rounds every glyph advance to whole game pixels and letters overlap.
    self.font = love.graphics.newFont(self.path, pixelSize, "normal", 1)
    self.font:setLineHeight(self.lineHeight)
end

function Font:getWidth(text)
    return self.font:getWidth(text) / self.density
end

function Font:getHeight()
    return self.font:getHeight() / self.density
end

-- Like LÖVE's Font:getWrap: width of the widest line and the lines of `text` wrapped at `width`.
function Font:getWrap(text, width)
    local widest, lines = self.font:getWrap(text, width * self.density)
    return widest / self.density, lines
end

function Font:setLineHeight(height)
    self.lineHeight = height
    self.font:setLineHeight(height)
end

function Font:getLineHeight()
    return self.lineHeight
end

-- Nearest point on a whole screen pixel, through the current transform.
local function snap(x, y, density)
    local screenX, screenY = love.graphics.transformPoint(x, y)
    return love.graphics.inverseTransformPoint(
        math.floor(screenX * density + 0.5) / density,
        math.floor(screenY * density + 0.5) / density)
end

-- Same arguments as love.graphics.print. Text that isn't rotated or scaled is kept on whole screen pixels.
function Font:print(text, x, y, r, sx, sy, ox, oy)
    r, sx = r or 0, sx or 1
    sy, ox, oy = sy or sx, ox or 0, oy or 0
    local density = self.density
    love.graphics.setFont(self.font)
    if r == 0 and sx == 1 and sy == 1 then
        x, y = snap(x - ox, y - oy, density)
        love.graphics.print(text, x, y, 0, 1 / density)
    else
        love.graphics.print(text, x, y, r, sx / density, sy / density, ox * density, oy * density)
    end
end

-- Same arguments as love.graphics.printf: `text` wrapped at `width` and aligned with `align`.
function Font:printf(text, x, y, width, align)
    local density = self.density
    x, y = snap(x, y, density)
    love.graphics.setFont(self.font)
    love.graphics.printf(text, x, y, width * density, align, 0, 1 / density)
end

return Font
