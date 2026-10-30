--[[
    UI
    Shared palette and drawing helpers (raised boxes, shadowed text, icons)
    so every screen shares the same chunky, Balatro-like look.
]]

local Anim = require("src.View.anim")

local UI = {}

local function hex(value)
    return {
        tonumber(value:sub(1, 2), 16) / 255,
        tonumber(value:sub(3, 4), 16) / 255,
        tonumber(value:sub(5, 6), 16) / 255,
        1,
    }
end

UI.colors = {
    red        = hex("FE5F55"),
    darkRed    = hex("B8322B"),
    blue       = hex("009DFF"),
    green      = hex("4BC292"),
    orange     = hex("FDA200"),
    gold       = hex("EAC058"),
    purple     = hex("8867A5"),
    grey       = hex("5F7377"),
    white      = hex("FFFFFF"),
    text       = hex("FFFFFF"),
    textDim    = hex("B9C4C4"),
    textDark   = hex("2A3436"),
    panel      = hex("374244"),
    panelDark  = hex("1E2B2D"),
    panelInner = hex("2B3A3D"),
    panelLight = hex("4F6367"),
    heal       = hex("5BE37D"),
    damage     = hex("FF4B3E"),
}

function UI.setColor(color, alpha)
    love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * (alpha or 1))
end

function UI.shade(color, factor)
    return { color[1] * factor, color[2] * factor, color[3] * factor, color[4] or 1 }
end

function UI.mix(a, b, t)
    return { Anim.lerp(a[1], b[1], t), Anim.lerp(a[2], b[2], t), Anim.lerp(a[3], b[3], t), Anim.lerp(a[4] or 1, b[4] or 1, t) }
end

-- Rounded box with an optional darker "edge" below it (depth) and an outline.
function UI.box(x, y, w, h, color, opts)
    opts = opts or {}
    local radius = opts.radius or 6
    local alpha = opts.alpha or 1
    local depth = opts.depth or 0
    if depth > 0 then
        UI.setColor(UI.shade(color, 0.55), alpha)
        love.graphics.rectangle("fill", x, y + depth, w, h, radius, radius)
    end
    UI.setColor(color, alpha)
    love.graphics.rectangle("fill", x, y, w, h, radius, radius)
    if opts.outline then
        UI.setColor(opts.outline, alpha)
        love.graphics.setLineWidth(opts.lineWidth or 1)
        love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, radius, radius)
    end
end

-- Text with a drop shadow. With opts.width the text is wrapped and aligned (opts.align).
function UI.text(text, x, y, font, color, opts)
    opts = opts or {}
    local alpha = opts.alpha or 1
    if opts.shadow ~= false then
        love.graphics.setColor(0, 0, 0, 0.45 * alpha)
        if opts.width then
            font:printf(text, x + 1, y + 1, opts.width, opts.align or "left")
        else
            font:print(text, x + 1, y + 1)
        end
    end
    UI.setColor(color or UI.colors.text, alpha)
    if opts.width then
        font:printf(text, x, y, opts.width, opts.align or "left")
    else
        font:print(text, x, y)
    end
end

-- Text centered on (cx, cy), optionally scaled and rotated around its center.
function UI.textCentered(text, cx, cy, font, color, opts)
    opts = opts or {}
    local alpha = opts.alpha or 1
    local scale = opts.scale or 1
    local r = opts.r or 0
    local ox, oy = font:getWidth(text) / 2, font:getHeight() / 2
    if opts.shadow ~= false then
        local depth = opts.shadowDepth or 1
        love.graphics.setColor(0, 0, 0, 0.45 * alpha)
        font:print(text, cx + depth, cy + depth, r, scale, scale, ox, oy)
    end
    if opts.outline then
        love.graphics.setColor(0.08, 0.1, 0.11, 0.85 * alpha)
        for _, offset in ipairs({ { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }) do
            font:print(text, cx + offset[1], cy + offset[2], r, scale, scale, ox, oy)
        end
    end
    UI.setColor(color or UI.colors.text, alpha)
    font:print(text, cx, cy, r, scale, scale, ox, oy)
end

-- Draws an icon from ui_assets.png (see AssetManager.ICONS) scaled to `size` pixels.
function UI.icon(assets, name, x, y, size, alpha, color)
    local quad = assets.frames.uiAssets[assets.ICONS[name]]
    local scale = size / 36
    UI.setColor(color or UI.colors.white, alpha)
    love.graphics.draw(assets.textures.uiAssets, quad, x, y, 0, scale, scale)
end

-- Card value as printed on the card: 2-10, J, Q, K, A.
function UI.rankName(value)
    local names = { [11] = "J", [12] = "Q", [13] = "K", [14] = "A" }
    return names[value] or tostring(value)
end

-- "7" for pip cards, "Q (12)" for faces, to explain values in sentences.
function UI.valueLabel(value)
    if value <= 10 then
        return tostring(value)
    end
    return UI.rankName(value) .. " (" .. value .. ")"
end

function UI.formatTime(seconds)
    seconds = math.floor(seconds)
    return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

function UI.renderBackground(assets)
    love.graphics.setShader(assets.shaders.background)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, assets.WIDTH, assets.HEIGHT)
    love.graphics.setShader()
end

-- Darkens whatever is below an overlay.
function UI.dim(assets, alpha)
    love.graphics.setColor(0.04, 0.07, 0.08, alpha)
    love.graphics.rectangle("fill", 0, 0, assets.WIDTH, assets.HEIGHT)
end

-- Main panel used by overlays (pause, rules, settings, end of run).
function UI.panel(x, y, w, h, alpha)
    UI.box(x, y, w, h, UI.colors.panel, { radius = 10, depth = 4, outline = UI.colors.panelLight, alpha = alpha })
end

return UI
