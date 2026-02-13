--[[
    StateStack
    Manages a stack of view states (screens).
    The topmost state receives update and input events.
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
    return table.remove(self.stack)
end

function StateStack:render()
    for i = 1, #self.stack do
        self.stack[i]:render()
    end
end

function StateStack:update(dt)
    if #self.stack == 0 then
        return
    end
    self.stack[#self.stack]:update(dt)
end

function StateStack:onMouseClick(mouseX, mouseY)
    if #self.stack == 0 then
        return
    end
    self.stack[#self.stack]:onMouseClick(mouseX, mouseY)
end

return StateStack