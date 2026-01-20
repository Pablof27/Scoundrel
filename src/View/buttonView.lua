
local Button = {}

function Button:new(params)
    local o = {}
    setmetatable(o, self)
    self.__index = self

    o.pos = { x = params.x, y = params.y }
    o.size = { width = params.width, height = params.height }
    o.text = params.text or ""
    o.color = params.color or {0, 0, 0, 1}
    o.onClick = params.onClick or function() end
    o.hoovered = false
    o.visible = params.visible ~= false
    return o
end

function Button:render()
    if not self.visible then
        return
    end
    local luminosity = self.hoovered and 1.0 or 0.9
    love.graphics.setColor(self.color[1] * luminosity, self.color[2] * luminosity, self.color[3] * luminosity, self.color[4])
    love.graphics.rectangle("fill", self.pos.x, self.pos.y, self.size.width, self.size.height, 4, 4)
    love.graphics.setColor(self.color[1] * 0.8, self.color[2] * 0.8, self.color[3] * 0.8, self.color[4])
    love.graphics.rectangle("line", self.pos.x, self.pos.y, self.size.width, self.size.height, 4, 4)
    love.graphics.setColor(0.9, 0.9, 0.9, 1)
    love.graphics.setFont(Fonts["medium"])
    local textWidth = Fonts["medium"]:getWidth(self.text)
    local textHeight = Fonts["medium"]:getHeight()
    love.graphics.print(self.text, self.pos.x + (self.size.width - textWidth) / 2, self.pos.y + (self.size.height - textHeight) / 2)
end

function Button:isInside(mouseX, mouseY)
    return mouseX >= self.pos.x and mouseX <= self.pos.x + self.size.width and
           mouseY >= self.pos.y and mouseY <= self.pos.y + self.size.height
end

function Button:update(dt)
    local mouseX, mouseY = push:toGame(love.mouse.getPosition())
    self.hoovered = self:isInside(mouseX, mouseY)
end

function Button:onMouseClick(mouseX, mouseY)
    if not self.visible or  not self:isInside(mouseX, mouseY) then
        return false
    end
    self.onClick()
    return true
end

return Button