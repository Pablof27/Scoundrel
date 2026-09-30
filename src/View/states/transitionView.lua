--[[
    TransitionView
    Fade-out / fade-in overlay drawn on top of every screen to smoothly swap screens.
    Phase 1: alpha 0→1, then calls onMidpoint (swap the screens underneath).
    Phase 2: alpha 1→0, then calls onComplete.
]]

local Timer = require("lib.timer")

local TransitionView = {}
TransitionView.__index = TransitionView

local FADE_TIME = 0.22
local COLOR = { 0.1, 0.14, 0.15 }

function TransitionView:new(onMidpoint, onComplete)
    local o = setmetatable({}, self)
    o.alpha       = 0
    o.onMidpoint  = onMidpoint
    o.onComplete  = onComplete

    Timer.tween(FADE_TIME, { [o] = { alpha = 1 } }):finish(function()
        if o.onMidpoint then
            o.onMidpoint()
        end
        Timer.tween(FADE_TIME, { [o] = { alpha = 0 } }):finish(function()
            if o.onComplete then
                o.onComplete()
            end
        end)
    end)

    return o
end

function TransitionView:render()
    love.graphics.setColor(COLOR[1], COLOR[2], COLOR[3], self.alpha)
    love.graphics.rectangle("fill", 0, 0, Constants.WIDTH, Constants.HEIGHT)
end

return TransitionView
