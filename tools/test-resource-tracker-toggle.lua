-- The minimized Resource Tracker must be truly OFF, including during the UI's update lag.
-- Run from repository root: lua5.2 tools/test-resource-tracker-toggle.lua
local function check(label, condition)
    assert(condition,label)
    print("PASS "..label)
end

local attributes={
    ResourceTracker={active="true",height="245"},
    ResourceTrackerDetail={active="true"}
}
UI={
    getAttribute=function(id,key)
        return attributes[id]~=nil and attributes[id][key] or nil
    end,
    setAttribute=function(id,key,value)
        attributes[id]=attributes[id] or {}
        attributes[id][key]=value
    end
}
local arrowsCleared,defeatsCleared,moveCleared,repRefreshed=0,0,0,0
local textRefreshed,moveCalculated,scanQueued=0,0,0
getObjectFromGUID=function() return nil end
attackAssignmentsClearAll=function() arrowsCleared=arrowsCleared+1 end
combatClearDefeatMarks=function() defeatsCleared=defeatsCleared+1 end
clearMoveDisplayVisuals=function() moveCleared=moveCleared+1 end
resourceFameRepApply=function() end
refreshResourceTrackerReputation=function() repRefreshed=repRefreshed+1 end
refreshResourceTrackerText=function() textRefreshed=textRefreshed+1 end
updateMoveDisplay=function() moveCalculated=moveCalculated+1 end
safeWaitCondition=function() scanQueued=scanQueued+1 end

unitResourceDefinitions={unit1={{key="move"}}}
unitLayoutSnapshot=function()
    return {commands={{guid="new-command-token"}}}
end
unitLayoutCommandTarget=function()
    return {guid="unit1"}
end
unitLayoutResourceState=function()
    return {units={{guid="unit1",unwounded=true}}}
end
gStates={
    firstStarted=true,turnNumber=1,
    moveCost={plains=2,forest=5},
    resourceTracker={
        move={move=5},siege={physical=0},ranged={physical=0},
        block={physical=0},attack={physical=0},
        influence={generated=3,reputation=1,cityShields=0},
        healing={healing=2},playerPos={10,1,10}
    },
    unitResourceActivations={unit1={seatPos=1,tokenGUID="old-token",choice=1}}
}
turnOrder={{seatPos=1}}
dofile("src/PlayingGame/PlayerBoard/CardRecognition.lua")

check("expanded tracker starts enabled",resourceCardsPanelOpen() and resourceCardsPanelReady())
-- Close while TTS still reports the old expanded attributes for one frame.
resourceCardsPanelChanged(false)
check("OFF latches before UI changes are applied",
    not resourceCardsPanelOpen() and resourceCardsPanelReady())
check("closing clears combat overlays, attack arrows and map overlays",
    arrowsCleared==1 and defeatsCleared==1 and moveCleared==1)
check("closing drops stale Unit activations",
    next(gStates.unitResourceActivations)==nil)
check("closing clears previous manual Move, Influence and Heal amounts",
    gStates.resourceTracker.move.move==0 and gStates.resourceTracker.influence.generated==0
    and gStates.resourceTracker.healing.healing==0 and gStates.resourceTracker.playerPos==nil)
check("closing preserves real terrain costs and reputation baseline",
    gStates.moveCost.plains==2 and gStates.moveCost.forest==5
    and gStates.resourceTracker.influence.reputation==1)
check("closing invokes no UI or movement calculation",
    textRefreshed==0 and moveCalculated==0)
check("OFF returns no tracked Move and no active resource totals",
    resourceCardsEffectiveValue("move","move")==0 and resourceCardsCurrentTotals()==nil
    and resourceCardsCurrentMovementEffects()==nil)
check("OFF retains only printed terrain cost",
    resourceCardsEffectiveTerrainCost("plains")==2)

attributes.ResourceTrackerDetail.active="false"
resourceCardsZoneEntered({zoneInfo={kind="play"},obj={guid="card"}})
resourceCardsZoneLeft({zoneInfo={kind="play"},obj={guid="card"}})
resourceCardsObjectMoved({guid="card"})
resourceUnitsCommandPickedUp("Red",{guid="new-command-token"})
resourceUnitsCommandDropped("Red",{guid="new-command-token"})
resourceCardsSourceChanged()
check("OFF zone and Command events do not schedule new scans",
    scanQueued==0 and next(gStates.unitResourceActivations)==nil)

-- Re-enable without moving a stale saved activation into the new session.
attributes.ResourceTrackerDetail.active="true"
check("visibility alone cannot restart an OFF tracker",
    resourceCardsPanelReady() and not resourceCardsPanelOpen())
resourceCardsPanelChanged(true)
check("restart enables the tracker and recalculates the UI",
    resourceCardsPanelOpen() and repRefreshed==1
    and textRefreshed==1 and moveCalculated==1)
check("restart rebuilds used Units from current physical Command tokens",
    gStates.unitResourceActivations.unit1~=nil
    and gStates.unitResourceActivations.unit1.tokenGUID=="new-command-token"
    and gStates.unitResourceActivations.unit1.choice==1)
check("restart schedules a new play-area scan",scanQueued==1)
print("Resource tracker OFF/restart regression tests passed.")
