---@diagnostic disable: undefined-global

function PlayCardAction:new(cards)
	local o = setmetatable({}, self)
	o.cards = cards
	return o
end

function PlayCardAction:execute(gameState)
	return gameState:playCards(self.cards)
end

function DefendAction:new(cards)
	local o = setmetable({}, self)
	o.cards = cards
	return o
end

function DefendAction:execute(gameState)
	return gameState:defend(cards)
end

return {
	PlayCardAction = PlayCardAction,
	DefendAction = DefendAction,
}
