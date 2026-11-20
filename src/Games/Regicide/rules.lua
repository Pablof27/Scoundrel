--[[
    Regicide "How to play" pages, shown by RulesView (see there for the page format).
]]

local Card   = require("src.Model.card")
local UI     = require("src.View.ui")
local Config = require("src.Games.Regicide.config")

local HEART, CLUB, DIAMOND, SPADE = Card.SUITS.HEART, Card.SUITS.CLUB, Card.SUITS.DIAMOND, Card.SUITS.SPADE
local ACE = Card.ACE
local SMALL = 0.62

local function label(view, text, cx, cy, color, font)
    UI.textCentered(text, cx, cy, font or view.assets.fonts.small, color or UI.colors.text)
end

return {
    {
        title = "THE CASTLE",
        text = "Regicide is a solo card game by Paul Abrahams, Luke Badger and Andy Richdale.\n\n" ..
            "Overthrow 12 corrupt Royals waiting in the Castle deck: 4 Jacks, then 4 Queens, " ..
            "then 4 Kings, one at a time.\n\n" ..
            "You fight with an 8-card hand drawn from the 40-card Tavern deck: 2 to 10 and " ..
            "4 Animal Companions (Aces, worth 1).",
        cards = {
            { suit = HEART,   rank = 11, x = -80, y = -34, s = SMALL },
            { suit = SPADE,   rank = 12, x = 0,   y = -34, s = SMALL },
            { suit = DIAMOND, rank = 13, x = 80,  y = -34, s = SMALL },
        },
        extras = function(self, ax, ay)
            local C, fonts = UI.colors, self.assets.fonts
            label(self, "4 JACKS",  ax - 80, ay - 76, C.gold)
            label(self, "4 QUEENS", ax,      ay - 76, C.gold)
            label(self, "4 KINGS",  ax + 80, ay - 76, C.gold)
            label(self, "20 HP",    ax - 80, ay + 12, C.heal)
            label(self, "10 ATK",   ax - 80, ay + 26, C.red)
            label(self, "30 HP",    ax,      ay + 12, C.heal)
            label(self, "15 ATK",   ax,      ay + 26, C.red)
            label(self, "40 HP",    ax + 80, ay + 12, C.heal)
            label(self, "20 ATK",   ax + 80, ay + 26, C.red)
            UI.box(ax - 118, ay + 52, 236, 44, C.panelInner, { radius = 6 })
            label(self, "TAVERN DECK: 40 CARDS", ax, ay + 65, C.text)
            label(self, "2-10 + Animal Companions (A = 1)  |  Max hand: 8", ax, ay + 82, C.textDim, fonts.tiny)
        end,
    },
    {
        title = "SUIT POWERS",
        text = "Play a card from your hand to deal its value as damage and trigger its suit power " ..
            "at your total attack value:\n\n" ..
            "HEARTS: shuffle the discard pile and move N cards under the Tavern deck.\n" ..
            "DIAMONDS: draw N cards (up to 8 in hand).\n" ..
            "CLUBS: deal double damage (2 x N).\n" ..
            "SPADES: shield -N against this Royal's attack.\n\n" ..
            "IMMUNITY: every Royal ignores its own suit! Hearts always resolve before Diamonds.",
        cards = {
            { suit = DIAMOND, rank = 8,   x = -34, y = -62, s = 0.56 },
            { suit = CLUB,    rank = ACE, x = 34,  y = -62, s = 0.56 },
        },
        extras = function(self, ax, ay)
            local C, fonts = UI.colors, self.assets.fonts
            label(self, "8 + A = 9 ATK  ->  Draw 9, Deal 18!", ax, ay - 22, C.gold)
            local rows = {
                { "heart",   "HEARTS",   "Heal N from Discard -> Tavern", C.heal },
                { "diamond", "DIAMONDS", "Draw N from Tavern (max 8)",    C.blue },
                { "club",    "CLUBS",    "Double damage dealt (x2)",      C.orange },
                { "spade",   "SPADES",   "Shield -N enemy ATK (stacks)",  C.purple },
            }
            for i, row in ipairs(rows) do
                local ry = ay - 6 + (i - 1) * 24
                UI.box(ax - 124, ry, 248, 20, C.panelInner, { radius = 4 })
                UI.icon(self.assets, row[1], ax - 118, ry + 4, 12, 1)
                UI.text(row[2], ax - 102, ry + 4, fonts.small, row[4])
                UI.text(row[3], ax - 36, ry + 6, fonts.tiny, C.text, { shadow = false })
            end
            label(self, "Enemy ignores powers matching its own suit!", ax, ay + 102, C.red, fonts.tiny)
        end,
    },
    {
        title = "COMPANIONS & COMBOS",
        text = "Instead of playing a single card, you can combine cards in two ways:\n\n" ..
            "ANIMAL COMPANION (A = 1): pair an Ace with ANY one other card, even a 10 or a " ..
            "captured Royal! Both suits trigger at their combined total (if different).\n\n" ..
            "COMBO: play 2, 3 or 4 cards of the SAME number (2s to 5s, never Aces) whose " ..
            "combined value is 10 or less.",
        cards = {
            { suit = HEART,   rank = ACE, x = -90, y = -50, s = 0.56 },
            { suit = SPADE,   rank = 10,  x = -42, y = -50, s = 0.56 },
            { suit = CLUB,    rank = 3,   x = 34,  y = -50, s = 0.56 },
            { suit = DIAMOND, rank = 3,   x = 70,  y = -50, s = 0.56 },
            { suit = HEART,   rank = 3,   x = 106, y = -50, s = 0.56 },
        },
        extras = function(self, ax, ay)
            local C, fonts = UI.colors, self.assets.fonts
            UI.box(ax - 110, ay - 98, 88, 18, C.green, { radius = 4, depth = 2 })
            label(self, "COMPANION", ax - 66, ay - 89, C.text)
            UI.box(ax + 34, ay - 98, 72, 18, C.purple, { radius = 4, depth = 2 })
            label(self, "COMBO", ax + 70, ay - 89, C.text)

            label(self, "A + 10 = 11", ax - 66, ay - 8, C.gold)
            label(self, "Heal 11 & Shield 11", ax - 66, ay + 6, C.textDim, fonts.tiny)
            label(self, "3 + 3 + 3 = 9", ax + 70, ay - 8, C.gold)
            label(self, "Total <= 10", ax + 70, ay + 6, C.textDim, fonts.tiny)

            UI.box(ax - 118, ay + 30, 236, 62, C.panelInner, { radius = 6 })
            label(self, "LEGAL COMBOS", ax, ay + 43, C.purple)
            label(self, "Pairs: 2+2, 3+3, 4+4, 5+5", ax, ay + 59, C.text, fonts.tiny)
            label(self, "Triples: 2+2+2, 3+3+3   |   Quads: 2+2+2+2", ax, ay + 74, C.text, fonts.tiny)
        end,
    },
    {
        title = "RECRUITING ROYALS",
        text = "Drop a Royal's HP to 0 or below to overthrow it! It never strikes back, and " ..
            "all cards played against it move to the discard pile.\n\n" ..
            "OVERKILL (< 0 HP): the defeated Royal goes to the discard pile (where Hearts " ..
            "can heal it into the Tavern deck).\n\n" ..
            "EXACT KILL (= 0 HP): the purified Royal goes face-down onto the TOP of the Tavern " ..
            "deck: you'll draw it next! In your hand, J = 10, Q = 15 and K = 20.",
        cards = {
            { suit = SPADE, rank = 11, x = -64, y = -40, s = SMALL },
            { suit = HEART, rank = 12, x = 64,  y = -40, s = SMALL },
        },
        extras = function(self, ax, ay)
            local C, fonts = UI.colors, self.assets.fonts
            UI.box(ax - 106, ay - 92, 84, 18, C.gold, { radius = 4, depth = 2 })
            label(self, "EXACT 0 HP", ax - 64, ay - 83, C.textDark)
            UI.box(ax + 22, ay - 92, 84, 18, C.heal, { radius = 4, depth = 2 })
            label(self, "BELOW 0 HP", ax + 64, ay - 83, C.text)

            label(self, "TOP OF TAVERN!", ax - 64, ay + 8, C.gold)
            label(self, "ready to draw next", ax - 64, ay + 22, C.textDim, fonts.tiny)
            label(self, "DISCARD PILE", ax + 64, ay + 8, C.heal)
            label(self, "healable with Hearts", ax + 64, ay + 22, C.textDim, fonts.tiny)

            UI.box(ax - 118, ay + 44, 236, 48, C.panelInner, { radius = 6 })
            label(self, "CAPTURED ROYALS IN YOUR HAND", ax, ay + 57, C.gold)
            label(self, "J = 10   |   Q = 15   |   K = 20   (attack or defend!)", ax, ay + 74, C.text, fonts.tiny)
        end,
    },
    {
        title = "DEFENSE & JESTERS",
        text = "If the Royal survives your attack, it strikes back! Discard cards from your hand " ..
            "totaling at least its ATK minus your Spades shield. If you can't cover the blow, " ..
            "or start an attack with no cards left, you lose.\n\n" ..
            "SOLO JESTERS: up to twice per game (before attacking OR before defending), flip a " ..
            "Jester to discard your hand and draw 8 fresh cards.\n\n" ..
            "Win with 0, 1 or 2 Jesters used for a Gold, Silver or Bronze Victory!",
        extras = function(self, ax, ay)
            local C, fonts = UI.colors, self.assets.fonts
            UI.box(ax - 118, ay - 96, 236, 52, C.panelInner, { radius = 6 })
            label(self, "ROYAL COUNTERATTACK", ax, ay - 82, C.red)
            label(self, "Queen (15 ATK) - 6 Spades Shield = Discard 9+", ax, ay - 62, C.text, fonts.tiny)

            UI.box(ax - 118, ay - 32, 236, 44, C.panelInner, { radius = 6 })
            label(self, "SOLO JESTER (x2)", ax, ay - 18, C.purple)
            label(self, "Discard hand -> Draw 8 cards (Step 1 or Step 4)", ax, ay - 1, C.text, fonts.tiny)

            local tiers = {
                { "GOLD",   "0 Jesters", C.gold,   C.textDark },
                { "SILVER", "1 Jester",  C.blue,   C.text },
                { "BRONZE", "2 Jesters", C.orange, C.text },
            }
            for i, t in ipairs(tiers) do
                local cx = ax + (i - 2) * 82
                UI.box(cx - 36, ay + 28, 72, 22, t[3], { radius = 5, depth = 2 })
                UI.textCentered(t[1], cx, ay + 39, fonts.medium, t[4], { shadow = t[3] ~= C.gold })
                label(self, t[2], cx, ay + 62, C.textDim, fonts.tiny)
            end
            label(self, "Adjustable in SETTINGS (2, 1 or 0 Jesters)", ax, ay + 90, C.textDim, fonts.tiny)
        end,
    },
    {
        title = "CONTROLS",
        text = "Click cards in your hand (or press 1-8) to build an attack or choose cards to " ..
            "discard for defense. Right-click or Backspace clears your selection.\n\n" ..
            "ATTACK / DEFEND (Enter or Space) confirms your selection.\n\n" ..
            "JESTER (J, click twice) flips a Solo Jester to refresh your hand.\n\n" ..
            "Watch the Royal's HP bar and the sidebar for live previews. ESC opens the menu.",
        cards = {
            { suit = CLUB, rank = 7, x = 0, y = -52, s = SMALL },
        },
        extras = function(self, ax, ay)
            local C, fonts = UI.colors, self.assets.fonts
            UI.box(ax - 112, ay + 4, 224, 38, C.panelInner, { radius = 6 })
            UI.box(ax - 104, ay + 10, 56, 16, C.gold, { radius = 4, depth = 2 })
            UI.textCentered("EXACT!", ax - 76, ay + 18, fonts.small, C.textDark, { shadow = false })
            label(self, "7 -> 14 DMG (Clubs x2)", ax + 24, ay + 18, C.text)
            label(self, "Royal joins TOP of Tavern!", ax, ay + 33, C.gold, fonts.tiny)

            UI.box(ax - 110, ay + 58, 102, 22, C.blue, { radius = 4, depth = 2 })
            label(self, "ATTACK [ENTER]", ax - 59, ay + 69, C.text)
            UI.box(ax + 8, ay + 58, 102, 22, C.purple, { radius = 4, depth = 2 })
            label(self, "JESTER (2) [J]", ax + 59, ay + 69, C.text)
            label(self, "1-8: toggle cards   |   Right-click: clear", ax, ay + 96, C.textDim, fonts.tiny)
        end,
    },
}
