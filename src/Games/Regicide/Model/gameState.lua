--[[
    Regicide GameState
    Solo mode of Regicide (Paul Abrahams, Luke Badger and Andy Richdale — Badgers From Mars):
    overthrow 12 corrupt Royals (4 Jacks, 4 Queens, 4 Kings) with a 40-card Tavern deck and up to
    two Solo Jesters. Pure model with no references to Views or UI; every action leaves a detailed
    `lastOutcome` table for the board to animate.
]]

local Card   = require("src.Model.card")
local Deck   = require("src.Model.deck")
local Config = require("src.Games.Regicide.config")

local GameState = {}
GameState.__index = GameState

local HAND_SIZE = Config.HAND_SIZE

GameState.PLAY_KINDS = {
    single    = { name = "ATTACK",    color = "blue" },
    royal     = { name = "ROYAL",     color = "gold" },
    companion = { name = "COMPANION", color = "green" },
    combo     = { name = "COMBO",     color = "purple" },
}

-- Castle deck: 4 Jacks on top, then 4 Queens, then 4 Kings, each tier shuffled on its own.
local function newCastleDeck()
    local deck = Deck:new()
    for _, rank in ipairs(Config.ROYAL_RANKS) do
        local tier = {}
        local attack = Config.ROYALS[rank].attack
        for suit = 0, 3 do
            table.insert(tier, Card:new(suit, rank, attack))
        end
        table.shuffle(tier)
        deck:addToBottom(tier)
    end
    return deck
end

-- Tavern deck: 2-10 and Animal Companions (Aces, worth 1) in all four suits (40 cards).
local function newTavernDeck()
    local cards = {}
    for suit = 0, 3 do
        table.insert(cards, Card:new(suit, Card.ACE, 1))
        for rank = 2, 10 do
            table.insert(cards, Card:new(suit, rank))
        end
    end
    return Deck:new(cards):shuffle()
end

local function indexOf(cards, card)
    for i, c in ipairs(cards) do
        if c.position == card.position then
            return i
        end
    end
    return nil
end

local function totalValue(cards)
    local sum = 0
    for _, c in ipairs(cards) do
        sum = sum + c.value
    end
    return sum
end

--[[
    Classifies a set of cards for Step 1 (Attack):
      - single card (any card; converted Royals are highlighted as "royal")
      - Animal Companion (Ace, worth 1) paired with any one other card (even 10, J, Q, K or another Ace)
      - combo of 2, 3 or 4 cards of the same number (not Aces) whose combined value is at most 10
    Returns { kind, cards, attack, suits } or nil, reason.
]]
function GameState.classifyAttack(cards)
    local count = #cards
    if count == 0 then
        return nil, "Select a card to attack"
    end
    if count > 4 then
        return nil, "At most 4 cards can be played together"
    end

    local attack = totalValue(cards)
    local suits = {}
    for _, c in ipairs(cards) do
        suits[c.suit] = true
    end

    if count == 1 then
        local kind = cards[1].rank >= 11 and cards[1].rank <= 13 and "royal" or "single"
        return { kind = kind, cards = cards, attack = attack, suits = suits }
    end

    if count == 2 and (cards[1].rank == Card.ACE or cards[2].rank == Card.ACE) then
        return { kind = "companion", cards = cards, attack = attack, suits = suits }
    end

    for _, c in ipairs(cards) do
        if c.rank == Card.ACE then
            return nil, "An Animal Companion (A) can only pair with one other card"
        end
    end
    local rank = cards[1].rank
    for i = 2, count do
        if cards[i].rank ~= rank then
            return nil, "Only an Animal Companion (A) or equal ranks up to 10 can combine"
        end
    end
    if attack > 10 then
        return nil, "Combos of equal ranks can't exceed 10 (" .. attack .. ")"
    end
    return { kind = "combo", cards = cards, attack = attack, suits = suits }
end

GameState.total = totalValue

