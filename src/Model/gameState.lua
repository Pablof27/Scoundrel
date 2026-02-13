--[[
    GameState
    Pure game-state model. Contains no references to Views or UI.
    End-game detection is exposed as query methods; the Controller decides what to do.
]]

local Player    = require("src.Model.player")
local Deck      = require("src.Model.deck")
local Room      = require("src.Model.room")

local GameState = {}
GameState.__index = GameState

local CARDS_PER_ROOM = Constants.CARDS_PER_ROOM

function GameState:new()
    local o = setmetatable({}, self)
    o.discardPile = {}
    o.drawPile    = Deck:new()
    o.room        = Room:new(o.drawPile:drawCards(CARDS_PER_ROOM))
    o.player      = Player:new()
    o.skippedLast = false
    o.errorMsg    = nil
    o.canUndo     = false
    return o
end

function GameState:skipRoomIfPossible()
    if not self:canSkipRoom() then
        self.errorMsg = "Cannot skip two rooms in a row"
        return false
    end
    self.skippedLast = true
    self.canUndo = false
    self.drawPile:addToBottom(self.room:shuffledRoom())
    self.room:replaceCards(self.drawPile:drawCards(CARDS_PER_ROOM))
    return true
end

function GameState:canSkipRoom()
    return not self.skippedLast and self.room:isRoomComplete()
end

function GameState:nextRoomIfPossible()
    if #self.room.cards ~= 1 then
        self.errorMsg = "Cannot proceed to next room: more than one card remains"
        return false
    end
    self.skippedLast = false
    self.canUndo = false
    self.room:replenishRoom(self.drawPile:drawCards(CARDS_PER_ROOM - 1))
    return true
end

function GameState:canGoNextRoom()
    return #self.room.cards == 1
end

function GameState:playCardIfPossible(card, useArmor)
    if not self.room:removeCard(card) then
        self.errorMsg = "Selected card is not in the room"
        return false
    end

    self.canUndo = true

    if card:isHeart() then
        self.player:heal(card.value)
        table.insert(self.discardPile, card)
        return true
    end
    if card:isDiamond() then
        local discards = self.player:addWeapon(card)
        self:addToDiscard(discards)
        return true
    end

    useArmor = useArmor ~= false
    local discards = self.player:takeDamage(card, useArmor)
    self:addToDiscard(discards)
    return true
end

function GameState:nextState(playerAction)
    self.errorMsg = nil
    if not playerAction:execute(self) then
        print("Action could not be executed: " .. tostring(self.errorMsg))
    end
end

function GameState:addToDiscard(cards)
    for _, card in ipairs(cards) do
        table.insert(self.discardPile, card)
    end
end

-- Query methods — the Controller calls these to decide end-game transitions
function GameState:isPlayerDead()
    return self.player.lifes <= 0
end

function GameState:isVictory()
    return self.drawPile:isEmpty() and not self.room:isRoomComplete()
end

return GameState