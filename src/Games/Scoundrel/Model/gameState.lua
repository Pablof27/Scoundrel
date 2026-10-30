--[[
    Scoundrel GameState
    Pure game-state model. Contains no references to Views or UI.
    End-game detection is exposed as query methods; the Controller decides what to do.
]]

local Card      = require("src.Model.card")
local Deck      = require("src.Model.deck")
local Config    = require("src.Games.Scoundrel.config")
local Player    = require("src.Games.Scoundrel.Model.player")
local Room      = require("src.Games.Scoundrel.Model.room")

local GameState = {}
GameState.__index = GameState

local CARDS_PER_ROOM = Config.CARDS_PER_ROOM
local MAX_LIFES      = Config.MAX_LIFES

-- Clubs and spades are monsters; their face cards and aces (J, Q, K, A) are bosses.
function GameState.isMonster(card)
    return card:isClub() or card:isSpade()
end

function GameState.isBoss(card)
    return GameState.isMonster(card) and card.value >= 11
end

-- The 44-card dungeon: every club and spade, plus hearts and diamonds from 2 to 10.
local function newDungeon()
    local cards = {}
    for _, suit in ipairs({ Card.SUITS.HEART, Card.SUITS.CLUB, Card.SUITS.DIAMOND, Card.SUITS.SPADE }) do
        local highest = (suit == Card.SUITS.HEART or suit == Card.SUITS.DIAMOND) and 10 or Card.ACE
        for rank = 2, highest do
            table.insert(cards, Card:new(suit, rank))
        end
    end
    local deck = Deck:new(cards)
    deck:shuffle()
    return deck
end

-- difficulty: key of one of Config.DIFFICULTIES (defaults to Config.DEFAULT_DIFFICULTY).
function GameState:new(difficulty)
    local o = setmetatable({}, self)
    o.difficulty  = Config.difficulty(difficulty)
    o.discardPile = {}
    o.drawPile    = newDungeon()
    o.room        = Room:new(o.drawPile:drawCards(CARDS_PER_ROOM))
    o.player      = Player:new(o.difficulty.weaponSlaysEqual)
    o.skippedLast = false
    o.errorMsg    = nil
    o.canUndo     = false
    o.roomNumber  = 1
    o.potionUsedThisRoom = false
    o.lastOutcome = nil
    o.stats = {
        cardsPlayed     = 0,
        monstersSlain   = 0,
        bossesSlain     = 0,
        damageTaken     = 0,
        damageBlocked   = 0,
        potionsDrunk    = 0,
        healed          = 0,
        potionsWasted   = 0,
        weaponsEquipped = 0,
        roomsFled       = 0,
    }
    return o
end

function GameState:skipRoomIfPossible()
    if not self:canSkipRoom() then
        self.errorMsg = "Cannot skip room: " .. tostring(self:skipBlockedReason())
        return false
    end
    self.skippedLast = true
    self.canUndo = false
    self.potionUsedThisRoom = false
    self.roomNumber = self.roomNumber + 1
    self.stats.roomsFled = self.stats.roomsFled + 1
    self.drawPile:addToBottom(self.room:shuffledRoom())
    self.room:replaceCards(self.drawPile:drawCards(CARDS_PER_ROOM))
    return true
end

function GameState:canSkipRoom()
    return self:skipBlockedReason() == nil
end

-- Why the room cannot be fled right now: "deckEmpty", "roomStarted", "fledLast" or nil.
function GameState:skipBlockedReason()
    if self.drawPile:isEmpty() then
        return "deckEmpty"
    end
    if not self.room:isRoomComplete() then
        return "roomStarted"
    end
    if self.skippedLast then
        return "fledLast"
    end
    return nil
end

function GameState:nextRoomIfPossible()
    if not self:canGoNextRoom() then
        self.errorMsg = "Cannot proceed to next room: one card must remain and the dungeon must be able to deal a room"
        return false
    end
    self.skippedLast = false
    self.canUndo = false
    self.potionUsedThisRoom = false
    self.roomNumber = self.roomNumber + 1
    self.room:replenishRoom(self.drawPile:drawCards(CARDS_PER_ROOM - 1))
    return true
end

-- Whether the dungeon can deal the next room. When the whole dungeon doesn't have to be cleared,
-- only full rooms are dealt: the run ends once there are too few cards left to fill one.
function GameState:canDealRoom()
    if self.difficulty.clearDungeon then
        return not self.drawPile:isEmpty()
    end
    return self.drawPile:remainingCards() >= CARDS_PER_ROOM - 1
end

function GameState:canGoNextRoom()
    return #self.room.cards == 1 and self:canDealRoom()
end

