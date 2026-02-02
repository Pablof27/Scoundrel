local Player = require("src.Model.player")
local deck = require("src.Model.deck")
local Room = require("src.Model.room")

local EndGameView = require("src.View.states.endGameView")
local GameView = require("src.View.states.gameView")

local GameState = {}

CARDS_PER_ROOM = 4

function GameState:start()
    self.discardPile = {}
    self.drawPile = deck:new()
    self.room = Room:new(self.drawPile:drawCards(CARDS_PER_ROOM))
    self.player = Player:new()
    self.skippedLast = false
    self.prevState = nil
    self.errorMsg = nil
    self.canUndo = false
    return self
end

function GameState:skipRoomIfPossible()
    if not self:canSkipRoom() then
        self.errorMsg = "Cannot skip two rooms in a row"
        return false
    end
    self.skippedLast = true
    self.canUndo = false
    self.drawPile:addToBottom(self.room:shuffledRoom())
    self.room:new(self.drawPile:drawCards(CARDS_PER_ROOM))
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

function GameState:goToPreviousStateIfPossible()
    if self.prevState == nil then
        self.errorMsg = "No previous state to go back to"
        return false
    end
    if not self.canUndo then
        self.errorMsg = "Cannot undo last action"
        return false
    end
    self = self.prevState
    return true
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

    if not playerAction.shouldChangePrev then
        self.prevState = DeepCopy(self)
    end

    if not playerAction:execute(self) then
        print("Action could not be executed: " .. tostring(self.errorMsg))
    end

end

function GameState:addToDiscard(cards)
    for _, card in ipairs(cards) do
        table.insert(self.discardPile, card)
    end
end

function GameState:checkEndGame()
    if self.player.lifes <= 0 then
        StateStack:pop()
        StateStack:push(EndGameView:new(
            false,
            function ()
                StateStack:pop()
                Game:start(GameView)
                GameView:init(Game.gameState)
                StateStack:push(GameView)
            end
        ))
        return
    end
    if self.drawPile:isEmpty() and not self.room:isRoomComplete() then
        StateStack:push(EndGameView:new(
            true,
            function ()
                Game:start(GameView)
                GameView:init(Game.gameState)
                StateStack:pop(GameView)
            end
        ))
        return
    end
end

return GameState