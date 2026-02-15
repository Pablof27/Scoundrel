--[[
    TransitionView
    Fade-to-white / fade-from-white transition overlay.
    Pushed on top of the StateStack to smoothly bridge two views.
    Phase 1: alpha 0→1 (fade to white), then calls onMidpoint.
    Phase 2: alpha 1→0 (fade from white), then calls onComplete.
]]

local Timer = require("lib.timer")

local TransitionView = {}
TransitionView.__index = TransitionView

function TransitionView:new(onMidpoint, onComplete)
    local o = setmetatable({}, self)
    o.alpha       = 0
    o.onMidpoint  = onMidpoint
    o.onComplete  = onComplete

    Timer.tween(0.25, { [o] = { alpha = 1 } }):finish(function()
        if o.onMidpoint then
            o.onMidpoint()
        end
        Timer.tween(0.25, { [o] = { alpha = 0 } }):finish(function()
            if o.onComplete then
                o.onComplete()
            end
        end)
    end)

    return o
end

function TransitionView:render()
    love.graphics.setColor(1, 1, 1, self.alpha)
    love.graphics.rectangle("fill", 0, 0, Constants.WIDTH, Constants.HEIGHT)
end

function TransitionView:update(dt)
end

function TransitionView:onMouseClick(mouseX, mouseY)
end

return TransitionView
