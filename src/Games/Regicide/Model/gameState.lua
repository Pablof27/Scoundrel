---@diagnostic disable: unused-local, unused-function, global-element

local Card = require("src.Model.card")
local Deck = require("src.Model.deck")

local GameState = {}
GameState.__index = GameState

local HAND_SIZE = 8
local JOKERS = 2

local PLAYER_STATES = { ATTACK = true, DEFEND = false }

local function enemyCards()
	local deck = Deck:new()
	for i = 1, 3 do
		local cards = {}
		for suit = 0, 3 do
			table.insert(cards, Card:new(suit, 10 + i, 10 + 5 * i))
			table.shuffle(cards)
		end
		deck:addToBottom(cards)
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
	o.currentEnemy = o.enemyDeck:drawCards(1)[1]
	o.enemyLife = enemyMaxLife(o.currentEnemy)
	o.damageShield = 0
	o.availableJokers = JOKERS
	o.currentPlayerState = PLAYER_STATES.ATTACK
	o.playedCards = {}
	o.errorMsg = nil
	o.stats = {
		enemyKills = 0,
		perfectKills = 0,
	}
	return o
end

function GameState:togglePlayerState()
	self.currentPlayerState = not self.currentPlayerState
end

function GameState:defend(cards)
	if not self.currentPlayerState == PLAYER_STATES.DEFEND then
		return
	end

	for _, c in ipairs(cards) do
		table.insert(self.discardPile, c)
	end
	self:togglePlayerState()
end

function GameState:selectionCanDefend(cards)
	local sum = 0
	for _, c in ipairs(cards) do
		sum = sum + c.value
	end

	return sum >= self.currentEnemy.value - self.damageShield
end

function GameState:nextEnemy()
	self.currentEnemy = self.enemyDeck:drawCards(1)[1]
	self.enemyLife = enemyMaxLife(self.currentEnemy)
	self.damageShield = 0
	self.playedCards = {}
end

function GameState:selectionCanAttack(cards)
	if #cards == 1 then
		return true
	end

	local sum = 0
	for _, c in ipairs(cards) do
		sum = sum + c.value
	end

	if sum > 10 or #cards > 4 then
		return false
	end

	if #cards == 2 then
		return cards[1].rank == Card.ACE or cards[2].rank == Card.ACE or cards[1].rank == cards[2].rank
	end

	if #cards == 3 then
		return cards[1].rank == cards[2].rank and cards[2].rank == cards[3].rank
	end

	return cards[1].rank == cards[2].rank and cards[2].rank == cards[3].rank and cards[3].rank == cards[4].rank
end

function GameState:playCards(cards)
	if not self.currentPlayerState == PLAYER_STATES.ATTACK then
		return false
	end
	local effectSum = 0
	local suits = {}
	for _, c in ipairs(cards) do
		table.insert(self.playedCards, c)
		effectSum = effectSum + c.value
		if not c.suit == self.currentEnemy.suit then
			table.insert(suits, c.suit)
		end
	end
	for _, s in ipairs(suits) do
		self:applyEffect(effectSum, s)
	end

	self.enemyLife = self.enemyLife - effectSum

	if self.enemyLife == 0 then
		self.playerDeck:addToTop(self.currentEnemy)
		self:nextEnemy()
		return true
	elseif self.enemyLife < 0 then
		table.insert(self.discardPile, self.currentEnemy)
		self:nextEnemy()
		return true
	end

	self:togglePlayerState()
	return true
end

function GameState:PlayJoker()
	if not self.currentPlayerState == PLAYER_STATES.ATTACK then
		return
	end
	if self.availableJokers <= 0 then
		return
	end
	self.availableJokers = self.availableJokers - 1
	for _, c in self.hand do
		table.insert(self.discardPile, c)
	end
	self.hand = self.playerDeck:drawCards(HAND_SIZE)
end

function GameState:applyEffect(n, suit)
	self:applyHearts(n, suit)
	self:applyDiamonds(n, suit)
	self:applySpades(n, suit)
	self:applyClubs(n, suit)
end

function GameState:applyHearts(n, suit)
	if not suit == Card.SUITS.HEART then
		return
	end
	table.shuffle(self.discardPile)
	local cards = {}
	for _ = 1, n do
		table.insert(cards, table.remove(self.discardPile, 1))
	end
	self.playerDeck:addToBottom(cards)
end

function GameState:applyDiamonds(n, suit)
	if not suit == Card.SUITS.DIAMOND then
		return
	end
	local draws = math.min(n, HAND_SIZE - #self.hand)
	local cards = self.playerDeck:drawCards(draws)

	for _, c in ipairs(cards) do
		table.insert(self.hand, c)
	end
end

function GameState:applySpades(n, suit)
	if not suit == Card.SUITS.SPADE then
		return
	end
	self.damageShield = self.damageShield - n
end

function GameState:applyClubs(n, suit)
	if not suit == Card.SUITS.CLUB then
		return
	end
	self.enemyLife = self.enemyLife - n
end

function GameState:isOver() end

return GameState
