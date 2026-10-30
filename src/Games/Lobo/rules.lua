--[[
    Lobo "How to play" pages, shown by RulesView (see there for the page format).
    Cards are given by suit and rank: aces (rank 14) are worth 1 in Lobo.
]]

local Card = require("src.Model.card")
local UI   = require("src.View.ui")

local HEART, CLUB, DIAMOND, SPADE, GOLD = Card.SUITS.HEART, Card.SUITS.CLUB, Card.SUITS.DIAMOND,
    Card.SUITS.SPADE, Card.SUITS.GOLD_SPADE
local ACE = Card.ACE
local SMALL = 0.62

local function label(view, text, cx, cy, color, font)
    UI.textCentered(text, cx, cy, font or view.assets.fonts.small, color or UI.colors.text)
end

return {
    {
        title = "THE WOLF",
        text = "Lobo is a solitaire game by James Ernest. The Wolf's hand is the row at the top, yours is " ..
            "the row at the bottom: four cards each.\n\n" ..
            "Only you take turns. Capture the Wolf's cards with yours until its hand is empty.\n\n" ..
            "The deck has 50 cards: aces (worth 1) to 10 in five suits. Suits don't matter, only values.",
        cards = {
            { suit = SPADE, rank = 7, x = -87, y = -50, s = SMALL },
            { suit = HEART, rank = 3, x = -29, y = -50, s = SMALL },
            { suit = GOLD, rank = 9, x = 29, y = -50, s = SMALL },
            { suit = CLUB, rank = 5, x = 87, y = -50, s = SMALL },
            { suit = DIAMOND, rank = 2, x = -87, y = 48, s = SMALL },
            { suit = CLUB, rank = 9, x = -29, y = 48, s = SMALL },
            { suit = HEART, rank = 6, x = 29, y = 48, s = SMALL },
            { suit = GOLD, rank = ACE, x = 87, y = 48, s = SMALL },
        },
        extras = function(self, ax, ay)
            local C = UI.colors
            label(self, "THE WOLF", ax, ay - 98, C.red)
            label(self, "YOU", ax, ay + 96, C.gold)
            label(self, "A = 1", ax + 87, ay + 108, C.textDim, self.assets.fonts.tiny)
        end,
    },
    {
        title = "THE CUB",
        text = "The top card of the deck, the cub, is always face up: it is the next card anyone draws. " ..
            "The cards below it stay unknown until they are drawn.\n\n" ..
            "After a capture someone draws: you take the cub after a Perfect or a Sum, the Wolf after a " ..
            "Split or an Over.\n\n" ..
            "The deck is only shuffled every third hand, so the cards already played tell you what is left. " ..
            "The sidebar counts them for you.",
        cards = {
            { faceUp = false, x = -50, y = 10 },
            { faceUp = false, x = -48, y = 7 },
            { faceUp = false, x = -46, y = 4 },
            { suit = DIAMOND, rank = 7, x = -44, y = 1 },
            { suit = HEART, rank = 4, x = 66, y = 4, s = SMALL },
        },
        extras = function(self, ax, ay)
            local C = UI.colors
            label(self, "THE CUB", ax - 44, ay - 60, C.gold)
            label(self, "unknown cards below", ax - 46, ay + 70, C.textDim)
            label(self, "seen: count on it", ax + 66, ay - 46, C.textDim)
            label(self, "1 2 3 4 5 6 7 8 9 10", ax + 66, ay + 52, C.textDim, self.assets.fonts.tiny)
            label(self, "5 5 4 3 5 4 2 5 5 5", ax + 66, ay + 64, C.text, self.assets.fonts.tiny)
        end,
    },
    {
        title = "PERFECT & SUM",
        text = "PERFECT: play one card to capture a Wolf card of the same value. 9 takes 9.\n\n" ..
            "SUM: play two or more cards that add up exactly to one Wolf card. 6 + 4 takes 10, " ..
            "1 + 1 + 3 takes 5.\n\n" ..
            "All the cards involved are discarded, then you take the cub into your hand.",
        cards = {
            { suit = SPADE, rank = 9, x = -66, y = -56, s = SMALL },
            { suit = HEART, rank = 9, x = -66, y = 42, s = SMALL },
            { suit = CLUB, rank = 10, x = 62, y = -56, s = SMALL },
            { suit = DIAMOND, rank = 6, x = 37, y = 42, s = SMALL },
            { suit = GOLD, rank = 4, x = 87, y = 42, s = SMALL },
        },
        extras = function(self, ax, ay)
            local C = UI.colors
            UI.box(ax - 104, ay - 106, 76, 18, C.gold, { radius = 4, depth = 2 })
            label(self, "PERFECT", ax - 66, ay - 97, C.text)
            UI.box(ax + 32, ay - 106, 60, 18, C.blue, { radius = 4, depth = 2 })
            label(self, "SUM", ax + 62, ay - 97, C.text)
            label(self, "9 takes 9", ax - 66, ay - 8, C.text)
            label(self, "6 + 4 takes 10", ax + 62, ay - 8, C.text)
            label(self, "then you take the cub", ax, ay + 98, C.heal)
        end,
    },
    {
        title = "SPLIT & OVER",
        text = "SPLIT: play one card to capture two or more Wolf cards that add up exactly to it. " ..
            "9 takes 6 + 3. Then the Wolf takes the cub.\n\n" ..
            "OVER: play one card to capture one smaller Wolf card. 9 takes 7. Then the Wolf takes one card " ..
            "per point of difference: the cub first, then unknown cards.\n\n" ..
            "A big Over feeds the Wolf: use it with care.",
        cards = {
            { suit = HEART, rank = 6, x = -91, y = -56, s = SMALL },
            { suit = CLUB, rank = 3, x = -41, y = -56, s = SMALL },
            { suit = SPADE, rank = 9, x = -66, y = 42, s = SMALL },
            { suit = DIAMOND, rank = 7, x = 66, y = -56, s = SMALL },
            { suit = GOLD, rank = 9, x = 66, y = 42, s = SMALL },
        },
        extras = function(self, ax, ay)
            local C = UI.colors
            UI.box(ax - 98, ay - 106, 64, 18, C.purple, { radius = 4, depth = 2 })
            label(self, "SPLIT", ax - 66, ay - 97, C.text)
            UI.box(ax + 36, ay - 106, 60, 18, C.red, { radius = 4, depth = 2 })
            label(self, "OVER", ax + 66, ay - 97, C.text)
            label(self, "9 takes 6 + 3", ax - 66, ay - 8, C.text)
            label(self, "9 takes 7", ax + 66, ay - 8, C.text)
            label(self, "Wolf takes the cub", ax - 66, ay + 90, C.damage)
            label(self, "Wolf takes 2 cards", ax + 66, ay + 90, C.damage)
        end,
    },
    {
        title = "SCORING",
        text = "Keep capturing until the Wolf's hand is empty, you fold, or you have no capture left.\n\n" ..
            "If the Wolf runs out of cards you win the hand, and score the cards left in your hand " ..
            "(with the card drawn after your final capture).\n\n" ..
            "Otherwise the Wolf scores the cards left in its hand, so folding early can keep it low: " ..
            "the wolf takes small bites.\n\n" ..
            "The first to reach 100 points wins the match.",
        cards = {
            { suit = CLUB, rank = ACE, x = -58, y = -60, s = SMALL },
            { suit = HEART, rank = 2, x = 0, y = -60, s = SMALL },
            { suit = GOLD, rank = 4, x = 58, y = -60, s = SMALL },
        },
        extras = function(self, ax, ay)
            local C, fonts = UI.colors, self.assets.fonts
            label(self, "1 + 2 + 4 = 7 POINTS", ax, ay - 12, C.gold)
            UI.box(ax - 110, ay + 6, 220, 70, C.panelDark, { radius = 6 })
            UI.text("LEDGER", ax - 102, ay + 11, fonts.tiny, C.textDim, { shadow = false })
            local rows = { { "1", "WOLF", "FOLDED", "+14", C.red }, { "2", "YOU", "ALL TAKEN", "+7", C.gold },
                { "3", "WOLF", "NO MOVES", "+23", C.red } }
            for i, row in ipairs(rows) do
                local y = ay + 9 + i * 16
                UI.text(row[1], ax - 102, y, fonts.small, C.textDim)
                UI.text(row[2], ax - 86, y, fonts.small, row[5])
                UI.text(row[3], ax - 46, y + 2, fonts.tiny, C.textDim, { shadow = false })
                UI.text(row[4], ax + 102 - fonts.small:getWidth(row[4]), y, fonts.small, row[5])
            end
            label(self, "first to 100 wins", ax, ay + 94, C.text)
        end,
    },
    {
        title = "CONTROLS",
        text = "Click cards of both hands to select a capture. Its name and what it does show between the " ..
            "piles; cards that can't join your selection are dimmed.\n\n" ..
            "CAPTURE (Enter) plays it. Right-click or Backspace clears the selection.\n\n" ..
            "FOLD ends the hand: click it twice. NEXT HAND (Enter) deals the next one.\n\n" ..
            "Hover the deck, the piles and the sidebar for explanations. ESC opens the menu.",
        cards = {
            { suit = DIAMOND, rank = 7, x = 0, y = -68, s = SMALL },
            { suit = GOLD, rank = 9, x = 0, y = 62, s = SMALL },
        },
        extras = function(self, ax, ay)
            local C, fonts = UI.colors, self.assets.fonts
            UI.box(ax - 110, ay - 30, 220, 40, C.panelDark, { radius = 6 })
            UI.box(ax - 102, ay - 24, 58, 18, C.red, { radius = 4, depth = 2 })
            label(self, "OVER", ax - 73, ay - 15, C.text, fonts.medium)
            label(self, "9 takes 7", ax + 30, ay - 15, C.text, fonts.medium)
            label(self, "the Wolf takes 2 cards", ax, ay + 2, C.orange, fonts.tiny)
            UI.box(ax - 108, ay + 98, 96, 18, C.blue, { radius = 4, depth = 2 })
            label(self, "CAPTURE", ax - 60, ay + 107, C.text)
            UI.box(ax + 12, ay + 98, 96, 18, C.red, { radius = 4, depth = 2 })
            label(self, "FOLD", ax + 60, ay + 107, C.text)
        end,
    },
}
