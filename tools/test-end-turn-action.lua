-- End Turn must stay disabled without a newly played/discarded card, even when
-- a discard pile shrinks or play-area entry/exit notifications are stale.
-- Run from repository root: lua5.2 tools/test-end-turn-action.lua
local function read(path)
    local file=assert(io.open(path,"r"))
    local contents=file:read("*a")
    file:close()
    return contents
end
local source=read("src/PlayingGame/Interface/UI.lua")
local first=assert(source:find("local playAreaObjectState={}",1,true))
local last=assert(source:find("--End-round availability only changes",first,true))
local playObjects,discardObjects={},{}
local playZone={getObjects=function() return playObjects end}
local discardZone={getObjects=function() return discardObjects end}
local zones={play=playZone,discard=discardZone}
local state={
    playerPlayAreas={[1]="play"},
    deedDeckDiscardZones={[1]="discard"},
    gameCards={played={}},
    skillTokens={},
    turnOrder={{seatPos=1,discardCount=5}},
    gStates={bannercard={},doingTheRounds={}},
    getObjectFromGUID=function(guid) return zones[guid] end
}
setmetatable(state,{__index=_G})
assert(load(source:sub(first,last-1),"@end-turn-gate","t",state))()
local function card(guid)
    return {guid=guid,type="Card",getGMNotes=function() return "" end}
end
local function deck(count)
    return {type="Deck",getQuantity=function() return count end}
end
local function equal(actual,expected,message)
    assert(actual==expected,message..": expected "..tostring(expected)..", got "..tostring(actual))
end
discardObjects={deck(5)}
equal(state.endTurnPlayerHasAction(1,0),false,"Empty turn UI")
equal(state.endTurnPlayerHasAction(1),false,"Empty turn click")
discardObjects={deck(3)}
equal(state.endTurnPlayerHasAction(1,0),false,"Shrinking discard pile UI")
equal(state.endTurnPlayerHasAction(1),false,"Shrinking discard pile click")
discardObjects={deck(6)}
equal(state.endTurnPlayerHasAction(1,0),true,"Real discard enables End Turn")
discardObjects={deck(5)}
playObjects={card("played")}
equal(state.endTurnPlayerHasAction(1),true,"Played card enables End Turn")
equal(state.endTurnPlayerHasAction(1,1),true,"Cached played card enables button")
playObjects={}
equal(state.cachedPlayAreaCounts(1),1,"Test has stale play-area cache")
equal(state.endTurnPlayerHasAction(1),false,"Stale card rejected on click")
equal(state.cachedPlayAreaCounts(1),0,"Click reconciles stale cache")
zones.discard=nil
equal(state.endTurnPlayerHasAction(1,0),false,"Missing discard zone cannot unlock")
zones.discard=discardZone
state.turnOrder[1].discardCount=nil
discardObjects={deck(6)}
equal(state.endTurnPlayerHasAction(1,0),false,"Missing baseline cannot unlock")
assert(source:find('if source=="New Turn" then syncPlayAreaObjectState(currentPlayer.seatPos) end',1,true),
    "New turns must recheck physical play-area membership")
assert(source:find("endTurnPlayerHasAction(gStates.turnNumber)~=true",1,true),
    "The button must use the shared action gate")
local combat=read("src/PlayingGame/Combat/Combat.lua")
assert(combat:find("and endTurnPlayerHasAction(gStates.turnNumber)~=true",1,true),
    "The actual End Turn click must enforce the shared gate")
print("End Turn play/discard action regressions passed")
