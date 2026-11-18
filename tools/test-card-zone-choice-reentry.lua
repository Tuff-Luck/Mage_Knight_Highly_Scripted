-- An onEnterZone for a returning card must cancel the pending
-- onExitZone choice reset, even if the zone's object list lags the drop.
-- Run from repository root: lua5.2 tools/test-card-zone-choice-reentry.lua
local function read(path)
    local f=assert(io.open(path,"r"))
    local s=f:read("*a")
    f:close()
    return s
end
local function section(text,first,last)
    local a=assert(text:find(first,1,true),"Missing "..first)
    local b=assert(text:find(last,a+#first,true),"Missing "..last)
    return text:sub(a,b-1)
end
local source=read("src/PlayingGame/PlayerBoard/CardRecognition.lua")
local zoneCode=section(source,"function resourceCardsZoneEntered(ctx)",
    "function resourceCardsZoneLeft(ctx)")
local matCode=section(source,"trackerPrivate.cardOverPlayMat=function(obj,seatPos)",
    "local function scheduleChoiceResetAfterPlay(guid,seatPos)")
local resetCode=section(source,"local function scheduleChoiceResetAfterPlay(guid,seatPos)",
    "local function footprint(obj)")
local pos={x=30,y=6,z=0,[1]=30,[2]=6,[3]=0}
local card={guid="rage",type="Card",resting=true,held_by_color=nil,
    isSmoothMoving=function() return false end,
    getPosition=function() return pos end,
    isDestroyed=function() return false end}
local zone={getObjects=function() return {} end,
    getBounds=function() return {center={x=0,z=0},size={x=0,z=0}} end,
    getPosition=function() return {x=0,z=0} end,
    getScale=function() return {x=12,z=12} end}
local states={rage={effect="block"}}
local tracker={
    playCandidatesBySeat={},bySeat={},playCardMovements={},choiceResetGenerationByGUID={},
    playCandidateKind=function(kind) return kind=="card" end,
    readyForXZ=function() return true end
}
local frameCallbacks,waits,queued={}, {}, 0
local env={
    trackerPrivate=tracker,selectedResourceByGUID=states,
    choiceExpandedByGUID={},gStates={turnNumber=1,resourceCardPlayOrder={rage=1}},
    turnOrder={{seatPos=1}},playerPlayAreas={[1]="zone"},
    gameCards={rage={resourceKey="rage"}},
    getObjectFromGUID=function(guid)
        if guid=="zone" then return zone end
        if guid=="rage" then return card end
    end,
    resourceCardsPanelOpen=function() return true end,
    resourceCardsRelevantZone=function() return 1 end,
    resourceObjectKind=function() return "card" end,
    manaColor=function() return nil end,
    queueSeat=function() queued=queued+1 end,
    safeWaitFrames=function(_,callback)
        frameCallbacks[#frameCallbacks+1]=callback
        return #frameCallbacks
    end,
    safeWaitCondition=function(_,callback,predicate)
        waits[#waits+1]={callback=callback,predicate=predicate}
    end,
    unitHistoryValidSources=function() end
}
setmetatable(env,{__index=_G})
local functions=table.concat({matCode,resetCode,zoneCode,
    "return scheduleChoiceResetAfterPlay,resourceCardsZoneEntered"},"\n")
local onExit,onEnter=assert(load(functions,"Reentry choice reset","t",env))()
onExit("rage",1)
assert(#frameCallbacks==1 and states.rage.effect=="block","Exit schedules deferred reset")
-- Reentry arrives while the object is still high/outside the shallow zone
-- provider's reported footprint. An older exit callback must never win.
onEnter({obj=card,objGUID="rage",objType="Card",zoneInfo={kind="play",seatPos=1}})
frameCallbacks[1]()
assert(#waits==0 and states.rage.effect=="block",
    "Reentry must invalidate queued exit reset before it runs")
assert(queued==1,"Reentering should still request a resource scan")
-- A completed onDrop was already calculated. TTS subsequently reports
-- onEnterZone when that same card falls into the shallow scripting zone.
-- This must NOT calculate a second time or override the selected target.
pos.x,pos[1]=0,0
onEnter({obj=card,objGUID="rage",objType="Card",zoneInfo={kind="play",seatPos=1}})
assert(queued==1,"Late onEnter after onDrop must not recalculate")
assert(states.rage.effect=="block","Card selection remains Block after reentry")
-- A subsequent *real* removal, with no reentry, still retires that choice.
pos.x,pos[1]=30,30
onExit("rage",1)
assert(#frameCallbacks==2)
frameCallbacks[2]()
assert(#waits==1 and waits[1].predicate(),
    "Real departure must be eligible for final choice cleanup")
waits[1].callback()
assert(states.rage==nil and env.gStates.resourceCardPlayOrder.rage==nil,
    "True departure must retire the previous play selection")
print("Card exit/reentry choice-reset regression passed")
