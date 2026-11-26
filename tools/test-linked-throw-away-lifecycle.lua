-- Linked throw-away restacking and recovery from the hand while the tracker is OFF.
local function read(path)
    local f=assert(io.open(path,"r"))
    local s=f:read("*a")
    f:close()
    return s
end
local function section(s,first,last)
    local a=assert(s:find(first,1,true),"Missing "..first)
    local b=assert(s:find(last,a+#first,true),"Missing "..last)
    return s:sub(a,b-1)
end
local rec=read("src/PlayingGame/PlayerBoard/CardRecognition.lua")
local events=read("src/PlayingGame/GameFlow/Events.lua")
assert(events:find("resourceCardsReturnedToHand(liveCtx.obj,liveCtx.zoneInfo.seatPos)",1,true),
    "Confirmed hand entry must reach the recovery path")
local private={
    playCardMovements={},choiceResetGenerationByGUID={},cardUIRecheckSerial={},
    playCandidatesBySeat={[1]={}},maximalMarkedByGUID={}
}
local cards,frames,swaps={}, {},0
local refreshes=0
local open=true
local moving=false
local function card(guid,y)
    local obj={guid=guid,type="Card",y=y}
    obj.getPosition=function() return {x=0,y=obj.y,z=0} end
    cards[guid]=obj
    return obj
end
local source=card("main",1.2)
local target=card("target",1.3)
local ordinary=card("ordinary",1.3)
local choices,expanded,shown={}, {},{}
local env=setmetatable({
    trackerPrivate=private,
    gameCards={main={resourceKey="maximal"},target={},ordinary={}},
    cardResourceDefinitions={maximal={requiredLink={mode="repeat"}},
        ritual={requiredLink={mode="throwAway"}}},
    gStates={artifactBreaks={},artifactGrailHealingUsed={},resourceCardMoveRoles={},
        resourceCardPlayOrder={},unitReadyCardChoices={},throwAwayCleanupByGUID={}},
    combatConfig={cardInTransit=function(obj) return moving and obj==target end},
    getObjectFromGUID=function(guid) return cards[guid] end,
    resourceCardsPanelOpen=function() return open end,
    resourceCardsArtifactBroken=function() return false end,
    resourceCardsArtifactBreakClear=function(guid) end,
    resourceCardsMaximalEffectMark=function(obj,active)
        private.maximalMarkedByGUID[obj.guid]=active and true or nil
        obj.marked=active
    end,
    resourceCardsMaximalEffectMarked=function(obj) return obj.marked==true end,
    safeWaitFrames=function(_,callback) frames[#frames+1]=callback end,
    cardInSeatPlayArea=function() return true end,
    footprint=function(obj) return obj end,
    overlapArea=function() return 1 end,
    playerBoardSendCardUnder=function(lower,upper,finished)
        assert(lower==target and upper==source,"Only the consumed card is tucked")
        lower.y,upper.y=upper.y,upper.y+0.13
        swaps=swaps+1
        finished()
    end,
    resourceCardsSourceChanged=function() refreshes=refreshes+1 end,
    selectedResourceByGUID=choices,choiceExpandedByGUID=expanded,choiceButtonShown=shown,
    combatAssignmentState={targets={},explicit={}},
    removeChoiceButtons=function(obj) obj.controlsRemoved=true end,
    queueSeat=function() error("OFF tracker must not scan on hand recovery") end,
    unitHistoryValidSources=function() end
},{__index=_G})
env.resourceCardsArtifactBreakClear=function(guid) env.gStates.artifactBreaks[guid]=nil end
private.objectEvents=assert(loadfile("src/PlayingGame/PlayerBoard/ResourceTracker/Core/ObjectEvents.lua","t",env))()
local code=section(rec,"function resourceCardsMaximalEffectSyncMarks(","-- Cleanup and the UI consult")
    ..section(rec,"function resourceCardsReturnedToHand(","function resourceCardsSourceChanged()")
assert(load(code,"Throw-away lifecycle","t",env))()
local function scan()
    env.resourceCardsMaximalEffectSyncMarks(1,{source,target,ordinary},
        {target={sourceGUID=source.guid}}, {target=source.guid,ordinary=source.guid},{main=true})
end
local function tick()
    assert(#frames>0,"Expected a pending physics sample")
    table.remove(frames,1)()
end
local function drain()
    local tries=0
    while #frames>0 do
        tries=tries+1
        assert(tries<100,"Physics sampling must be bounded")
        tick()
    end
end
scan()
assert(target.marked and not ordinary.marked and #frames==1,
    "Only a genuine throw-away link is marked and schedules a restack")
scan()
assert(#frames==1,"A repeated scan must not queue duplicate movement")
tick()
tick()
assert(swaps==0,"Wait for the source height to stabilize before moving")
tick()
assert(swaps==1 and target.y<source.y,"Linked payment goes under its owner")
drain()
assert(refreshes==1,"One reconciliation after physical settling")
scan()
assert(#frames==0 and swaps==1,"An already-under payment is not moved again")

-- Ritual Attack uses the paid throwAway link, not the repeat branch.
env.gameCards.main.resourceKey="ritual"
local function ritualScan()
    env.resourceCardsMaximalEffectSyncMarks(1,{source,target,ordinary},
        {}, {target=source.guid},{main=true})
end
target.y=source.y
ritualScan()
assert(target.marked and private.throwAwayLinksByGUID[target.guid]=="ritualAttack"
    and #frames==1,"Ritual Attack must sample even at equal Y")
moving=true
tick()
assert(swaps==1 and #frames==1,"Transient motion defers the tuck")
moving=false
target.y=source.y+0.6
tick()
assert(swaps==1 and #frames==1,"A high falling card must be sampled again")
target.y=source.y+0.2
tick()
assert(swaps==1,"Source height has not yet stabilized")
tick()
assert(swaps==2 and target.y<source.y,"Ritual Attack tucks in the normal height window")
-- Smooth completion may be followed by bounce/settling. Suppress only
-- overlapping physical transactions, not subsequent legitimate under moves.
local settledY=target.y
target.y=source.y
ritualScan()
tick()
target.y=source.y+0.1
ritualScan()
tick()
assert(swaps==2 and #frames==1,"No duplicate tuck during post-move bounce")
target.y=settledY
drain()
ritualScan()
assert(#frames==0,"Ritual Attack already below its owner stays put")
target.y=source.y+0.1
ritualScan()
drain()
assert(swaps==3 and target.y<source.y,
    "A later manual rearrangement of the same paid link may tuck again")
-- Near-equal height only dispatches after stable samples, and a cancelled
-- link must not cause movement.
target.y=source.y
ritualScan()
tick()
tick()
assert(swaps==3,"Equal-height pair must not move on a single sample")
env.resourceCardsMaximalEffectSyncMarks(1,{source,target,ordinary},{},{},{})
tick()
assert(swaps==3 and #frames==0 and not target.marked,"Cancelled link must not restack")
ritualScan()
drain()
assert(swaps==4 and target.marked and target.y<source.y,
    "A valid stable equal-height link can still tuck")

open=false
local guid=target.guid
local state=env.gStates
state.resourceCardPlayOrder[guid]=7
state.artifactBreaks[guid]=true
state.artifactGrailHealingUsed[guid]=true
state.resourceCardMoveRoles[guid]="combat"
state.unitReadyCardChoices[guid]=1
state.throwAwayCleanupByGUID[guid]="maximalEffect"
choices[guid]={effect="attack"}
expanded[guid]=true
shown[guid]="active"
private.playCardMovements[guid]={}
private.playCandidatesBySeat[1][guid]=true
env.combatAssignmentState.targets[guid.."#attack"]="enemy"
env.combatAssignmentState.explicit[guid.."#attack"]=true
env.combatAssignmentState.targets["unrelated"]="enemy"
env.resourceCardsReturnedToHand(target,1)
assert(not target.marked and private.maximalMarkedByGUID[guid]==nil
    and private.throwAwayLinksByGUID[guid]==nil
    and private.throwAwaySourcesByGUID[guid]==nil
    and state.throwAwayCleanupByGUID[guid]==nil,
    "Hand recovery must clear marker and every throw-away verdict")
assert(state.resourceCardPlayOrder[guid]==nil and state.artifactBreaks[guid]==nil
    and state.artifactGrailHealingUsed[guid]==nil and state.resourceCardMoveRoles[guid]==nil
    and state.unitReadyCardChoices[guid]==nil and choices[guid]==nil and expanded[guid]==nil
    and shown[guid]==nil and target.controlsRemoved,
    "Hand recovery must retire the previous play and its controls")
assert(private.playCardMovements[guid]==nil and private.playCandidatesBySeat[1][guid]==nil
    and private.choiceResetGenerationByGUID[guid]==1 and private.cardUIRecheckSerial[guid]==1
    and env.combatAssignmentState.targets[guid.."#attack"]==nil
    and env.combatAssignmentState.explicit[guid.."#attack"]==nil
    and env.combatAssignmentState.targets.unrelated=="enemy",
    "Hand recovery cancels stale callbacks and only this card's assignments")
env.resourceCardsReturnedToHand(target,1)
assert(private.choiceResetGenerationByGUID[guid]==1,"Hand recovery is idempotent")
print("Linked throw-away restack and hand recovery regressions passed")
