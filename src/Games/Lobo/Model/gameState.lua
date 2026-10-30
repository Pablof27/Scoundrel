--[[
    Lobo GameState
    A match of Lobo (James Ernest): hands against the Wolf until you or the Wolf reach the target score.
    Pure model with no references to Views or UI. Every action leaves its result in `lastOutcome`,
    which the view animates.

    Each hand deals four cards to the Wolf and four to you. The top card of the deck, the cub, is
    always face up. Capture the Wolf's cards (see Plays) until its hand is empty, or fold. The hand
    also ends when you have no capture left.
      You empty the Wolf's hand:  you score the cards left in your hand.
      Otherwise:                  the Wolf scores the cards left in its hand.
    The deck is only shuffled every third hand, or when it can't deal a hand. When it runs out during
    a hand, the discard pile is shuffled into a new deck.
]]

local Card   = require("src.Model.card")
local Deck   = require("src.Model.deck")
local Config = require("src.Games.Lobo.config")
local Plays  = require("src.Games.Lobo.Model.plays")

local GameState = {}
GameState.__index = GameState

local HAND_SIZE = Config.HAND_SIZE

-- Statistic counted for each kind of capture.
GameState.KIND_STATS = { perfect = "perfects", sum = "sums", split = "splits", over = "overs" }

-- The 50-card deck: aces (worth 1) to 10 in five suits.
local function newCards()
    local cards = {}
    for suit = 0, Config.SUITS - 1 do
        table.insert(cards, Card:new(suit, Card.ACE, 1))
        for rank = 2, 10 do
            table.insert(cards, Card:new(suit, rank))
        end
    end
    return cards
end

local function indexOf(cards, card)
    for i, c in ipairs(cards) do
        if c.position == card.position then
            return i
        end
    end
    return nil
end

-- target: points that win the match (defaults to Config.DEFAULT_TARGET).
function GameState:new(target)
    local o = setmetatable({}, self)
    o.target      = target or Config.DEFAULT_TARGET
    o.deck        = Deck:new(newCards())
    o.discardPile = {}
    o.hand        = {}  -- your cards
    o.wolf        = {}  -- the Wolf's cards
    o.scores      = { player = 0, wolf = 0 }
    o.ledger      = {}  -- finished hands: { hand, winner ("player"/"wolf"), points, reason }
    o.handNumber  = 0
    o.handsSinceShuffle = Config.SHUFFLE_EVERY  -- the first hand shuffles
    o.handOver    = false
    o.handResult  = nil
    o.canUndo     = false  -- undoing would reveal the cards drawn
    o.errorMsg    = nil
    o.stats = {
        handsPlayed = 0,
        handsWon    = 0,
        bestHand    = 0,  -- most points scored in one hand
        perfects    = 0,
        sums        = 0,
        splits      = 0,
        overs       = 0,
        folds       = 0,
        stuck       = 0,  -- hands lost with no capture left
        captured    = 0,  -- Wolf cards captured
        wolfDraws   = 0,  -- cards the Wolf took from the deck
        shuffles    = 0,
    }
    o.lastOutcome = o:dealHand()
    return o
end

------------------------------------------------------------------------
-- Queries
------------------------------------------------------------------------

-- The face-up top card of the deck, nil if the deck is empty.
function GameState:cub()
    return self.deck:top()
end

function GameState:handTotal()
    return Plays.total(self.hand)
end

function GameState:wolfTotal()
    return Plays.total(self.wolf)
end

function GameState:plays()
    return Plays.all(self.hand, self.wolf)
end

-- Hands left before the deck is shuffled again (0: the next hand starts with a shuffle).
function GameState:handsBeforeShuffle()
    return math.max(0, Config.SHUFFLE_EVERY - self.handsSinceShuffle)
end

-- How many cards of each value (1-10) the deck hides below the cub.
function GameState:hiddenCounts()
    local counts = {}
    for value = 1, 10 do
        counts[value] = 0
    end
    for i = 2, #self.deck.cards do
        local value = self.deck.cards[i].value
        counts[value] = counts[value] + 1
    end
    return counts
end

function GameState:isOver()
    return self.scores.player >= self.target or self.scores.wolf >= self.target
end

function GameState:isVictory()
    return self.scores.player >= self.target
end

------------------------------------------------------------------------
-- Actions
------------------------------------------------------------------------

