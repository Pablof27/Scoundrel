local BoardView = require("src.View.boardView")
local DeckView = require("src.View.deckView")
local Button = require("src.View.buttonView")
local Anim = require("src.View.anim")
local UI = require("src.View.ui")
local Config = require("src.Games.Regicide.config")
local GameState = require("src.Games.Regicide.Model.gameState")
local SidebarView = require("src.Games.Regicide.View.sidebarView")
-- local Actions = require("src.Games.Regicide.Controller.actions")

local GameView = BoardView.extend()

local SIDEBAR_WIDTH = Constants.SIDEBAR_WIDTH
local SAFE_X, SAFE_Y = Constants.SAFE_X, Constants.SAFE_Y
local DEAL_INTERVAL = 0.09

function GameView:new(context, gameState)
	local o = setmetatable({}, self)
	BoardView.init(o, context)
	o.state = gameState
	o:computeLayout()
	local L = o.layout
	o.enemyDeck = DeckView:new(o.assets, L.topDeckX, L.enemY)
	o.enemyDeck:setCount(#gameState.enemyDeck.cards)
	-- o.playerDeck = DeckView:new(o.assets, L.downDeckX, L.downDeckY)
	-- o.playerDeck:setCount(#gameState.playerDeck.cards)

	local dealDelay = 0.3
	local delt = o:sync({ dealDelay = dealDelay })
	o.lock = dealDelay + delt * DEAL_INTERVAL + 0.3
	return o
end

function GameView:computeLayout()
	local size = self.assets:getCardSize()
	local W, H = self.assets.WIDTH, self.assets.HEIGHT
	local L = { cardW = size.width, cardH = size.height }

	L.sidebar = { x = SAFE_X, y = SAFE_Y, w = SIDEBAR_WIDTH, h = H - 2 * SAFE_Y }

	local areaX = L.sidebar.x + L.sidebar.w + 10
	local areaW = W - SAFE_X - areaX
	local spacing = size.width + 8
	local enemyW = spacing + size.width
	local left = math.floor(areaX + (areaW - enemyW) / 2)

	L.enemY = 30 + size.height / 2
	L.eSlotX = left + size.width / 2 + spacing
	L.topDeckX = left + size.width / 2
	self.layout = L
end

function GameView:sync(opts)
	opts = opts or {}
	local L, state = self.layout, self.state
	local present = {}
	local dealDelay = opts.dealDelay or 0
	local eDeckX, eDeckY = self.enemyDeck:topPosition()

	local card = state.currentEnemy
	local view = self.views[card.position]

	view = self:placeCard(card, "enemySlot", L.eSlotX, L.enemY, 0, present)
	view:snapTo(eDeckX, eDeckY)
	view:setTarget(L.eSlotX, L.enemY)
	view.flip = -1
	view.faceUp = true
	view.delay = dealDelay
	self:after(view.delay, function()
		self.assets.audio:play("deal", { variation = 0.15 })
	end)
	view.slot = nil
	view.lastSlot = 1

	self.enemyDeck:setCount(#state.enemyDeck.cards)
	return 1
end

function GameView:render()
	self:beginRender()
	self.enemyDeck:render()
	for _, view in pairs(self.views) do
		view:draw()
	end
	self:endRender()
end

function GameView:update(dt, hasFocus)
	self:updateClock(dt, hasFocus)
	local mouseX, mouseY = self.mouseProvider()
	for _, view in pairs(self.views) do
		-- view.tint = Anim.approach(view.tint, 1, 8, dt)
		view:update(dt, mouseX, mouseY)
	end
	self.enemyDeck:update(dt, mouseX, mouseY)
	self:updateFeedback(dt)
end

function GameView:drawList(deckBound)
	if deckBound then
		return {}
	end
	return self.views
end

return GameView
