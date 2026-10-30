--[[
    Scoundrel
    A solo roguelike card game by Zach Gage and Kurt Bieg: make it through a dungeon made from a
    deck of cards. Game descriptor, registered in src/Games/init.lua (which documents the fields).
]]

local UI          = require("src.View.ui")
local Config      = require("src.Games.Scoundrel.config")
local GameState   = require("src.Games.Scoundrel.Model.gameState")
local GameView    = require("src.Games.Scoundrel.View.gameView")
local SidebarView = require("src.Games.Scoundrel.View.sidebarView")

local DIFFICULTY_KEYS, DIFFICULTY_NAMES, DIFFICULTY_DETAILS = {}, {}, {}
for i, difficulty in ipairs(Config.DIFFICULTIES) do
    DIFFICULTY_KEYS[i] = difficulty.key
    DIFFICULTY_NAMES[i] = difficulty.name
    DIFFICULTY_DETAILS[i] = difficulty.description
end

local Scoundrel = {
    id           = "scoundrel",
    name         = "SCOUNDREL",
    tagline      = "A roguelike dungeon crawl",
    author       = "by Zach Gage and Kurt Bieg",
    credits      = "A solo roguelike card game by Zach Gage and Kurt Bieg",
    color        = "red",
    -- suit, rank: A of spades, K of clubs, 10 of diamonds, 7 of hearts, Q of spades
    showcase     = { { 3, 14 }, { 1, 13 }, { 2, 10 }, { 0, 7 }, { 3, 12 } },
    restartLabel = "RESTART RUN",
    rules        = require("src.Games.Scoundrel.rules"),
    options = {
        -- The key predates the library: kept so saved settings still apply.
        { key = "difficulty", label = "Difficulty", values = DIFFICULTY_KEYS, names = DIFFICULTY_NAMES,
          default = Config.DEFAULT_DIFFICULTY, details = DIFFICULTY_DETAILS, note = "Applies from your next run." },
    },
    records = {
        file = "records.txt",
        defaults = { gamesPlayed = 0, gamesWon = 0, hasBestScore = false, bestScore = 0 },
    },
}

-- New runs use the difficulty currently chosen in the settings.
function Scoundrel.newState(settings)
    return GameState:new(settings:get("difficulty"))
end

function Scoundrel.newView(context, gameState)
    return GameView:new(context, gameState)
end

function Scoundrel.playTag(settings)
    local difficulty = Config.difficulty(settings:get("difficulty"))
    return { label = difficulty.name, color = difficulty.color }
end

-- Every run counts towards runs played and escapes; only ranked runs (Difficult) can set the best score.
function Scoundrel.registerResult(records, didWin, gameState)
    local score = gameState:score()
    records:add("gamesPlayed")
    if didWin then
        records:add("gamesWon")
    end
    local isBest = gameState.difficulty.ranked and (not records:get("hasBestScore") or score > records:get("bestScore"))
    if isBest then
        records:set("hasBestScore", true)
        records:set("bestScore", score)
    end
    records:save()
    return { score = score, isBest = isBest }
end

-- End-of-run summary: official Scoundrel scoring, difficulty and the statistics of the run.
function Scoundrel.summary(result, record)
    local C = UI.colors
    local gameState = result.gameState
    local difficulty = gameState.difficulty
    local subtitle
    if not result.didWin then
        subtitle = "The dungeon claimed you in room " .. gameState.roomNumber .. "."
    elseif difficulty.clearDungeon then
        subtitle = "You made it through the whole dungeon."
    else
        subtitle = "Too few cards were left for another room: you made it out."
    end

    local rows = {
        { label = "Difficulty", value = difficulty.name, color = C[difficulty.color] },
        { label = "Rooms explored", value = gameState.roomNumber },
        { label = "Time", value = UI.formatTime(result.runTime) },
    }
    for _, row in ipairs(SidebarView.STAT_ROWS) do
        table.insert(rows, { label = row.label, value = gameState.stats[row.key] })
    end

    return {
        title      = result.didWin and "YOU ESCAPED!" or "YOU DIED",
        titleColor = result.didWin and C.gold or C.red,
        subtitle   = subtitle,
        scoreLabel = "SCORE",
        score      = record.score,
        isBest     = record.isBest,
        scoreNote  = not difficulty.ranked and "Only Difficult runs\nset a best score" or nil,
        rows       = rows,
    }
end

-- Footer of the home screen.
function Scoundrel.recordsText(records)
    local played = records:get("gamesPlayed")
    if played == 0 then
        return "Survive the 44-card dungeon. Good luck, scoundrel."
    end
    local text = "Runs " .. played .. "     Escaped " .. records:get("gamesWon")
    if records:get("hasBestScore") then
        text = text .. "     Best score " .. records:get("bestScore")
    end
    return text
end

-- One line for the game's panel in the library.
function Scoundrel.recordsSummary(records)
    local played = records:get("gamesPlayed")
    if played == 0 then
        return "No runs yet"
    end
    return "Runs " .. played .. "   Escaped " .. records:get("gamesWon")
end

return Scoundrel
