---@diagnostic disable: undefined-global

local Action = require("src.Controller.action")

function PlayCardAction:new(cards)
	local o = setmetatable({}, self)
	o.cards = cards
	return o
end

function PlayCardAction:execute(gameState)
	return gameState:playCards(self.cards)
end

return {
	PlayCardAction = PlayCardAction,
}
