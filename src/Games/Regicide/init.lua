local GameState = require("src.Games.Regicide.Model.gameState")
local GameView = require("src.Games.Regicide.View.gameView")
local ui = require("src.View.ui")

local Regicide = {
	id = "regicide",
	name = "REGICIDE",
	tagline = "Defeat the twelve corrupt royals",
	author = "by Paul Abrahams and Luke Badger",
	credits = "Regicide, a challenging solitaire game",
	color = "blue",
	showcase = { { 0, 13 }, { 3, 12 }, { 2, 13 }, { 1, 11 } },
	restartLabel = "NEW GAME",
	rules = require("src.Games.Regicide.rules"),
	options = {
		key = "regicideTarget", --[[TODO]]
	},
	records = {
		file = "regicide_records.txt",
		defaults = { --[[TODO]]
		},
	},
}

function Regicide.newState(settings)
	--return GameState:new(settings:get("regicideTarget"))
end

function Regicide.newView(context, gameState)
	--return GameView:new(context, gameState)
	local view = {}
	view.render = function(self)
		love.graphics.print("Not implemented yet", 100, 100)
	end
	view.update = function(self) end
	return view
end

function Regicide.playTag(_) end

function Regicide.registerResults(records, didWin, gameState)
	-- TODO
end

function Regicide.summary(result, record)
	-- TODO
	return {}
end

function Regicide.recordsText(records)
	-- TODO
	return "Defeat the nobelty"
end

function Regicide.recordsSummary(records)
	-- TODO
	return "No matches yet"
end

return Regicide
