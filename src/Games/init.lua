--[[
    Games
    The games of the library, in the order they are listed. Each game lives in src/Games/<Name>/
    (its rules model, actions and board) and is described by its init.lua, a table with:
      id                          unique key, also keeps its records apart
      name, tagline, author       its panel in the library
      credits                     line under its title on its home screen
      color                       UI.colors entry of its panel
      showcase                    { { suit, rank }, ... } cards fanned on its home screen and library panel
      restartLabel                text of the pause menu's restart button
      rules                       "How to play" pages (see RulesView)
      options                     its own settings, stored with the general ones (see Settings.OPTIONS)
      records                     { file, defaults }: its lifetime statistics (see Records)
      newState(settings)          the state of a new game, run by the Game controller
      newView(context, state)     the board that plays it (see BoardView)
      registerResult(records, didWin, state)  saves a finished game; returns what `summary` receives
      summary(result, record)     content of the end screen (see EndGameView)
      recordsText(records)        records line of its home screen
      recordsSummary(records)     records line of its library panel
      playTag(settings)           optional { label, color } shown under PLAY (rules new games will use)
]]

local Games = {
    require("src.Games.Scoundrel"),
    require("src.Games.Lobo"),
}

Games.byId = {}
for _, game in ipairs(Games) do
    Games.byId[game.id] = game
end

-- The settings declared by every game.
function Games.options()
    local options = {}
    for _, game in ipairs(Games) do
        for _, option in ipairs(game.options or {}) do
            table.insert(options, option)
        end
    end
    return options
end

return Games
