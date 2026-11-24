-- Regression: a released card above the shallow Play Area zone keeps its
-- selected option and enemy target when rearranged. Y is intentionally ignored.
-- Run from repository root: lua5.2 tools/test-card-relocation-choice-lock.lua
package.path="src/?.lua;"..package.path
local function read(path)
    local f=assert(io.open(path,"r"))
    local content=f:read("*a")
    f:close()
    return content
end
local function slice(source,first,last)
    local a=assert(source:find(first,1,true),"Missing "..first)
    local b=assert(source:find(last,a+#first,true),"Missing "..last)
    return source:sub(a,b-1)
end

local source=read("src/PlayingGame/PlayerBoard/CardRecognition.lua")
local matCode=slice(source,"trackerPrivate.zoneFootprintContainsXZ=require(",
    "local function scheduleChoiceResetAfterPlay(")
local resetCode=slice(source,"local function scheduleChoiceResetAfterPlay(guid,seatPos)",
    "local footprint=require(")
local lockCode=slice(source,"local function combatSourceKeepsLock(key)",
    "-- Physical target controls and the calculator")
local dropCode=slice(source,"function resourceCardsObjectMoved(obj,stabilized)",
    "-- Register the remaining readying")
local recoverCode=slice(source,"    -- A released source may be above the shallow zone",
    "    -- A resting active Unit can be lifted")

local pos={x=0,y=12,z=0,[1]=0,[2]=12,[3]=0}
local card={
    guid="rage",type="Card",resting=false,held_by_color=nil,
    isSmoothMoving=function() return false end,
    isDestroyed=function() return false end,
    getPosition=function() return pos end
}
local zoneContents={}
local zone={
    -- The card is directly over the mat but has not fallen into the thin
    -- scripting zone yet, so getObjects initially returns no cards.
    getObjects=function() return zoneContents end,
    getBounds=function()
        return {center={x=0,z=0},size={x=0,z=0}}
    end,
    getPosition=function() return {x=0,z=0} end,
    getScale=function() return {x=12,z=12} end
}
local selected={rage={effect="attack"}}
local targets={rage="left"}
local tracker={choiceResetGenerationByGUID={},
    playCardMovements={},bySeat={[1]={rage=true}},
    playCandidatesBySeat={[1]={rage=true}},
    playCandidateKind=function(kind)
        return kind=="card" or kind=="skill" or kind=="factionReward"
    end,
    checkCardChoicesAfterDrop=function() end, -- Independent UI repair tested elsewhere
    readyForXZ=function(obj)
        return obj.held_by_color==nil and not obj.isSmoothMoving()
            and (obj.type~="Dice" or obj.resting==true)
    end}
local frames,conditions={},{}
local queues,historyResets=0,0
local env={
    trackerPrivate=tracker,selectedResourceByGUID=selected,
    choiceExpandedByGUID={rage=true},
    gStates={turnNumber=1,resourceCardPlayOrder={rage=2},
        unitReadyCardChoices={rage=true}},
    turnOrder={{seatPos=1}},playerPlayAreas={[1]="play"},
    getObjectFromGUID=function(guid)
        if guid=="rage" then return card end
        if guid=="play" then return zone end
        return nil
    end,
    attackAssignmentsTargetGUIDs=function()
        return targets.rage~=nil and {[targets.rage]=true} or {}
    end,
    combatAssignmentActiveSeat=function() return 1 end,
    resourceCardsPanelOpen=function() return true end,
    combatConfig={cardInTransit=function(obj)
        return obj.held_by_color~=nil or obj.isSmoothMoving()
    end},
    resourceObjectKind=function() return "card" end,
    -- This test covers the independent X/Z fallback, not the new pickup
    -- stability watcher (tested by test-card-relocation-stable-drop.lua).
    resourceCardsObjectPickedUp=function() end,
    manaColor=function() return nil end,
    unitLayoutIsCommand=function() return false end,
    unitLayoutIsWound=function() return false end,
    combatEnemyData=function() return nil end,
    safeWaitFrames=function(_,callback)
        frames[#frames+1]=callback
        return #frames
    end,
    safeWaitCondition=function(_,callback,predicate)
        conditions[#conditions+1]={callback=callback,predicate=predicate}
    end,
    resourceCardsArtifactBreakClear=function(guid) end, -- No Artifact in this fixture
    unitHistoryValidSources=function() historyResets=historyResets+1 end,
    queueSeat=function() queues=queues+1 end
}
setmetatable(env,{__index=_G})
local code=table.concat({matCode,resetCode,lockCode,dropCode,
    "return cardInSeatPlayArea,scheduleChoiceResetAfterPlay,combatSourceKeepsLock,resourceCardsObjectMoved"},"\n")
local onMat,scheduleReset,keepsLock,onDrop=
    assert(load(code,"Card relocation","t",env))()

assert(onMat("rage",1),"Released Rage above thin zone must count as on mat")
assert(not keepsLock("rage"),"Settled cards rely on active sources, not blanket arrow protection")
scheduleReset("rage",1)
assert(#frames==1,"Zone exit should defer choice reset")
frames[1]()
assert(#conditions==1 and conditions[1].predicate(),
    "Released falling card must not wait for the resting flag")
conditions[1].callback()
assert(selected.rage.effect=="attack" and targets.rage=="left",
    "Temporary zone exit must preserve Attack and left-enemy target")
assert(historyResets==0,"Rearrangement must not invalidate prior ready links")

onDrop(card)
assert(queues==1 and tracker.playCandidatesBySeat[1].rage==true,
    "Drop above thin zone must queue reconciliation and keep play candidate")
local recover=assert(load("return function(seatPos,objects,placements,objectKinds)\n"
    ..recoverCode.."\nend","Card recovery","t",env))()
local objects,placements,kinds={}, {}, {}
recover(1,objects,placements,kinds)
assert(objects.rage==card and placements.rage=="play" and kinds.rage=="card",
    "Released falling Rage must be included in resource scan")
assert(selected.rage.effect=="attack" and targets.rage=="left",
    "Recovered Rage keeps its Attack option and previously selected target")

-- EnterZone is positive evidence that the zone contains this card, even
-- when the approximate X/Z bounds disagree. The older membership check
-- returned false before looking at zone.getObjects(), which could clear
-- the option and prune the persistent enemy arrow after the drop.
pos.x,pos[1]=30,30
zoneContents={card}
assert(onMat("rage",1),
    "A zone-confirmed reentry must win over an X/Z bounds disagreement")
assert(not keepsLock("rage"),
    "On-mat geometry alone must not protect an inactive arrow after a choice change")
pos.x,pos[1]=0,0
zoneContents={}

-- While lifted, preserve the arrow but do not count a temporary hover as a
-- resource-producing card. A later drop can still restore it.
card.held_by_color="Blue"
assert(keepsLock("rage"),"Held Rage must keep its explicit target")
local flyingObjects,positions,types={}, {}, {}
recover(1,flyingObjects,positions,types)
assert(flyingObjects.rage==nil and tracker.playCandidatesBySeat[1].rage,
    "Held card should not be rescanned or retired")
card.held_by_color=nil

-- Actually removing Rage from the mat is different: its play choice should
-- reset and the combat lock should not be retained outside the play area.
pos.x,pos[1]=30,30
assert(not onMat("rage",1) and not keepsLock("rage"),
    "Card beyond play mat must not keep an active lock")
onDrop(card)
assert(tracker.playCandidatesBySeat[1].rage==nil,
    "Real departure should retire play-area candidate")
assert(#frames==2,"Real departure should schedule choice cleanup")
frames[2]()
assert(#conditions==2 and conditions[2].predicate(),
    "Released card outside mat is ready for cleanup")
conditions[2].callback()
assert(selected.rage==nil and env.gStates.resourceCardPlayOrder.rage==nil,
    "Leaving the play mat must clear old choices/play-order history")
print("Card relocation choice/target lock regression passed")
