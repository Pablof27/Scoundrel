--[[
    Scoundrel "How to play" pages, shown by RulesView.
    Each page has a title and either `text` (left column) plus an illustration on the right
    (`cards` and `extras`, positioned relative to the illustration center), or `columns`.
    Cards are given by suit and rank; `extras(view, ax, ay)` draws the rest of the illustration.
]]

local Card   = require("src.Model.card")
local UI     = require("src.View.ui")
local Config = require("src.Games.Scoundrel.config")

local HEART, CLUB, DIAMOND, SPADE = Card.SUITS.HEART, Card.SUITS.CLUB, Card.SUITS.DIAMOND, Card.SUITS.SPADE

-- Rules each difficulty changes, as rows of the comparison table on the DIFFICULTY page.
local DIFFICULTY_ROWS = {
    { label = "Whole dungeon", rule = "clearDungeon" },
    { label = "Equal slays",   rule = "weaponSlaysEqual" },
    { label = "Best score",    rule = "ranked" },
}

local function difficultyText()
    local parts = { "Choose the difficulty in SETTINGS. It applies from your next run." }
    for _, difficulty in ipairs(Config.DIFFICULTIES) do
        table.insert(parts, difficulty.name:upper() .. ": " .. difficulty.description)
    end
    return table.concat(parts, "\n\n")
end

