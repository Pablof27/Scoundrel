--[[
    Regicide
    A solo/cooperative fantasy card game by Paul Abrahams, Luke Badger and Andy Richdale
    (Badgers From Mars): overthrow 12 corrupt Royals using suit powers, Animal Companions and
    clever hand management. Game descriptor, registered in src/Games/init.lua.
]]

local UI          = require("src.View.ui")
local Config      = require("src.Games.Regicide.config")
local GameState   = require("src.Games.Regicide.Model.gameState")
local GameView    = require("src.Games.Regicide.View.gameView")

local Regicide = {
    id           = "regicide",
    name         = "REGICIDE",
    tagline      = "Overthrow the twelve royals",
    author       = "by Badgers From Mars",
    credits      = "Regicide, by Paul Abrahams, Luke Badger and Andy Richdale",
    color        = "blue",
    showcase     = { { 0, 13 }, { 3, 12 }, { 2, 13 }, { 1, 11 } },
    restartLabel = "NEW GAME",
    rules        = require("src.Games.Regicide.rules"),
    options = {
        { key = "regicideJesters", label = "Solo Jesters", values = Config.JESTER_COUNTS, names = Config.JESTER_NAMES,
          default = Config.DEFAULT_JESTERS, details = Config.JESTER_DETAILS, note = "Applies from your next game." },
    },
    records = {
        file = "regicide_records.txt",
        defaults = {
            gamesPlayed    = 0,
            gamesWon       = 0,
            bestRoyals     = 0,
            bestTier       = 0,  -- 0 = none, 1 = Bronze, 2 = Silver, 3 = Gold
            royalsDefeated = 0,
            exactKills     = 0,
        },
    },
}

function Regicide.newState(settings)
    return GameState:new(settings:get("regicideJesters"))
end

function Regicide.newView(context, gameState)
    return GameView:new(context, gameState)
end

function Regicide.playTag(settings)
    local jesters = settings:get("regicideJesters")
    if jesters == 0 then
        return { label = "Gold Challenge", color = "gold" }
    elseif jesters == 1 then
        return { label = "1 Jester", color = "purple" }
    end
    return { label = "2 Jesters", color = "blue" }
end

function Regicide.registerResult(records, didWin, gameState)
    local stats = gameState.stats
    local royals = stats.royalsDefeated
    local tier = gameState:victoryTier()

    records:add("gamesPlayed")
    if didWin then
        records:add("gamesWon")
    end
    records:add("royalsDefeated", royals)
    records:add("exactKills", stats.exactKills)

    local prevBestRoyals = records:get("bestRoyals")
    local prevBestTier = records:get("bestTier")
    local isBest = false
    if tier > prevBestTier then
        records:set("bestTier", tier)
        isBest = true
    end
    if royals > prevBestRoyals then
        records:set("bestRoyals", royals)
        if prevBestTier == 0 then
            isBest = true
        end
    end
    records:save()

    return { royals = royals, tier = tier, isBest = isBest }
end

function Regicide.summary(result, record)
    local C = UI.colors
    local state = result.gameState
    local stats = state.stats

    local title, titleColor, subtitle, scoreNote
    if result.didWin then
        local tierInfo = Config.TIERS[record.tier]
        title = tierInfo.title
        titleColor = C[tierInfo.color]
        local used = state.jokersUsed
        subtitle = "All 12 Royals overthrown" ..
            (used == 0 and " without flipping a single Jester!"
                or (" with " .. used .. (used == 1 and " Jester flipped." or " Jesters flipped.")))
        scoreNote = tierInfo.name .. " Victory\n" .. used .. (used == 1 and " Jester used" or " Jesters used")
    else
        title = "THE CROWN STANDS"
        titleColor = C.red
        if state.currentEnemy then
            local royal = Config.ROYALS[state.currentEnemy.rank].name
            local suit = Config.SUIT_BY_ID[state.currentEnemy.suit].name
            local why = state.loseReason == "noCards" and "Ran out of cards against the "
                or "Overwhelmed by the "
            subtitle = why .. royal .. " of " .. suit .. "."
        else
            subtitle = "Your rebellion fell short."
        end
        local remaining = Config.TOTAL_ROYALS - stats.royalsDefeated
        scoreNote = remaining .. (remaining == 1 and " Royal left\nin the Castle" or " Royals left\nin the Castle")
    end

    local tierLabel = result.didWin and (Config.TIERS[record.tier].name .. " Victory") or "Defeat"
    local tierColor = result.didWin and C[Config.TIERS[record.tier].color] or C.red

    return {
        title      = title,
        titleColor = titleColor,
        subtitle   = subtitle,
        scoreLabel = "ROYALS OVERTHROWN",
        score      = record.royals,
        isBest     = record.isBest,
        scoreNote  = scoreNote,
        rows = {
            { label = "Result",          value = tierLabel, color = tierColor },
            { label = "Jesters used",    value = state.jokersUsed .. " / " .. state.maxJokers },
            { label = "Turns played",    value = stats.turnsPlayed },
            { label = "Time",            value = UI.formatTime(result.runTime) },
            { label = "Exact kills",     value = stats.exactKills, color = stats.exactKills > 0 and C.gold or nil },
            { label = "Cards played",    value = stats.cardsPlayed },
            { label = "Damage dealt",    value = stats.damageDealt },
            { label = "Damage blocked",  value = stats.damageBlocked },
            { label = "Cards healed",    value = stats.cardsHealed },
            { label = "Cards drawn",     value = stats.cardsDrawn },
            { label = "Cards discarded", value = stats.cardsDiscarded },
        },
    }
end

function Regicide.recordsText(records)
    local played = records:get("gamesPlayed")
    if played == 0 then
        return "Overthrow 4 Jacks, 4 Queens and 4 Kings. Win without Jesters for a Gold Victory."
    end
    local bestTier = records:get("bestTier")
    local bestNote = bestTier > 0
        and ("Best: " .. Config.TIERS[bestTier].name .. " Victory")
        or ("Best run: " .. records:get("bestRoyals") .. "/12 royals")
    return "Games " .. played .. "     Won " .. records:get("gamesWon") ..
        "     Royals overthrown " .. records:get("royalsDefeated") ..
        "     Exact kills " .. records:get("exactKills") ..
        "     " .. bestNote
end

function Regicide.recordsSummary(records)
    local played = records:get("gamesPlayed")
    if played == 0 then
        return "No games yet"
    end
    local bestTier = records:get("bestTier")
    if bestTier > 0 then
        return "Won " .. records:get("gamesWon") .. "/" .. played .. "   " .. Config.TIERS[bestTier].name
    end
    return "Games " .. played .. "   Best " .. records:get("bestRoyals") .. "/12"
end

return Regicide

