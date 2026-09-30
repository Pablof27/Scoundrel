--[[
    StateStack
    Manages a stack of view states (screens and overlays).
    Every state is updated and rendered (bottom to top) so overlays can sit on top
    of a live screen, but only the topmost state has focus and receives input.
]]

local StateStack = {}
StateStack.__index = StateStack

function StateStack:new()
    local o = setmetatable({}, self)
    o.stack = {}
    return o
end

function StateStack:push(view)
    table.insert(self.stack, view)
end

function StateStack:pop()
    if #self.stack == 0 then
        return nil
    end
    local view = table.remove(self.stack)
    if view.destroy then
        view:destroy()
    end
    return view
end

function StateStack:clear()
    while #self.stack > 0 do
        self:pop()
    end
end

function StateStack:top()
    return self.stack[#self.stack]
end

function StateStack:render()
    for i = 1, #self.stack do
        self.stack[i]:render()
    end
end

function StateStack:update(dt)
    -- Iterate over a copy: states may push/pop while updating.
    local views = { unpack(self.stack) }
    for i, view in ipairs(views) do
        view:update(dt, i == #views)
    end
end

function StateStack:onMouseClick(mouseX, mouseY, button)
    local top = self:top()
    if top then
        top:onMouseClick(mouseX, mouseY, button)
    end
end

function StateStack:onKeyPressed(key)
    local top = self:top()
    if top and top.onKeyPressed then
        top:onKeyPressed(key)
    end
end

return StateStack