return {
    {
        title = "THE DUNGEON",
        text = "You are a scoundrel delving into a dungeon made from a deck of cards.\n\n" ..
            "The dungeon holds 44 cards: every club and spade, plus the hearts and diamonds " ..
            "from 2 to 10. Red face cards and aces are left out.\n\n" ..
            "You start with 20 health. Make it through the dungeon to escape: how much of it you must " ..
            "resolve depends on the difficulty. If your health drops to 0, you die.",
        cards = {
            { faceUp = false, x = -62, y = -4 },
            { faceUp = false, x = -60, y = -7 },
            { faceUp = false, x = -58, y = -10 },
        },
        extras = function(self, ax, ay)
            local C, fonts = UI.colors, self.assets.fonts
            UI.textCentered("44 CARDS", ax - 58, ay + 56, fonts.small, C.text)
            UI.icon(self.assets, "heart", ax + 38, ay - 44, 48)
            UI.textCentered("20", ax + 62, ay - 20, fonts.large, C.text, { shadowDepth = 2 })
            UI.textCentered("HEALTH", ax + 62, ay + 18, fonts.small, C.text)
        end,
    },
    {
        title = "THE CARDS",
        columns = {
            { suit = SPADE, rank = 12, title = "MONSTERS", color = "red",
              text = "Clubs and spades deal damage equal to their value.\nJ = 11, Q = 12, K = 13, A = 14." },
            { suit = DIAMOND, rank = 7, title = "WEAPONS", color = "orange",
              text = "Diamonds reduce a monster's damage by their value. Equipping one discards the old one." },
            { suit = HEART, rank = 5, title = "POTIONS", color = "green",
              text = "Hearts heal their value, up to 20. Only one potion per room works: the next is wasted." },
        },
        footer = "During a run, hover any card to see exactly what it will do.",
    },
    {
        title = "ROOMS",
        text = "Each room deals 4 cards from the dungeon. Resolve 3 of them, one at a time, in any order.\n\n" ..
            "The 4th card stays and becomes part of the next room, which is dealt automatically.\n\n" ..
            "Before resolving any card you may FLEE: the whole room goes to the bottom of the " ..
            "dungeon and a new one is dealt. You can never flee two rooms in a row.",
        cards = {
            { suit = CLUB, rank = 9, x = -96, y = -34, s = 0.72 },
            { suit = HEART, rank = 4, x = -32, y = -34, s = 0.72 },
            { suit = SPADE, rank = 11, x = 32, y = -34, s = 0.72 },
            { suit = DIAMOND, rank = 6, x = 96, y = -34, s = 0.72 },
        },
        extras = function(self, ax, ay)
            local C, fonts = UI.colors, self.assets.fonts
            for i, dx in ipairs({ -96, -32, 32 }) do
                UI.textCentered(tostring(i), ax + dx, ay + 12, fonts.medium, C.heal)
            end
            UI.textCentered("STAYS", ax + 96, ay + 12, fonts.small, C.gold)
            UI.box(ax - 40, ay + 42, 80, 24, C.red, { radius = 5, depth = 3 })
            UI.textCentered("FLEE", ax, ay + 54, fonts.medium, C.text)
            UI.textCentered("skip the whole room (not twice in a row)", ax, ay + 80, fonts.small, C.text)
        end,
    },
    {
        title = "COMBAT",
        text = "Barehanded, a monster hits you for its full value.\n\n" ..
            "With a weapon you take the monster's value minus the weapon's (never below 0) " ..
            "and the monster is stacked on the weapon.\n\n" ..
            "From then on, the weapon only slays monsters weaker than the last one it killed " ..
            "(on Easy, also as strong). You can always fight barehanded instead to keep your weapon fresh.",
        cards = {
            { suit = DIAMOND, rank = 5, x = -78, y = -8 },
            { suit = SPADE, rank = 12, x = -54, y = -6, r = 0.03 },
            { suit = CLUB, rank = 11, x = 70, y = -52, s = 0.62 },
            { suit = SPADE, rank = 13, x = 70, y = 40, s = 0.62 },
        },
        extras = function(self, ax, ay)
            local C, fonts = UI.colors, self.assets.fonts
            UI.textCentered("a 5 that slew a Q", ax - 66, ay + 52, fonts.small, C.text)
            UI.box(ax + 30, ay - 18, 80, 16, C.orange, { radius = 4, depth = 2 })
            UI.textCentered("WEAPON -6", ax + 70, ay - 10, fonts.small, C.text)
            UI.box(ax + 30, ay + 74, 80, 16, C.red, { radius = 4, depth = 2 })
            UI.textCentered("FISTS -13", ax + 70, ay + 82, fonts.small, C.text)
            UI.textCentered("J < Q: weapon works", ax + 70, ay - 94, fonts.small, C.text)
            UI.textCentered("K > Q: too strong", ax + 70, ay + 100, fonts.small, C.text)
        end,
    },
    {
        title = "DIFFICULTY",
        text = difficultyText(),
        extras = function(self, ax, ay)
            local C, fonts = UI.colors, self.assets.fonts
            local font = fonts.small
            local selected = self.settings:get("difficulty")
            for i, difficulty in ipairs(Config.DIFFICULTIES) do
                local cx = ax - 26 + (i - 1) * 64
                if difficulty.key == selected then
                    UI.box(cx - 31, ay - 86, 62, 154, C.panelLight, { radius = 6, alpha = 0.4 })
                    UI.textCentered("SELECTED", cx, ay + 58, fonts.tiny, C.gold)
                end
                UI.box(cx - 29, ay - 78, 58, 18, C[difficulty.color], { radius = 4, depth = 2 })
                UI.textCentered(difficulty.name:upper(), cx, ay - 69, font, C.text)
                for j, row in ipairs(DIFFICULTY_ROWS) do
                    local on = difficulty[row.rule]
                    UI.textCentered(on and "YES" or "-", cx, ay - 34 + (j - 1) * 30, font, on and C.heal or C.textDim)
                end
            end
            for j, row in ipairs(DIFFICULTY_ROWS) do
                UI.text(row.label, ax - 130, ay - 34 + (j - 1) * 30 - font:getHeight() / 2, font, C.text)
            end
            UI.textCentered("change it in SETTINGS", ax, ay + 92, font, C.textDim)
        end,
    },
    {
        title = "CONTROLS & SCORE",
        text = "Hover a card to see exactly what it will do. Click it to play it.\n\n" ..
            "Monsters: click the card to use your weapon, or click FISTS (or right-click the card) " ..
            "to fight barehanded.\n\n" ..
            "UNDO (U) takes back cards resolved in the current room. ESC opens the menu.\n\n" ..
            "Score: escaping scores your remaining health (plus the potion if your last card was one, " ..
            "drunk at full health). Dying scores your health minus every monster left.",
        cards = {
            { suit = CLUB, rank = 9, x = 0, y = -46 },
        },
        extras = function(self, ax, ay)
            local C, fonts = UI.colors, self.assets.fonts
            UI.box(ax - 38, ay + 8, 77, 18, C.orange, { radius = 4, depth = 2 })
            UI.text("WEAPON", ax - 33, ay + 11, fonts.small, C.text)
            UI.text("-4", ax + 33 - fonts.small:getWidth("-4"), ay + 11, fonts.small, C.text)
            UI.box(ax - 38, ay + 29, 77, 18, C.red, { radius = 4, depth = 2 })
            UI.text("FISTS", ax - 33, ay + 32, fonts.small, C.text)
            UI.text("-9", ax + 33 - fonts.small:getWidth("-9"), ay + 32, fonts.small, C.text)
            UI.textCentered("click the card = main action", ax, ay + 66, fonts.small, C.text)
            UI.textCentered("click a tab = that action", ax, ay + 80, fonts.small, C.text)
        end,
    },
}
