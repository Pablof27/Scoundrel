--[[
    LibraryView
    First screen: the library's title and one panel per game (name, tagline, a fan of its cards,
    credits and records). Clicking a panel, or pressing Enter on the selected one, opens that game's
    home screen. The general settings are reachable from here too.
    Publishes "navigate" events; it knows nothing about the other screens.
]]

local Card     = require("src.Model.card")
local CardView = require("src.View.cardView")
local Button   = require("src.View.buttonView")
local Anim     = require("src.View.anim")
local UI       = require("src.View.ui")

local LibraryView = {}
LibraryView.__index = LibraryView

local PANEL_W, PANEL_H, PANEL_GAP = 250, 196, 26
local PANEL_Y = 110
local HEADER_H = 28
local CARD_SCALE = 0.72
local CARD_SPREAD = 46
local HOVER_LIFT = -5

-- games: the game descriptors, in the order they are listed.
function LibraryView:new(context, games)
    local o = setmetatable({}, self)
    o.assets        = context.assets
    o.eventBus      = context.eventBus
    o.records       = context.records
    o.mouseProvider = context.mouseProvider
    o.time          = 0
    o.titleDrop     = -90
    o.titleVel      = 0
    o.selected      = nil  -- panel under the mouse, or chosen with the arrow keys
    o.panels        = {}

    local W, H = o.assets.WIDTH, o.assets.HEIGHT
    local total = #games * PANEL_W + (#games - 1) * PANEL_GAP
    local left = math.floor((W - total) / 2)
    for i, game in ipairs(games) do
        local panel = {
            game  = game,
            x     = left + (i - 1) * (PANEL_W + PANEL_GAP),
            y     = PANEL_Y,
            lift  = 0,
            juice = nil,
            cards = {},
        }
        -- The middle cards of the game's showcase, fanned out.
        local first = math.max(1, math.floor((#game.showcase - 3) / 2) + 1)
        for j = 0, 2 do
            local spec = game.showcase[first + j]
            if spec then
                local view = CardView:new(Card:new(spec[1], spec[2]), o.assets, panel.x + PANEL_W / 2, H + 100,
                    { s = CARD_SCALE })
                view.offset = j - 1
                view.delay = 0.15 + i * 0.1 + j * 0.06
                view.flip = -1
                table.insert(panel.cards, view)
            end
        end
        table.insert(o.panels, panel)
    end
    o:placeCards()

    local specs = { { text = "SETTINGS", color = "green", width = 120, target = "settings" } }
    -- A web page can't be closed by the game.
    if not Constants.IS_WEB then
        table.insert(specs, { text = "QUIT", color = "red", width = 90, target = "quit" })
    end
    local gap = 10
    local width = -gap
    for _, spec in ipairs(specs) do
        width = width + spec.width + gap
    end
    local x = (W - width) / 2
    o.buttons = {}
    for i, spec in ipairs(specs) do
        local button = Button:new({
            x = x, y = PANEL_Y + PANEL_H + 22, width = spec.width, height = 30,
            text = spec.text, color = UI.colors[spec.color], font = o.assets.fonts.big,
            onClick = function() o.eventBus:publish("navigate", spec.target) end,
        }, o.assets, o.mouseProvider)
        button.visible = false
        button.showAt = 0.6 + i * 0.08
        table.insert(o.buttons, button)
        x = x + spec.width + gap
    end
    return o
end

function LibraryView:placeCards()
    for _, panel in ipairs(self.panels) do
        local cx = panel.x + PANEL_W / 2
        local cy = panel.y + panel.lift + 100
        for _, view in ipairs(panel.cards) do
            local offset = view.offset
            view:setTarget(cx + offset * CARD_SPREAD, cy + math.abs(offset) * 6, offset * 0.12, CARD_SCALE)
        end
    end
end

function LibraryView:panelAt(x, y)
    for i, panel in ipairs(self.panels) do
        if x >= panel.x and x <= panel.x + PANEL_W and y >= panel.y and y <= panel.y + PANEL_H then
            return i
        end
    end
    return nil
end

function LibraryView:select(index)
    if index and index ~= self.selected then
        self.panels[index].juice = Anim.newJuice(0.04, 0.01, 0.3)
        self.assets.audio:play("hover", { pitch = 0.8, variation = 0.1 })
    end
    self.selected = index
end

function LibraryView:open(index)
    local panel = self.panels[index]
    panel.juice = Anim.newJuice(0.08, 0.02, 0.35)
    self.assets.audio:play("click")
    self.eventBus:publish("navigate", "selectGame", panel.game.id)
end

function LibraryView:update(dt, hasFocus)
    self.time = self.time + dt
    self.titleDrop, self.titleVel = Anim.spring(self.titleDrop, self.titleVel, 0, 120, 9, dt)

    local mouseX, mouseY = self.mouseProvider()
    if not hasFocus then
        mouseX, mouseY = -1000, -1000
    end
    local hovered = self:panelAt(mouseX, mouseY)
    if hovered then
        self:select(hovered)
    elseif self.mouseMoved then
        self.selected = nil
    end
    self.mouseMoved = self.lastMouseX ~= nil and (self.lastMouseX ~= mouseX or self.lastMouseY ~= mouseY)
    self.lastMouseX, self.lastMouseY = mouseX, mouseY

    for i, panel in ipairs(self.panels) do
        panel.lift = Anim.approach(panel.lift, i == self.selected and HOVER_LIFT or 0, 14, dt)
        panel.juice = Anim.updateJuice(panel.juice, dt)
        for _, view in ipairs(panel.cards) do
            view.hovered = i == self.selected and view:contains(mouseX, mouseY)
            view:update(dt, mouseX, mouseY)
        end
    end
    self:placeCards()

    for _, button in ipairs(self.buttons) do
        if not button.visible and self.time >= button.showAt then
            button.visible = true
            button.juice = Anim.newJuice(0.15, 0.03, 0.4)
        end
        button:update(dt, hasFocus)
    end
end

function LibraryView:render()
    local assets = self.assets
    local C, fonts = UI.colors, assets.fonts
    local W, H = assets.WIDTH, assets.HEIGHT
    UI.renderBackground(assets)

    UI.wavyText(Constants.TITLE:upper(), W / 2, 52 + self.titleDrop, fonts.title, self.time,
        { amplitude = 3, speed = 2, spacing = 0.5, tilt = 0.03, shadowDepth = 4 })
    UI.textCentered("A library of solitaire card games. Pick one to play.", W / 2, 92 + self.titleDrop * 0.5,
        fonts.small, C.text)

    for i, panel in ipairs(self.panels) do
        self:renderPanel(panel, i == self.selected)
    end

    for _, button in ipairs(self.buttons) do
        button:render()
    end
end

function LibraryView:renderPanel(panel, selected)
    local C, fonts = UI.colors, self.assets.fonts
    local game = panel.game
    local color = C[game.color] or C.blue
    local x, y = panel.x, panel.y + panel.lift
    local cx = x + PANEL_W / 2
    local juice = panel.juice

    love.graphics.push()
    if juice then
        love.graphics.translate(cx, y + PANEL_H / 2)
        love.graphics.rotate(juice.r)
        love.graphics.scale(1 + juice.scale, 1 + juice.scale)
        love.graphics.translate(-cx, -(y + PANEL_H / 2))
    end

    UI.box(x, y, PANEL_W, PANEL_H, C.panel,
        { radius = 10, depth = 4, outline = selected and UI.mix(color, C.white, 0.3) or C.panelLight, lineWidth = 2 })
    UI.box(x + 6, y + 6, PANEL_W - 12, HEADER_H, color, { radius = 6, depth = 2 })
    UI.textCentered(game.name, cx, y + 6 + HEADER_H / 2, fonts.big, C.text, { shadowDepth = 2 })
    UI.textCentered(game.tagline, cx, y + HEADER_H + 18, fonts.small, C.text)

    for _, view in ipairs(panel.cards) do
        view:draw()
    end

    UI.textCentered(game.author, cx, y + 150, fonts.small, C.textDim)
    UI.textCentered(game.recordsSummary(self.records[game.id]), cx, y + 168, fonts.small, C.text)
    if selected then
        local pulse = 0.6 + 0.4 * math.sin(self.time * 6)
        UI.textCentered("CLICK TO PLAY", cx, y + PANEL_H - 10, fonts.tiny, UI.mix(color, C.white, 0.4),
            { alpha = pulse, shadow = false })
    end
    love.graphics.pop()
end

function LibraryView:onMouseClick(mouseX, mouseY, button)
    for _, b in ipairs(self.buttons) do
        if b:onMouseClick(mouseX, mouseY) then
            return
        end
    end
    local index = self:panelAt(mouseX, mouseY)
    if index then
        self:open(index)
    end
end

function LibraryView:onKeyPressed(key)
    local count = #self.panels
    if key == "left" then
        self:select(((self.selected or 1) - 2) % count + 1)
    elseif key == "right" then
        self:select((self.selected or 0) % count + 1)
    elseif key == "return" or key == "space" then
        self:open(self.selected or 1)
    elseif key == "escape" and not Constants.IS_WEB then
        self.eventBus:publish("navigate", "quit")
    end
end

return LibraryView