-- The last card of a room always stays for the next one, except in the final room of a run
-- that must clear the whole dungeon.
function GameState:canPlayCard(card)
    if not self.room:contains(card) then
        return false
    end
    return #self.room.cards > 1 or (self.difficulty.clearDungeon and self:isFinalRoom())
end

-- No room can be dealt after this one.
function GameState:isFinalRoom()
    return not self:canDealRoom()
end

--[[
    Describes what playing a card would do, without changing anything.
    Returns a table with `kind` ("potion", "weapon" or "monster") and:
      potion:  heal, wasted, lifeAfter
      weapon:  replaced (card or nil), discardCount, lifeAfter
      monster: damage, usedWeapon, weaponUsable, lethal, lifeAfter
]]
function GameState:previewCard(card, useArmor)
    local player = self.player
    local preview = { card = card }
    if card:isHeart() then
        preview.kind = "potion"
        preview.wasted = self.potionUsedThisRoom
        preview.heal = preview.wasted and 0 or math.min(card.value, MAX_LIFES - player.lifes)
        preview.lifeAfter = player.lifes + preview.heal
    elseif card:isDiamond() then
        preview.kind = "weapon"
        preview.replaced = player:hasArmor() and player.armor.card or nil
        preview.discardCount = player:hasArmor() and (1 + #player.armor.defendedCards) or 0
        preview.lifeAfter = player.lifes
    else
        preview.kind = "monster"
        preview.weaponUsable = player:canUseArmor(card)
        preview.damage, preview.usedWeapon = player:damageFrom(card, useArmor ~= false)
        preview.lifeAfter = player.lifes - preview.damage
        preview.lethal = preview.lifeAfter <= 0
    end
    return preview
end

function GameState:playCardIfPossible(card, useArmor)
    if not self:canPlayCard(card) then
        self.errorMsg = "Selected card cannot be played"
        return false
    end

    local outcome = self:previewCard(card, useArmor)
    local stats = self.stats
    self.room:removeCard(card)
    self.canUndo = true
    stats.cardsPlayed = stats.cardsPlayed + 1

    if outcome.kind == "potion" then
        -- Only one potion per room heals; any further potion is simply discarded.
        if outcome.wasted then
            stats.potionsWasted = stats.potionsWasted + 1
        else
            self.player:heal(card.value)
            self.potionUsedThisRoom = true
            stats.potionsDrunk = stats.potionsDrunk + 1
            stats.healed = stats.healed + outcome.heal
        end
        table.insert(self.discardPile, card)
    elseif outcome.kind == "weapon" then
        outcome.discarded = self.player:addWeapon(card)
        self:addToDiscard(outcome.discarded)
        stats.weaponsEquipped = stats.weaponsEquipped + 1
    else
        local discards = self.player:takeDamage(card, outcome.usedWeapon)
        self:addToDiscard(discards)
        stats.damageTaken = stats.damageTaken + outcome.damage
        stats.damageBlocked = stats.damageBlocked + (card.value - outcome.damage)
        if not self:isPlayerDead() then
            stats.monstersSlain = stats.monstersSlain + 1
            if GameState.isBoss(card) then
                stats.bossesSlain = stats.bossesSlain + 1
            end
        end
    end

    self.lastOutcome = outcome
    return true
end

function GameState:addToDiscard(cards)
    for _, card in ipairs(cards) do
        table.insert(self.discardPile, card)
    end
end

function GameState:isPlayerDead()
    return self.player.lifes <= 0
end

--[[
    Clearing the whole dungeon: escaped once every card has been drawn and resolved.
    Otherwise: escaped once the final room is down to the card that would stay for the next room.
]]
function GameState:isVictory()
    if self:isPlayerDead() or not self:isFinalRoom() then
        return false
    end
    if self.difficulty.clearDungeon then
        return #self.room.cards == 0
    end
    return #self.room.cards <= 1
end

function GameState:isOver()
    return self:isPlayerDead() or self:isVictory()
end

--[[
    Official Scoundrel scoring:
    - Dead: remaining health minus the value of every monster still in the dungeon.
    - Escaped: remaining health, plus the potion's value if the last card was a potion drunk at full health.
]]
function GameState:score()
    if self:isPlayerDead() then
        local remaining = 0
        for _, pile in ipairs({ self.room.cards, self.drawPile.cards }) do
            for _, card in ipairs(pile) do
                if GameState.isMonster(card) then
                    remaining = remaining + card.value
                end
            end
        end
        return self.player.lifes - remaining
    end

    local score = self.player.lifes
    local last = self.lastOutcome
    if last and last.kind == "potion" and not last.wasted and self.player.lifes == MAX_LIFES then
        score = score + last.card.value
    end
    return score
end

return GameState