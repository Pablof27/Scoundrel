local gameView = require("src.View.states.gameView")

local StateStack = {}

function StateStack:new()
    local obj = {
        stack = {},
    }
    setmetatable(obj, self)
    self.__index = self
    return obj
end

function StateStack:push(view)
    table.insert(self.stack, view)
end

function StateStack:pop()
    if #self.stack == 0 then
        return nil
    end
    return table.remove(self.stack, #self.stack)
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

return StateStack:new()