-- Moving an explicitly configured card must never publish intermediate
-- resource totals or switch its enemy target to the nearest opponent.
-- Run from repository root: lua5.2 tools/test-card-relocation-stable-drop.lua
local function read(path)
    local file=assert(io.open(path,"r"))
    local source=file:read("*a")
    file:close()
    return source
end
local function section(source,first,last)
    local a=assert(source:find(first,1,true),"Missing "..first)
    local b=assert(source:find(last,a+#first,true),"Missing "..last)
    return source:sub(a,b-1)
end

local source=read("src/PlayingGame/PlayerBoard/CardRecognition.lua")
local events=read("src/PlayingGame/Events.lua")
assert(events:find("resourceCardsObjectPickedUp(picked_up_object)",1,true),
    "Picking up a source must mark the relocation before callbacks rescan it")
local matCode=section(source,"trackerPrivate.zoneFootprintContainsXZ=function(obj,zone)",
    "local function scheduleChoiceResetAfterPlay(")
local resetCode=section(source,"local function scheduleChoiceResetAfterPlay(guid,seatPos)",
    "local function footprint(obj)")
local relocationCode=section(source,"function resourceCardsObjectPickedUp(obj)",
    "function resourceCardsZoneEntered(ctx)")
local renderGuard=section(source,"local function renderSeat(seatPos)",
    "    trackerPrivate.renderCombatNight=nil")
local choiceCode=section(source,"local function currentChoice(guid,powered,choices,sideways)",
    "local function chosenEffect(")
assert(source:find("trackerPrivate.playCardMovements[obj.guid]~=nil then",1,true),
    "Dropped card must first finish its relocation")
assert(source:find("resourceCardsObjectMoved(live,true)",1,true)
    and source:find('if not stabilized and obj.type~="Dice"',1,true),
    "Stable falling cards must not restart the relocation watcher")
assert(source:find("trackerPrivate.playCardMovements={}\n    trackerPrivate.cardUIRecheckSerial={}\n    resourceCardScanBySeat={}",1,true),
    "Disabling tracker must cancel relocation watches")

local pos={x=0,y=5,z=0,[1]=0,[2]=5,[3]=0}
local rot={x=0,y=0,z=0,[1]=0,[2]=0,[3]=0}
local card={
    guid="rage",type="Card",resting=false,held_by_color="Blue",
    is_face_down=false,
    isSmoothMoving=function() return false end,
    isDestroyed=function() return false end,
    getPosition=function() return pos end,
    getRotation=function() return rot end
}
local zone={
    getObjects=function() return {} end,
    getBounds=function() return {center={x=0,z=0},size={x=0,z=0}} end,
    getPosition=function() return {x=0,z=0} end,
    getScale=function() return {x=12,z=12} end
}
local selected={rage={effect="attack"}}
local targets={rage="left"}
local calculator={targets={rage="left"},explicit={rage=true}}
local tracker={
    playCandidatesBySeat={[1]={rage=true}},bySeat={[1]={rage=true}},
    playCardMovements={},choiceResetGenerationByGUID={},
    playCandidateKind=function(kind) return kind=="card" end,
    readyForXZ=function(obj)
        return obj.held_by_color==nil and not obj.isSmoothMoving()
    end
}
local frames,conditions={},{}
local completeScans,dropCommits=0,0
local env={
    trackerPrivate=tracker,selectedResourceByGUID=selected,
    combatAssignmentState=calculator,
    cardPosture=function(obj)
        local y=(obj.getRotation().y or 0)%180
        if y<25 then return "upright" end
        if y<=70 then return "discard" end
        return "sideways"
    end,
    choiceExpandedByGUID={},gStates={turnNumber=1,
        resourceCardPlayOrder={rage=1}},turnOrder={{seatPos=1}},
    playerPlayAreas={[1]="zone"},
    getObjectFromGUID=function(guid)
        if guid=="rage" then return card end
        if guid=="zone" then return zone end
    end,
    resourceCardsPanelOpen=function() return true end,
    resourceObjectKind=function() return "card" end,
    safeWaitFrames=function(_owner,callback,_frames)
        frames[#frames+1]=callback
        return #frames
    end,
    safeWaitCondition=function(_,callback,predicate)
        conditions[#conditions+1]={callback=callback,predicate=predicate}
    end,
    unitHistoryValidSources=function() error("Do not reset choice on rearrange") end,
    queueSeat=function() end,
    resourceCardsObjectMoved=function(moved,stabilized)
        assert(moved==card and stabilized==true
            and moved.resting==false,"Y falling must not rearm drop processing")
        dropCommits=dropCommits+1
        assert(selected.rage.effect=="attack" and targets.rage=="left"
            and calculator.targets.rage=="left" and calculator.explicit.rage,
            "Card must not silently change effect or its explicitly locked enemy")
    end,
    choiceAvailable=function(options,category)
        for _,option in ipairs(options or {}) do
            for key in pairs(option) do if key==category then return true end end
        end
        return false
    end,
    choiceCategory=function(option)
        for key in pairs(option) do return key end
    end
}
setmetatable(env,{__index=_G})
local code=table.concat({matCode,resetCode,relocationCode,choiceCode,
    renderGuard,"    return true\nend",
    "return resourceCardsObjectPickedUp,trackerPrivate.finishPlayCardMove,"
    .."scheduleChoiceResetAfterPlay,currentChoice,renderSeat"},"\n")
local pickup,finish,reset,choice,render=
    assert(load(code,"Card relocation stability","t",env))()
local function tick()
    local callbacks=frames
    frames={}
    for _,callback in ipairs(callbacks) do callback() end
end
local function renderIfReady()
    if render(1) then completeScans=completeScans+1 end
end
local function checkChoice()
    local _,effect=choice("rage",false,{{attack=2},{block=2}},false)
    assert(effect=="attack","Rage must still be Attack 2, not default Block 2")
end

checkChoice()
renderIfReady()
assert(completeScans==1,"Initial calculator must be rendered")
pickup(card)
assert(tracker.playCardMovements.rage~=nil,"Pickup did not protect card")
assert(tracker.playCardMovements.rage.targets.rage.targetGUID=="left",
    "Pickup must save the explicit calculator target")
renderIfReady()
assert(completeScans==1,"Pickup must freeze the previous calculator result")
reset("rage",1)
tick()
assert(#conditions==1,"A temporary zone exit must defer its choice reset")
assert(conditions[1].predicate()==false,"Held card is not ready for reset")
-- Even if an unrelated event tried to reassign the intermediate source,
-- the completed drop must restore the selected card effect and original lock.
selected.rage=nil
calculator.targets.rage="right"
calculator.explicit.rage=nil

-- A fast dropped card can rotate through the sideways and discard values.
-- The tracker must not publish any of those transient interpretations.
card.held_by_color=nil
rot.y,rot[2]=90,90
finish(card)
tick()
renderIfReady()
assert(completeScans==1 and dropCommits==0,"Sideways drop frame must stay frozen")
rot.y,rot[2]=45,45
tick()
renderIfReady()
assert(completeScans==1 and dropCommits==0,"Discard rotation must stay frozen")
rot.y,rot[2]=0,0
tick()
renderIfReady()
assert(completeScans==1 and dropCommits==0,"First upright frame is not settled")
tick()
assert(dropCommits==0,"One stable rotation frame is insufficient")
tick()
assert(dropCommits==1,"Stable released card must reconcile exactly once")
assert(tracker.playCardMovements.rage==nil,"Completed move must unblock scans")
assert(tracker.playCandidatesBySeat[1].rage==true,
    "Drop must retain play membership for duplicate EnterZone suppression")
assert(conditions[1].predicate()==true,"Real release must unblock reset check")
conditions[1].callback()
checkChoice()
assert(targets.rage=="left","Enemy target must remain explicit")
renderIfReady()
assert(completeScans==2,"Card should produce one final complete calculator result")

-- Lifting the same card again must invalidate the old hand-off and preserve
-- the same choice and target through another move, independent of its Y.
card.held_by_color="Blue"
pickup(card)
card.held_by_color=nil
pos.y,pos[2]=10,10
finish(card)
for i=1,3 do tick() end
assert(dropCommits==2 and tracker.playCardMovements.rage==nil,
    "Second relocation must also reconcile exactly once")
checkChoice()
assert(targets.rage=="left","Second move must retain left-enemy lock")

-- A missed Drop must NOT leave an immortal lock after 30 held samples.
-- U/Place Under can rearrange a card without any normal pickup/drop sequence.
-- The watcher begins at pickup and recovers on release without a Drop event.
card.held_by_color="Blue"
pickup(card)
assert(#frames>0,"Pickup must start its own release watcher")
for i=1,45 do tick() end
assert(tracker.playCardMovements.rage~=nil,
    "A long hold should still protect the selected choice and target")
card.held_by_color=nil
for i=1,4 do tick() end
assert(dropCommits==3 and tracker.playCardMovements.rage==nil,
    "Missing onObjectDrop must recover and unblock future updates")

-- Native U is observable through onPlayerAction even when no zone events fire.
local underCode=section(source,"function resourceCardsUnderAction(targets)",
    "\nfunction resourceCardsZoneEntered(ctx)")
local actionCode=section(events,"function __onPlayerAction_raw(player,action,targets)",
    "\nlocal function protectedObjectDestroyAudit")
local underFrames,picked,moved,changed={},0,0,0
local underEnv={
    trackerPrivate={traceEnabled=false},
    resourceCardsPanelOpen=function() return true end,
    resourceCardsObjectPickedUp=function(obj)
        assert(obj==card)
        picked=picked+1
    end,
    resourceCardsObjectMoved=function(obj)
        assert(obj==card)
        moved=moved+1
    end,
    resourceCardsSourceChanged=function() changed=changed+1 end,
    getObjectFromGUID=function(guid) return guid==card.guid and card or nil end,
    safeWaitFrames=function(_owner,callback,_frames)
        underFrames[#underFrames+1]=callback
    end
}
setmetatable(underEnv,{__index=_G})
local under=assert(load(underCode.."\nreturn resourceCardsUnderAction",
    "Native Under action","t",underEnv))()
local actionEnv={
    Player={Action={Under=1,Delete=2,Cut=3,PickUp=4}},
    gStates={firstStarted=true},
    resourceCardsUnderAction=under
}
setmetatable(actionEnv,{__index=_G})
local playerAction=assert(load(actionCode.."\nreturn __onPlayerAction_raw",
    "TTS player action","t",actionEnv))()
assert(playerAction({color="Blue"},actionEnv.Player.Action.Under,{card})==true)
assert(picked==1 and moved==0 and #underFrames==1,
    "U must capture the moved card before its native stacking finishes")
underFrames[1]()
assert(moved==1 and changed==1,
    "U must trigger a settled tracker refresh without Drop/Zone callbacks")
assert(playerAction({color="Blue"},actionEnv.Player.Action.PickUp,{card})==true
    and picked==1,"Other player actions must not be intercepted")
print("Card relocation stable-drop and U action regressions passed")