function GameState:new(jokers)
    if jokers == nil then
        jokers = Config.DEFAULT_JESTERS
    end
    local o = setmetatable({}, self)
    o.enemyDeck       = newCastleDeck()
    o.playerDeck      = newTavernDeck()
    o.discardPile     = {}
    o.playedCards     = {}  -- cards played against the current Royal
    o.hand            = o.playerDeck:drawCards(HAND_SIZE)
    o.currentEnemy    = o.enemyDeck:drawCards(1)[1]
    o.enemyMaxLife    = Config.ROYALS[o.currentEnemy.rank].health
    o.enemyLife       = o.enemyMaxLife
    o.damageShield    = 0
    o.maxJokers       = jokers
    o.availableJokers = jokers
    o.jokersUsed      = 0
    o.phase           = "attack"  -- "attack" or "defend"
    o.turnNumber      = 1
    o.gameOver        = false
    o.won             = false
    o.loseReason      = nil       -- "overwhelmed" or "noCards"
    o.canUndo         = false     -- undoing would reveal hidden Tavern / Castle cards
    o.errorMsg        = nil
    o.lastOutcome     = nil
    o.stats = {
        royalsDefeated = 0,
        exactKills     = 0,
        turnsPlayed    = 0,
        cardsPlayed    = 0,
        damageDealt    = 0,
        damageBlocked  = 0,
        cardsHealed    = 0,
        cardsDrawn     = 0,
        cardsDiscarded = 0,
        jokersUsed     = 0,
    }
    return o
end

------------------------------------------------------------------------
-- Queries
------------------------------------------------------------------------

function GameState:isOver()
    return self.gameOver
end

function GameState:isVictory()
    return self.won
end

-- Victory tier: 3 = Gold (0 Jesters used), 2 = Silver (1 used), 1 = Bronze (2 used), 0 = defeat.
function GameState:victoryTier()
    if not self.won then
        return 0
    end
    return Config.tierForJokersUsed(self.jokersUsed)
end

function GameState:incomingDamage()
    if not self.currentEnemy then
        return 0
    end
    return math.max(0, self.currentEnemy.value - self.damageShield)
end

function GameState:handTotal()
    return totalValue(self.hand)
end

function GameState:canPlayJoker()
    return not self.gameOver and self.availableJokers > 0 and #self.playerDeck.cards > 0
end

function GameState:jokerBlockedReason()
    if self.availableJokers <= 0 then
        return self.maxJokers == 0 and "No Jesters in a Gold Challenge run." or "No Jesters left."
    end
    if #self.playerDeck.cards == 0 then
        return "The Tavern deck is empty: flipping a Jester would draw no cards."
    end
    return nil
end

function GameState:selectionCanAttack(cards)
    return GameState.classifyAttack(cards) ~= nil
end

function GameState:selectionCanDefend(cards)
    return #cards > 0 and totalValue(cards) >= self:incomingDamage()
end

-- Remaining Royals in the Castle (including currentEnemy) per rank: { [11] = n, [12] = n, [13] = n }.
function GameState:remainingRoyalsByRank()
    local counts = { [11] = 0, [12] = 0, [13] = 0 }
    if self.currentEnemy then
        counts[self.currentEnemy.rank] = counts[self.currentEnemy.rank] + 1
    end
    for _, card in ipairs(self.enemyDeck.cards) do
        counts[card.rank] = counts[card.rank] + 1
    end
    return counts
end