--[[
    Captures `theirs` (cards of the Wolf's hand) with `mine` (cards of your hand).
    lastOutcome: { kind, play, mine, theirs, drawn, drawnBy ("player"/"wolf"), reshuffled, handResult }
]]
function GameState:capture(mine, theirs)
    if self.handOver then
        self.errorMsg = "The hand is over"
        return false
    end
    local myCards, theirCards = self:pick(self.hand, mine), self:pick(self.wolf, theirs)
    if not myCards or not theirCards then
        self.errorMsg = "Those cards aren't on the table"
        return false
    end
    local play, reason = Plays.classify(myCards, theirCards)
    if not play then
        self.errorMsg = "Not a capture (" .. reason .. ")"
        return false
    end

    for _, card in ipairs(myCards) do
        table.remove(self.hand, indexOf(self.hand, card))
        table.insert(self.discardPile, card)
    end
    for _, card in ipairs(theirCards) do
        table.remove(self.wolf, indexOf(self.wolf, card))
        table.insert(self.discardPile, card)
    end

    local outcome = { kind = play.kind, play = play, mine = myCards, theirs = theirCards, drawn = {} }
    if play.playerDraws > 0 then
        outcome.drawnBy = "player"
        self:draw(self.hand, play.playerDraws, outcome)
    elseif play.wolfDraws > 0 then
        outcome.drawnBy = "wolf"
        self:draw(self.wolf, play.wolfDraws, outcome)
        self.stats.wolfDraws = self.stats.wolfDraws + #outcome.drawn
    end

    local stats = self.stats
    stats[GameState.KIND_STATS[play.kind]] = stats[GameState.KIND_STATS[play.kind]] + 1
    stats.captured = stats.captured + #theirCards

    if #self.wolf == 0 then
        self:finishHand("player", "captured", outcome)
    elseif not Plays.any(self.hand, self.wolf) then
        self:finishHand("wolf", "stuck", outcome)
    end
    self.lastOutcome = outcome
    return true
end

-- Stop fighting: the Wolf scores the cards left in its hand.
function GameState:fold()
    if self.handOver then
        self.errorMsg = "The hand is over"
        return false
    end
    local outcome = { kind = "fold" }
    self:finishHand("wolf", "fold", outcome)
    self.lastOutcome = outcome
    return true
end

function GameState:nextHand()
    if not self.handOver or self:isOver() then
        self.errorMsg = "The hand isn't over"
        return false
    end
    self.lastOutcome = self:dealHand()
    return true
end

------------------------------------------------------------------------
-- Internals
------------------------------------------------------------------------

-- The cards of `pile` matching `cards` (by position), or nil if any is missing or repeated.
function GameState:pick(pile, cards)
    local picked, seen = {}, {}
    for _, card in ipairs(cards) do
        local index = indexOf(pile, card)
        if not index or seen[card.position] then
            return nil
        end
        seen[card.position] = true
        table.insert(picked, pile[index])
    end
    return picked
end

--[[
    Clears the table and deals a new hand.
    Returns the outcome: { kind = "deal", returned (cards cleared from the table), shuffled, reshuffled,
    handResult (the hand can be over at once if no capture is possible) }
]]
function GameState:dealHand()
    local outcome = { kind = "deal", returned = {} }
    for _, pile in ipairs({ self.hand, self.wolf }) do
        for _, card in ipairs(pile) do
            table.insert(self.discardPile, card)
            table.insert(outcome.returned, card)
        end
    end
    self.hand, self.wolf = {}, {}

    -- Both hands and the cub must come from the deck.
    if self.handsSinceShuffle >= Config.SHUFFLE_EVERY or self.deck:remainingCards() < 2 * HAND_SIZE + 1 then
        self:shuffleAll()
        outcome.shuffled = true
    end
    for _ = 1, HAND_SIZE do
        table.insert(self.wolf, self:takeTop(outcome))
        table.insert(self.hand, self:takeTop(outcome))
    end

    self.handNumber = self.handNumber + 1
    self.handsSinceShuffle = self.handsSinceShuffle + 1
    self.handOver = false
    self.handResult = nil
    if not Plays.any(self.hand, self.wolf) then
        self:finishHand("wolf", "stuck", outcome)
    end
    return outcome
end

-- Every card off the table goes back into the deck, which is shuffled.
function GameState:shuffleAll()
    for _, card in ipairs(self.discardPile) do
        table.insert(self.deck.cards, card)
    end
    self.discardPile = {}
    self.deck:shuffle()
    self.handsSinceShuffle = 0
    self.stats.shuffles = self.stats.shuffles + 1
end

-- Takes the top card of the deck. When the deck runs out, the discard pile is shuffled into a new deck,
-- so there is always a face-up cub while cards are left off the table.
function GameState:takeTop(outcome)
    local card = table.remove(self.deck.cards, 1)
    if self.deck:isEmpty() and #self.discardPile > 0 then
        self.deck.cards = self.discardPile
        self.discardPile = {}
        self.deck:shuffle()
        outcome.reshuffled = true
    end
    return card
end

function GameState:draw(pile, count, outcome)
    for _ = 1, count do
        local card = self:takeTop(outcome)
        if not card then
            break
        end
        table.insert(pile, card)
        table.insert(outcome.drawn, card)
    end
end

-- winner: "player" or "wolf"; reason: "captured", "fold" or "stuck".
function GameState:finishHand(winner, reason, outcome)
    local points = winner == "player" and self:handTotal() or self:wolfTotal()
    local stats = self.stats
    self.scores[winner] = self.scores[winner] + points
    self.handOver = true
    self.handResult = { hand = self.handNumber, winner = winner, points = points, reason = reason }
    table.insert(self.ledger, self.handResult)
    stats.handsPlayed = stats.handsPlayed + 1
    if winner == "player" then
        stats.handsWon = stats.handsWon + 1
        stats.bestHand = math.max(stats.bestHand, points)
    elseif reason == "fold" then
        stats.folds = stats.folds + 1
    else
        stats.stuck = stats.stuck + 1
    end
    outcome.handResult = self.handResult
end

return GameState
