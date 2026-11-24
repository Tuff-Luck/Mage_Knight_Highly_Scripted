-- Regression for TTS calling onEnterZone after the player's drop.
-- A source already in play must not restart pickup/relocation or recalculate
-- based on its new nearest enemy.  Run: lua5.2 tools/test-card-enter-zone-idempotence.lua
local function read(path)
    local f=assert(io.open(path,"r"))
    local s=f:read("*a")
    f:close()
    return s
end
local function section(source,first,last)
    local a=assert(source:find(first,1,true),"Missing "..first)
    local b=assert(source:find(last,a+#first,true),"Missing "..last)
    return source:sub(a,b-1)
end
local source=read("src/PlayingGame/PlayerBoard/CardRecognition.lua")
local mat=section(source,"trackerPrivate.zoneFootprintContainsXZ=function(obj,zone)",
    "local function scheduleChoiceResetAfterPlay(")
local zones=section(source,"function resourceCardsZoneEntered(ctx)",
    "function resourceCardsObjectMoved(")
local lock=section(source,"local function combatSourceKeepsLock(key)",
    "-- Physical target controls and the calculator")
local position={x=0,y=6,z=0,[1]=0,[2]=6,[3]=0}
local card={guid="52efb0",type="Card",resting=true,held_by_color=nil,
    getPosition=function() return position end,
    isSmoothMoving=function() return false end,
    isDestroyed=function() return false end}
local zone={getObjects=function() return {} end,
    getBounds=function() return {center={x=0,z=0},size={x=0,z=0}} end,
    getPosition=function() return {x=0,z=0} end,
    getScale=function() return {x=12,z=12} end}
local state={playCandidatesBySeat={[1]={["52efb0"]=true}},
    bySeat={[1]={["52efb0"]=true}},
    playCardMovements={},choiceResetGenerationByGUID={},
    playCandidateKind=function(kind) return kind=="card" end}
local queued,resets=0,0
local env={
    trackerPrivate=state,playerPlayAreas={[1]="zone"},
    turnOrder={{seatPos=1}},gStates={turnNumber=1,resourceCardPlayOrder={["52efb0"]=1}},
    gameCards={["52efb0"]={resourceKey="rage"}},
    resourceCardsPanelOpen=function() return true end,
    resourceCardsRelevantZone=function() return 1 end,
    resourceObjectKind=function() return "card" end,
    cardInSeatPlayArea=nil,
    getObjectFromGUID=function(guid)
        if guid=="zone" then return zone end
        if guid=="52efb0" then return card end
    end,
    resourceCardsObjectPickedUp=function()
        error("EnterZone must not infer pickup from resting=false")
    end,
    manaColor=function() return nil end,
    queueSeat=function() queued=queued+1 end,
    scheduleChoiceResetAfterPlay=function() resets=resets+1 end,
    combatConfig={cardInTransit=function(obj)
        return obj.held_by_color~=nil
    end},
    combatAssignmentActiveSeat=function() return 1 end,
    attackAssignmentsTargetGUIDs=function() return {left=true} end
}
setmetatable(env,{__index=_G})
local onEnter,onExit,keeps=assert(load(
    table.concat({mat,lock,zones,
        "return resourceCardsZoneEntered,resourceCardsZoneLeft,combatSourceKeepsLock"},"\n"),
    "Reentry double-calculation","t",env))()
local ctx={objGUID="52efb0",obj=card,objType="Card",
    zoneInfo={kind="play",seatPos=1}}
-- When TTS notifies enter after a completed drop, it may report resting
-- false again. No second scan or fake pickup is permitted.
card.resting=false
onEnter(ctx)
assert(queued==0,"Known played card must not rescan on late EnterZone")
assert(state.choiceResetGenerationByGUID["52efb0"]==1,
    "Reentry must cancel a queued exit choice-reset")
assert(state.playCardMovements["52efb0"]==nil,
    "EnterZone must not start a new movement transaction")
assert(not keeps("52efb0"),
    "Released active cards should be preserved by the scan, not by blanket lock")
-- A later delayed entry with resting=true is equally redundant.
card.resting=true
onEnter(ctx)
assert(queued==0,"Rested source must not rescan on duplicate EnterZone")
assert(not keeps("52efb0"),
    "A settled inactive source must not keep an obsolete target lock")
-- Even if a temporary scan lost the candidate cache, the prior seat scan
-- still proves that this is a rearrangement rather than a newly played card.
state.playCandidatesBySeat[1]["52efb0"]=nil
onEnter(ctx)
assert(queued==0 and state.playCandidatesBySeat[1]["52efb0"]==true,
    "Known card in prior seat scan must not be reprocessed after a late enter")
-- A real pickup/exit is reconciled by onDrop; do not rescan while carried.
card.held_by_color="Blue"
onExit(ctx)
assert(queued==0 and resets==0,
    "Held zone exit must not schedule a choice reset or empty scan")
-- Once actually dropped outside the Play Area, the exit queues a scan.
card.held_by_color=nil
position.x,position[1]=30,30
onExit(ctx)
assert(queued==1 and resets==1,"Real departure should trigger cleanup")
assert(not keeps("52efb0"),"Target lock cannot survive genuine off-mat removal")
-- A truly new card entering play still requests a first resource scan.
state.playCandidatesBySeat[1]["52efb0"]=nil
state.bySeat[1]["52efb0"]=nil
position.x,position[1]=0,0
onEnter(ctx)
assert(queued==2,"A newly played card must still trigger a scan")
print("Card enter-zone idempotence regressions passed")
