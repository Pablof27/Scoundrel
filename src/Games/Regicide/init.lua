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
	-- options = {
	-- 	key = "regicideTarget", --[[TODO]]
	-- },
	records = {
		file = "regicide_records.txt",
		defaults = { --[[TODO]]
		},
	},
}

function Regicide.newState(_)
	return GameState:new()
end

function Regicide.newView(context, gameState)
	return GameView:new(context, gameState)
end

function Regicide.playTag(_) end

function Regicide.registerResult(records, didWin, gameState)
	local _ = gameState.stats
	records:add("matchesPlayed")
	if didWin then
		records:add("matchesWon")
	end
	records:save()
	return {}
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
