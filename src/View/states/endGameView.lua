
EndGameView = {}

function EndGameView:new(didWin, onClick)
   self.didWin = didWin
   self.onClick = onClick
   self.titleY = -100
   self.subtitleY = HEIGHT + 100
   Timer.tween(0.25, {
         [self] = { titleY = HEIGHT / 2 - 32, subtitleY = HEIGHT / 2 + 32 }
   })
   return self
end

function EndGameView:render()
    love.graphics.clear(0, 0, 0)

    EndGameView.renderBackground()

    love.graphics.setFont(Fonts["large"])
    if self.didWin then
        love.graphics.printf("You Win!", 0, self.titleY, WIDTH, "center")
    else
        love.graphics.printf("Game Over", 0, self.titleY, WIDTH, "center")
    end

    love.graphics.setFont(Fonts["medium"])
    love.graphics.printf("Click to Restart", 0, self.subtitleY, WIDTH, "center")
end

function EndGameView.renderBackground()
    love.graphics.setShader(Shaders["background"])
    love.graphics.rectangle("fill", 0, 0, WIDTH, HEIGHT)
    love.graphics.setShader()
end

function EndGameView:update(dt)
end

function EndGameView:onMouseClick(mouseX, mouseY)
    self.onClick()
end

return EndGameView