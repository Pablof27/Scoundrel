--[[
    Lobo plays
    Classifies captures and lists the ones available. A capture plays cards of your hand ("mine")
    against cards of the Wolf's hand ("theirs"):
      perfect  one card takes a Wolf card of the same value                 then you draw the cub
      sum      several cards add up exactly to one Wolf card                then you draw the cub
      split    one card takes several Wolf cards adding up exactly to it    then the Wolf draws the cub
      over     one card takes one smaller Wolf card                         then the Wolf draws one card
                                                                            per point of difference
]]

local unpack = unpack or table.unpack

local Plays = {}

-- Name and UI.colors entry of each kind of capture.
Plays.KINDS = {
    perfect = { name = "PERFECT", color = "gold" },
    sum     = { name = "SUM",     color = "blue" },
    split   = { name = "SPLIT",   color = "purple" },
    over    = { name = "OVER",    color = "red" },
}

function Plays.total(cards)
    local sum = 0
    for _, card in ipairs(cards) do
        sum = sum + card.value
    end
    return sum
end

--[[
    Classifies playing `mine` against `theirs` (lists of cards). Returns the play:
      { kind, mine, theirs, myTotal, theirTotal, playerDraws, wolfDraws }
    or nil and why it isn't a capture:
      "empty"      no card on one side          "manyToMany"  several cards on both sides
      "tooSmall"   one card against a bigger one "noMatch"     the totals differ
]]
function Plays.classify(mine, theirs)
    if #mine == 0 or #theirs == 0 then
        return nil, "empty"
    end
    if #mine > 1 and #theirs > 1 then
        return nil, "manyToMany"
    end
    local play = {
        mine = mine, theirs = theirs,
        myTotal = Plays.total(mine), theirTotal = Plays.total(theirs),
        playerDraws = 0, wolfDraws = 0,
    }
    if #mine == 1 and #theirs == 1 then
        if play.myTotal == play.theirTotal then
            play.kind, play.playerDraws = "perfect", 1
        elseif play.myTotal > play.theirTotal then
            play.kind, play.wolfDraws = "over", play.myTotal - play.theirTotal
        else
            return nil, "tooSmall"
        end
    elseif play.myTotal ~= play.theirTotal then
        return nil, "noMatch"
    elseif #mine > 1 then
        play.kind, play.playerDraws = "sum", 1
    else
        play.kind, play.wolfDraws = "split", 1
    end
    return play
end

-- Every subset of `cards` with at least `minSize` cards whose values add up to `target`.
local function subsetsSumming(cards, target, minSize)
    local found, chosen = {}, {}
    local function search(start, remaining)
        if remaining == 0 then
            if #chosen >= minSize then
                table.insert(found, { unpack(chosen) })
            end
            return
        end
        for i = start, #cards do
            if cards[i].value <= remaining then
                table.insert(chosen, cards[i])
                search(i + 1, remaining - cards[i].value)
                table.remove(chosen)
            end
        end
    end
    search(1, target)
    return found
end

-- Every capture available with `hand` against `wolf`.
function Plays.all(hand, wolf)
    local plays = {}
    for _, mine in ipairs(hand) do
        for _, theirs in ipairs(wolf) do
            local play = Plays.classify({ mine }, { theirs })
            if play then
                table.insert(plays, play)
            end
        end
        for _, theirs in ipairs(subsetsSumming(wolf, mine.value, 2)) do
            table.insert(plays, Plays.classify({ mine }, theirs))
        end
    end
    for _, theirs in ipairs(wolf) do
        for _, mine in ipairs(subsetsSumming(hand, theirs.value, 2)) do
            table.insert(plays, Plays.classify(mine, { theirs }))
        end
    end
    return plays
end

-- Whether any capture is available (cheaper than Plays.all).
function Plays.any(hand, wolf)
    if #hand == 0 or #wolf == 0 then
        return false
    end
    -- A card at least as big as a Wolf card has a Perfect or an Over (and a Split needs one too).
    local highest, lowest = 0, math.huge
    for _, card in ipairs(hand) do
        highest = math.max(highest, card.value)
    end
    for _, card in ipairs(wolf) do
        lowest = math.min(lowest, card.value)
    end
    if highest >= lowest then
        return true
    end
    for _, theirs in ipairs(wolf) do
        if #subsetsSumming(hand, theirs.value, 2) > 0 then
            return true
        end
    end
    return false
end

return Plays
