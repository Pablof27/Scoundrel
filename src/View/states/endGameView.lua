--[[
    EndGameView
    Win/lose screen overlay. Receives assets via constructor.
    No global dependencies.
]]

local Timer = require("lib.timer")

local EndGameView = {}
EndGameView.__index = EndGameView

function EndGameView:new(didWin, onClick, assets)
    local o = setmetatable({}, self)
    o.didWin   = didWin
    o.onClick  = onClick
    o.assets   = assets
    o.titleY   = -100
    o.subtitleY = assets.HEIGHT + 100
    Timer.tween(0.25, {
        [o] = { titleY = assets.HEIGHT / 2 - 32, subtitleY = assets.HEIGHT / 2 + 32 }
    })
    return o
end

function EndGameView:render()
    love.graphics.clear(0, 0, 0)

    self:renderBackground()

    love.graphics.setFont(self.assets.fonts.large)
    if self.didWin then
        love.graphics.printf("You Win!", 0, self.titleY, self.assets.WIDTH, "center")
    else
        love.graphics.printf("Game Over", 0, self.titleY, self.assets.WIDTH, "center")
    end

    love.graphics.setFont(self.assets.fonts.medium)
    love.graphics.printf("Click to Restart", 0, self.subtitleY, self.assets.WIDTH, "center")
end

function EndGameView:renderBackground()
    love.graphics.setShader(self.assets.shaders.background)
    love.graphics.rectangle("fill", 0, 0, self.assets.WIDTH, self.assets.HEIGHT)
    love.graphics.setShader()
end

function EndGameView:update(dt)
end

function EndGameView:onMouseClick(mouseX, mouseY)
    self.onClick()
end

return EndGameView