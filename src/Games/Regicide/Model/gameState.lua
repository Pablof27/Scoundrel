---@diagnostic disable: unused-local, unused-function, global-element

local Card = require("src.Model.card")
local Deck = require("src.Model.deck")

local GameState = {}
GameState.__index = GameState

local HAND_SIZE = 8

local function enemyCards()
	local deck = Deck:new()
	for i = 0, 2 do
		local cards = {}
		for suit = 0, 3 do
			table.insert(cards, Card:new(suit, 10 + i, 10 + 5 * i))
			table.shuffle(cards)
			deck:addToBottom(cards)
		end
	end
	return deck
end

local function playerCards()
	local cards = {}
	for suit = 0, 3 do
		for rank = 0, 10 do
			table.insert(cards, Card:new(suit, rank))
		end
		table.insert(cards, Card:new(suit, Card.ACE, 1))
	end
	return Deck:new(cards):shuffle()
end

local function enemyMaxLife(card)
	return (card.rank - 9) * 10
end

function GameState:new()
	local o = setmetatable({}, self)
	o.enemyDeck = enemyCards()
	o.playerDeck = playerCards()
	o.discardPile = {}
	o.hand = o.playerDeck:drawCards(HAND_SIZE)
	o.currentEnemy = o.enemyDeck:drawCards()[1]
	o.enemyLife = enemyMaxLife(o.currentEnemy)
	o.stats = {
		enemyKills = 0,
		perfectKills = 0,
	}

	return o
end

function GameState:PlayCards(cards)
	local damage = 0
	local suits = {}
	for _, c in ipairs(cards) do
		damage = damage + c.value
		if not c.suit == self.currentEnemy.suit then
			table.insert(suits, c.suit)
		end
	end
end
