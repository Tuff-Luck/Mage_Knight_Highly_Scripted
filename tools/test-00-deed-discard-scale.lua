-- End-turn Deed discards must not inherit the Play Area's temporary size.
-- Run from repository root: lua5.2 tools/test-deed-discard-scale.lua
local function read(path)
    local file=assert(io.open(path,"r"))
    local contents=file:read("*a")
    file:close()
    return contents
end

local source=read("src/PlayingGame/PlayerBoard/CardFlow.lua")
local first=assert(source:find("function deedInventoryForgetCard(",1,true))
local last=assert(source:find("\nlocal MEDITATION_BUTTON_SUFFIXES=",first,true))
local env={
    turnOrder={{seatPos=1,deadDeckInventory={"first","second","third"}}},
    gStates={bannercard={},turnForfeited=false},
    gameCards={},
    trashCan="trash",
    isQuestCardObject=function() return false end,
    isSteadyTempoGUID=function() return false end
}
setmetatable(env,{__index=_G})
env.getObjectFromGUID=function() return nil end
local scaledRecords={first=true,second=true,third=true}
env.playAreaScaleForgetObject=function(obj) scaledRecords[obj.guid]=nil end
assert(load(source:sub(first,last-1),"cleanup discard","t",env))()

local function scaleObject(obj)
    obj.setScale=function(s) obj.scale={s[1],s[2],s[3]} end
    obj.getScale=function() return {obj.scale[1],obj.scale[2],obj.scale[3]} end
    return obj
end
local function deck(scale)
    local obj=scaleObject({type="Deck",scale={scale,1,scale}})
    obj.putObject=function(card)
        assert(card.scale[1]==1.5 and card.scale[3]==1.5,"Added card must be full size")
        obj.count=(obj.count or 1)+1
        return obj
    end
    return obj
end
local function card(guid,scale)
    local obj=scaleObject({guid=guid,type="Card",is_face_down=false,scale={scale,1,scale}})
    obj.getPosition=function() return {0,1,0} end
    obj.setPosition=function(p) obj.position=p end
    obj.setRotation=function(r) obj.rotation=r end
    obj.putObject=function(nextCard)
        local newDeck=deck(obj.scale[1])
        newDeck.putObject(nextCard)
        return newDeck
    end
    return obj
end

local firstCard=card("first",0.75)
local pile=env.cleanupPlayedCardAtEndTurn(firstCard,1,nil)
assert(pile==firstCard,"First loose discard should seed the pile")
assert(firstCard.scale[1]==1.5 and firstCard.scale[3]==1.5,"First discard restored to normal size")
assert(scaledRecords.first==nil,"First discard loses the play-area scale record")

local secondCard=card("second",0.9)
pile=env.cleanupPlayedCardAtEndTurn(secondCard,1,pile)
assert(pile.type=="Deck" and pile.scale[1]==1.5,"Discard deck must form at normal size")
assert(scaledRecords.second==nil,"Stacked discard loses the play-area scale record")

-- An already-corrupted discard deck must be repaired before a new card is merged.
pile.setScale({0.6,1,0.6})
local thirdCard=card("third",0.6)
pile=env.cleanupPlayedCardAtEndTurn(thirdCard,1,pile)
assert(pile.scale[1]==1.5 and pile.scale[3]==1.5,"Existing undersized pile restored")
assert(scaledRecords.third==nil,"New card loses the play-area scale record")

assert(source:find("drawn.setScale({1.5,1,1.5})",1,true),"Scripted draw must normalize taken cards")
assert(source:find("deedDeck.setScale({1.5,1,1.5})",1,true),"Scripted draw must normalize the source deck")
assert(read("src/PlayingGame/GameFlow/Turn.lua"):find(
    "if newDeck~=nil then newDeck.setScale({1.5,1,1.5}) end",1,true),
    "Round reset must restore the discard deck before reusing it")
print("Deed discard scale regression checks passed")
