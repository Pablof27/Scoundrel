--[[
    Lobo (The Wolf)
    A solitaire game by James Ernest (Crab Fragment Labs): capture the Wolf's cards with yours, hand
    after hand, racing the Wolf to 100 points. Game descriptor, registered in src/Games/init.lua
    (which documents the fields).
]]

local UI        = require("src.View.ui")
local Config    = require("src.Games.Lobo.config")
local GameState = require("src.Games.Lobo.Model.gameState")
local GameView  = require("src.Games.Lobo.View.gameView")

local Lobo = {
    id           = "lobo",
    name         = "LOBO",
    tagline      = "Hunt down the Wolf's cards",
    author       = "by James Ernest",
    credits      = "Lobo (The Wolf), a solitaire game by James Ernest",
    color        = "purple",
    -- suit, rank (aces are worth 1): A of gold spades, 9 of hearts, 5 of clubs, 4 of diamonds, 10 of spades
    showcase     = { { 4, 14 }, { 0, 9 }, { 1, 5 }, { 2, 4 }, { 3, 10 } },
    restartLabel = "RESTART MATCH",
    rules        = require("src.Games.Lobo.rules"),
    options = {
        { key = "loboTarget", label = "Match length", values = Config.TARGETS, names = Config.TARGET_NAMES,
          default = Config.DEFAULT_TARGET, details = Config.TARGET_DETAILS, note = "Applies from your next match." },
    },
    records = {
        file = "lobo_records.txt",
        defaults = { matchesPlayed = 0, matchesWon = 0, handsPlayed = 0, handsWon = 0, bestHand = 0 },
    },
}

-- New matches use the length currently chosen in the settings.
function Lobo.newState(settings)
    return GameState:new(settings:get("loboTarget"))
end

function Lobo.newView(context, gameState)
    return GameView:new(context, gameState)
end

function Lobo.playTag(settings)
    return { label = "Match to " .. settings:get("loboTarget"), color = "purple" }
end

-- Every finished match counts, with its hands; the best hand is the most points scored in one hand.
function Lobo.registerResult(records, didWin, gameState)
    local stats = gameState.stats
    records:add("matchesPlayed")
    if didWin then
        records:add("matchesWon")
    end
    records:add("handsPlayed", stats.handsPlayed)
    records:add("handsWon", stats.handsWon)
    local isBestHand = stats.bestHand > records:get("bestHand")
    if isBestHand then
        records:set("bestHand", stats.bestHand)
    end
    records:save()
    return { score = gameState.scores.player, isBestHand = isBestHand }
end

function Lobo.summary(result, record)
    local C = UI.colors
    local state = result.gameState
    local stats = state.stats
    local hands = stats.handsPlayed
    return {
        title      = result.didWin and "YOU BEAT THE WOLF!" or "THE WOLF WINS",
        titleColor = result.didWin and C.gold or C.red,
        subtitle   = "Final score " .. state.scores.player .. " to " .. state.scores.wolf .. " after " ..
            hands .. (hands == 1 and " hand." or " hands."),
        scoreLabel = "YOUR POINTS",
        score      = record.score,
        isBest     = false,
        scoreNote  = "The Wolf\n" .. state.scores.wolf .. " points",
        rows = {
            { label = "Match", value = "To " .. state.target },
            { label = "Hands played", value = hands },
            { label = "Hands won", value = stats.handsWon },
            { label = "Best hand", value = (record.isBestHand and "NEW! " or "") .. stats.bestHand,
              color = record.isBestHand and C.gold or nil },
            { label = "Folds", value = stats.folds },
            { label = "Hands with no move", value = stats.stuck },
            { label = "Time", value = UI.formatTime(result.runTime) },
            { label = "Perfects", value = stats.perfects },
            { label = "Sums", value = stats.sums },
            { label = "Splits", value = stats.splits },
            { label = "Overs", value = stats.overs },
            { label = "Wolf cards captured", value = stats.captured },
            { label = "Cards the Wolf drew", value = stats.wolfDraws },
            { label = "Shuffles", value = stats.shuffles },
        },
    }
end

-- Footer of the home screen.
function Lobo.recordsText(records)
    local played = records:get("matchesPlayed")
    if played == 0 then
        return "Empty the Wolf's hand, or lose as little as you can: the wolf takes small bites."
    end
    return "Matches " .. played .. "     Won " .. records:get("matchesWon") .. "     Hands won " ..
        records:get("handsWon") .. " of " .. records:get("handsPlayed") .. "     Best hand " .. records:get("bestHand")
end

-- One line for the game's panel in the library.
function Lobo.recordsSummary(records)
    local played = records:get("matchesPlayed")
    if played == 0 then
        return "No matches yet"
    end
    return "Matches " .. played .. "   Won " .. records:get("matchesWon")
end

return Lobo