--[[
    Exact preview of attacking with `cards` (without mutating state), or nil, reason if invalid.
    Accounts for enemy suit immunity and Hearts healing into the Tavern before Diamonds draw.
]]
function GameState:previewAttack(cards)
    if not self.currentEnemy then
        return nil, "No enemy"
    end
    local play, reason = GameState.classifyAttack(cards)
    if not play then
        return nil, reason
    end

    local enemySuit = self.currentEnemy.suit
    local activeSuits = {}
    local immuneTriggered = false
    for suit in pairs(play.suits) do
        if suit == enemySuit then
            immuneTriggered = true
        else
            activeSuits[suit] = true
        end
    end

    local attack = play.attack
    local doubleDamage = activeSuits[Card.SUITS.CLUB] == true
    local damage = doubleDamage and (attack * 2) or attack
    local shieldGain = activeSuits[Card.SUITS.SPADE] and attack or 0
    local healCount = activeSuits[Card.SUITS.HEART] and math.min(attack, #self.discardPile) or 0
    local handAfterPlay = #self.hand - #cards
    local handRoom = math.max(0, HAND_SIZE - handAfterPlay)
    local drawCount = activeSuits[Card.SUITS.DIAMOND]
        and math.min(attack, handRoom, #self.playerDeck.cards + healCount) or 0

    local lifeAfter = self.enemyLife - damage
    local killsEnemy = lifeAfter <= 0
    local exactKill = lifeAfter == 0
    local shieldAfter = self.damageShield + shieldGain
    local incomingAfter = killsEnemy and 0 or math.max(0, self.currentEnemy.value - shieldAfter)

    return {
        kind            = play.kind,
        cards           = cards,
        attack          = attack,
        damage          = damage,
        doubleDamage    = doubleDamage,
        shieldGain      = shieldGain,
        healCount       = healCount,
        drawCount       = drawCount,
        activeSuits     = activeSuits,
        immuneSuit      = enemySuit,
        immuneTriggered = immuneTriggered,
        enemyLifeAfter  = lifeAfter,
        killsEnemy      = killsEnemy,
        exactKill       = exactKill,
        incomingAfter   = incomingAfter,
    }
end

------------------------------------------------------------------------
-- Actions
------------------------------------------------------------------------

function GameState:playCards(cards)
    if self.gameOver then
        self.errorMsg = "The game is over"
        return false
    end
    if self.phase ~= "attack" then
        self.errorMsg = "You must defend against the Royal's attack first"
        return false
    end
    local picked = self:pick(self.hand, cards)
    if not picked then
        self.errorMsg = "Those cards aren't in your hand"
        return false
    end
    local preview, reason = self:previewAttack(picked)
    if not preview then
        self.errorMsg = reason
        return false
    end

    for _, card in ipairs(picked) do
        table.remove(self.hand, indexOf(self.hand, card))
        table.insert(self.playedCards, card)
    end

    self.stats.turnsPlayed = self.stats.turnsPlayed + 1
    self.stats.cardsPlayed = self.stats.cardsPlayed + #picked

    local outcome = {
        kind            = preview.kind,
        cards           = picked,
        attack          = preview.attack,
        damage          = preview.damage,
        doubled         = preview.doubleDamage,
        shieldGain      = preview.shieldGain,
        activeSuits     = preview.activeSuits,
        immuneTriggered = preview.immuneTriggered,
        enemy           = self.currentEnemy,
        healed          = {},
        drawn           = {},
        clearedBattle   = {},
    }

    -- Step 2: Activate suit powers (Hearts always before Diamonds).
    if preview.activeSuits[Card.SUITS.HEART] and #self.discardPile > 0 then
        table.shuffle(self.discardPile)
        local count = math.min(preview.attack, #self.discardPile)
        for _ = 1, count do
            table.insert(outcome.healed, table.remove(self.discardPile, 1))
        end
        self.playerDeck:addToBottom(outcome.healed)
        self.stats.cardsHealed = self.stats.cardsHealed + #outcome.healed
    end

    if preview.activeSuits[Card.SUITS.DIAMOND] then
        local room = math.max(0, HAND_SIZE - #self.hand)
        local drawn = self.playerDeck:drawCards(math.min(preview.attack, room))
        for _, card in ipairs(drawn) do
            table.insert(self.hand, card)
            table.insert(outcome.drawn, card)
        end
        self.stats.cardsDrawn = self.stats.cardsDrawn + #drawn
    end

    if preview.activeSuits[Card.SUITS.SPADE] then
        self.damageShield = self.damageShield + preview.attack
    end

    -- Step 3: Deal damage and check if the Royal falls.
    self.enemyLife = self.enemyLife - preview.damage
    self.stats.damageDealt = self.stats.damageDealt + preview.damage

    if self.enemyLife <= 0 then
        outcome.enemyDefeated = true
        outcome.exactKill = (self.enemyLife == 0)
        self.stats.royalsDefeated = self.stats.royalsDefeated + 1

        for _, card in ipairs(self.playedCards) do
            table.insert(self.discardPile, card)
            table.insert(outcome.clearedBattle, card)
        end
        self.playedCards = {}

        if outcome.exactKill then
            self.stats.exactKills = self.stats.exactKills + 1
            self.playerDeck:addToTop(self.currentEnemy)
        else
            table.insert(self.discardPile, self.currentEnemy)
        end

        if self.enemyDeck:isEmpty() then
            self.currentEnemy = nil
            self.enemyLife = 0
            self.enemyMaxLife = 0
            self.damageShield = 0
            self.won = true
            self.gameOver = true
        else
            self.currentEnemy = self.enemyDeck:drawCards(1)[1]
            self.enemyMaxLife = Config.ROYALS[self.currentEnemy.rank].health
            self.enemyLife = self.enemyMaxLife
            self.damageShield = 0
            outcome.nextEnemy = self.currentEnemy
            self.phase = "attack"
            self.turnNumber = self.turnNumber + 1
            self:checkStep1Survival(outcome)
        end
    else
        -- Step 4: Royal counterattacks (skipped automatically if Spades reduced attack to 0).
        local rawAttack = self.currentEnemy.value
        local blocked = math.min(rawAttack, self.damageShield)
        self.stats.damageBlocked = self.stats.damageBlocked + blocked
        local incoming = rawAttack - blocked
        outcome.incoming = incoming
        outcome.blocked = blocked

        if incoming <= 0 then
            outcome.autoBlocked = true
            self.phase = "attack"
            self.turnNumber = self.turnNumber + 1
            self:checkStep1Survival(outcome)
        else
            self.phase = "defend"
            self:checkStep4Survival(outcome)
        end
    end

    self.lastOutcome = outcome
    return true
end

function GameState:defend(cards)
    if self.gameOver then
        self.errorMsg = "The game is over"
        return false
    end
    if self.phase ~= "defend" then
        self.errorMsg = "You are not defending right now"
        return false
    end
    local picked = self:pick(self.hand, cards)
    if not picked or #picked == 0 then
        self.errorMsg = "Select cards to absorb the attack"
        return false
    end
    local incoming = self:incomingDamage()
    local total = totalValue(picked)
    if total < incoming then
        self.errorMsg = "Selected cards (" .. total .. ") don't cover " .. incoming .. " damage"
        return false
    end

    for _, card in ipairs(picked) do
        table.remove(self.hand, indexOf(self.hand, card))
        table.insert(self.discardPile, card)
    end
    self.stats.cardsDiscarded = self.stats.cardsDiscarded + #picked

    local outcome = { cards = picked, total = total, incoming = incoming }
    self.phase = "attack"
    self.turnNumber = self.turnNumber + 1
    self:checkStep1Survival(outcome)

    self.lastOutcome = outcome
    return true
end

-- Solo Jester: allowed at the start of Step 1 (attack) or Step 4 (defend).
-- Discards your hand and refills up to 8 cards from the Tavern deck.
function GameState:playJoker()
    if self.gameOver then
        self.errorMsg = "The game is over"
        return false
    end
    if not self:canPlayJoker() then
        self.errorMsg = self:jokerBlockedReason() or "Cannot play Jester"
        return false
    end

    self.availableJokers = self.availableJokers - 1
    self.jokersUsed = self.jokersUsed + 1
    self.stats.jokersUsed = self.stats.jokersUsed + 1

    local discarded = {}
    for _, card in ipairs(self.hand) do
        table.insert(self.discardPile, card)
        table.insert(discarded, card)
    end
    self.hand = {}
    self.stats.cardsDiscarded = self.stats.cardsDiscarded + #discarded

    local drawn = self.playerDeck:drawCards(HAND_SIZE)
    for _, card in ipairs(drawn) do
        table.insert(self.hand, card)
    end
    self.stats.cardsDrawn = self.stats.cardsDrawn + #drawn

    local outcome = {
        discarded       = discarded,
        drawn           = drawn,
        remainingJokers = self.availableJokers,
        phase           = self.phase,
    }
    if self.phase == "defend" then
        self:checkStep4Survival(outcome)
    else
        self:checkStep1Survival(outcome)
    end

    self.lastOutcome = outcome
    return true
end

------------------------------------------------------------------------
-- Internals
------------------------------------------------------------------------

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

function GameState:checkStep1Survival(outcome)
    if #self.hand == 0 and not self:canPlayJoker() then
        self.gameOver = true
        self.won = false
        self.loseReason = "noCards"
        outcome.defeatedPlayer = "noCards"
    end
end

function GameState:checkStep4Survival(outcome)
    if self:handTotal() < self:incomingDamage() and not self:canPlayJoker() then
        self.gameOver = true
        self.won = false
        self.loseReason = "overwhelmed"
        outcome.defeatedPlayer = "overwhelmed"
    end
end

return GameState

