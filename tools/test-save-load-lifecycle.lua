-- Save/load regressions for explicit resource choices, damage planning,
-- destroyed roller dice, and compatibility with older optional save fields.
-- Run from repository root: lua5.2 tools/test-save-load-lifecycle.lua
local function read(path)
    local file=assert(io.open(path,"r"))
    local contents=file:read("*a")
    file:close()
    return contents
end
local function section(source,startMarker,endMarker)
    local first=assert(source:find(startMarker,1,true),startMarker)
    local last=assert(source:find(endMarker,first+#startMarker,true),endMarker)
    return source:sub(first,last-1)
end
local function eq(actual,expected,message)
    assert(actual==expected,(message or "Mismatch")..": expected "..
        tostring(expected)..", got "..tostring(actual),2)
end
local function loadSection(source,first,last,env,returns)
    setmetatable(env,{__index=_G})
    return assert(load(section(source,first,last).."\n"..returns,
        "save/load regression","t",env))()
end

local cards=read("src/PlayingGame/PlayerBoard/CardRecognition.lua")
local combat=read("src/PlayingGame/AttackAssignments.lua")
local events=read("src/PlayingGame/Events.lua")
local callbacks=read("src/PlayingGame/Callbacks.lua")
local rollers=read("src/PlayingGame/Rollers.lua")

-- Save current choices rather than re-guessing them after loading.
local zones={
    play={getObjects=function() return {{guid="played"},{guid="facedown"}} end},
    units={getObjects=function() return {{guid="unit"}} end}
}
local choiceEnv={
    trackerPrivate={},
    gStates={turnNumber=1},
    turnOrder={{seatPos=1}},
    playerPlayAreas={[1]="play"},
    playerUnitAreas={[1]="units"},
    gameCards={played={},facedown={},unit={},discarded={}},
    getObjectFromGUID=function(guid) return zones[guid] end,
    selectedResourceByGUID={
        played={effect="block",sideways="move",
            repeatChoices={[1]="attack",[3]="ranged"},
            inventorySets={[2]="influence"}},
        facedown={effect="healing"},
        unit={effect="attack"},
        discarded={effect="siege"}
    }
}
local saveChoices,restoreChoices=loadSection(cards,
    "-- Explicit card choices represent player decisions",
    "function resourceCardsPanelChanged(open)",choiceEnv,
    "return resourceCardsChoicesSave,resourceCardsChoicesRestore")
saveChoices()
local saved=choiceEnv.gStates.resourceCardSelectedChoices
eq(saved.played.effect,"block","main card choice")
eq(saved.played.sideways,"move","sideways card choice")
eq(saved.played.repeatChoices[2].index,3,"sparse repeated effect index")
eq(saved.played.repeatChoices[2].choice,"ranged","repeated effect value")
eq(saved.played.inventorySets[1].index,2,"sparse inventory set index")
eq(saved.discarded,nil,"discarded card choice excluded")
choiceEnv.selectedResourceByGUID={}
restoreChoices()
local restored=choiceEnv.selectedResourceByGUID
eq(restored.played.effect,"block","restore card decision")
eq(restored.played.sideways,"move","restore sideways decision")
eq(restored.played.repeatChoices[3],"ranged","restore sparse repeated choice")
eq(restored.played.inventorySets[2],"influence","restore sparse inventory set")
eq(restored.facedown.effect,"healing","restore saved face choice")
eq(restored.discarded,nil,"discarded card not resurrected")

-- An unresolved combat plan is distinct from the committed damage-phase snapshot.
local damageEnv={
    gStates={turnNumber=1},
    damageSpec={attacks={{key="enemy:1",owner="enemy",damage=3}},units={unitA=true},
        byOwner={},byKey={},reserved={}},
    damageTargets={["enemy:1"]={"unitA","missing","unitA"}},
    damagePending={key="enemy:1",color="Red"},
    damageSignature="old",
    getObjectFromGUID=function(guid) return guid=="unitA" and {guid=guid} or nil end,
    combatCommittedLock=function() return nil end,
    resourceCardsPanelOpen=function() return true end,
    damageUsedBy=function() return nil end,
    DAMAGE_BUTTON_LIMIT=6,
    damageButtonX={},
    damageTargetButtonX=function() return 0 end,
    rebuildDamageButtons=function() end,
    refreshRenderedLines=function() end,
    hasRuntimeWork=function() return false end,
    scheduleRefresh=function() end
}
local damageChunk=section(combat,"function attackAssignmentsDamageSync(spec)",
    "function attackAssignmentsDamageTargetsOf(key)")
setmetatable(damageEnv,{__index=_G})
local saveDamage,restoreDamage,syncDamage=assert(load(damageChunk..
    "\nreturn attackAssignmentsDamageSave,attackAssignmentsDamageRestore,attackAssignmentsDamageSync",
    "damage save/load regression","t",damageEnv))()
saveDamage()
eq(damageEnv.gStates.combatDamageDraft.turn,1,"draft belongs to turn")
eq(#damageEnv.gStates.combatDamageDraft.targets["enemy:1"],3,"save ordered targets")
damageEnv.damageTargets={}
restoreDamage()
eq(#damageEnv.damageTargets["enemy:1"],1,"ignore missing/duplicated Unit GUIDs")
eq(damageEnv.damageTargets["enemy:1"][1],"unitA","retain chosen Unit")
eq(damageEnv.damagePending,nil,"never resume mid-pointer targeting")
syncDamage({attacks={{key="enemy:1",owner="enemy",damage=3}},
    units={unitA=true}})
eq(#damageEnv.damageTargets["enemy:1"],1,"validated allocation survives first combat scan")
syncDamage({attacks={{key="other:1",owner="other",damage=2}},units={unitA=true}})
eq(next(damageEnv.damageTargets),nil,"expired attack allocation discarded")
local committed={turn=1,damage={targets={},attacks={}}}
damageEnv.combatCommittedLock=function() return committed end
saveDamage()
eq(damageEnv.gStates.combatDamageDraft,nil,"committed damage not duplicated")
damageEnv.gStates.combatDamageDraft={turn=1,targets={["enemy:1"]={"unitA"}}}
restoreDamage()
eq(next(damageEnv.damageTargets),nil,"committed damage comes from phase lock")

-- Destroyed TTS userdata may throw even when the Lua reference is non-nil.
local live={isDestroyed=function() return false end,getGUID=function() return "dieLive" end}
local removed={isDestroyed=function() error("invalid TTS reference") end}
local rollerEnv={
    rollerState={roller={dice={live,removed}}},
    getObjectFromGUID=function(guid) return guid=="dieLive" and live or nil end
}
local rollerSave=loadSection(rollers,"function rollerOnSave()",
    "function rollerOnLoad(savedState)",rollerEnv,"return rollerOnSave")
local rollerData=rollerSave()
eq(#rollerData.roller,1,"invalid die skipped without aborting save")
eq(rollerData.roller[1],"dieLive","live die saved")

-- Old games can be missing new optional maps without erasing meaningful false flags.
local loadEnv={gStates={},turnOrder={}}
local normalize=loadSection(events,"local function loadPersistedGameState(saved_data,loaded_data)",
    "function eventsOnLoadRawBase(saved_data, loaded_data)",loadEnv,
    "return loadPersistedGameState")
local old={turnOrder={{seatPos=1}},gStates={positionMageKnight={"Tovak",nil,nil,nil,"Proxy"},
    rampageAmbush=false}}
normalize("saved",old)
eq(loadEnv.gStates.rampageAmbush,false,"explicit false retained")
assert(type(loadEnv.gStates.hexOverideSave)=="table","old terrain override map initialized")
assert(type(loadEnv.gStates.ambushingMonsters)=="table","old ambush map initialized")
assert(type(loadEnv.gStates.pursuingMonsters)=="table","old pursuit map initialized")
local ok=pcall(normalize,"saved",{gStates={},turnOrder={}})
eq(ok,false,"invalid essential configuration rejected")

-- The first real ready-panel startup must restore arrows before asking
-- the tracker to scan. Later ordinary reopen calls must not restore again.
local startupEvents={}
local savedDetailActive="false" -- Loaded XML defaults to closed after a rewind.
local savedSeatEnabled=true
local startupLayoutExpanded=nil
local startupRestoreCount=0
local startupEnv={
    gStates={firstStarted=true,turnNumber=1},
    turnOrder={{seatPos=1}},
    trackerPrivate={trackerStartupRequest=0,restoreAssignmentsPending=false},
    resourceCardsSeatEnabled=function() return savedSeatEnabled end,
    resourceCardsPanelReady=function() return savedDetailActive=="true" end,
    resourceTrackerSyncLayout=function(expanded) startupLayoutExpanded=expanded end,
    resourceTrackerRestoreExpandedLayout=function()
        startupRestoreCount=startupRestoreCount+1
        startupLayoutExpanded=true
        savedDetailActive="true"
    end,
    UI={
        getAttribute=function(id,attribute)
            if id=="ResourceTrackerDetail" and attribute=="active" then return savedDetailActive end
        end,
        setAttribute=function(id,attribute,value)
            if id=="ResourceTrackerDetail" and attribute=="active" then savedDetailActive=value end
        end
    },
    attackAssignmentsRestore=function() startupEvents[#startupEvents+1]="restore" end,
    resourceCardsPanelChanged=function(open)
        startupEvents[#startupEvents+1]=open and "scan" or "close"
    end,
    safeWaitCondition=function(_,callback,condition)
        assert(condition(),"Ready-panel restore should not wait")
        callback()
    end
}
local startup=loadSection(cards,"function resourceCardsOnLoad(restoringSave)",
    "local function resourceCardsRelevantZone(ctx)",startupEnv,
    "return resourceCardsOnLoad")
startup(true)
eq(savedDetailActive,"true","rewind restores the saved expanded panel over closed XML")
eq(startupLayoutExpanded,true,"restored tracker gets expanded height before scan")
eq(startupRestoreCount,1,"saved open tracker uses rewind geometry restore")
eq(startupEvents[1],"restore","saved arrows restore first")
eq(startupEvents[2],"scan","initial scan starts after restore")
startup()
eq(#startupEvents,3,"reopening must not repeat assignment recovery")
eq(startupEvents[3],"scan","reopen still initiates scan")
eq(startupRestoreCount,1,"ordinary reopen leaves existing layout alone")

-- A seat whose tracker was explicitly minimized at the checkpoint must
-- stay minimized rather than being reopened by the saved-game startup.
savedSeatEnabled=false
savedDetailActive="true"
startup(true)
eq(savedDetailActive,"false","saved minimized tracker stays closed on rewind")
eq(startupLayoutExpanded,false,"closed tracker gets collapsed height")
eq(startupEvents[4],"close","saved minimized tracker does not start a scan")
eq(startupRestoreCount,1,"saved minimized tracker must not be expanded")

-- Previously persisted cleanup checkpoints must resume without replaying
-- already-processed physical objects or inventing a new cleanup sequence.
local combatSource=read("src/PlayingGame/Combat.lua")
local cleanupCount=0
local cleanupEnv={
    gStates={preEndTurn=true,combatPreEndTurnRecovery={
        player=1,processedObjects={cardA=true},rewardBoundaryDone=true}},
    turnOrder={{seatPos=1}},
    Player={Red={color="Red"}},
    positionToColor=function(_index) return "Red" end,
    combatPreEndTurnPreparePlayArea=function(_,recovery)
        eq(recovery.processedObjects.cardA,true,"recovered cleanup ledger")
        return nil,{}
    end,
    combatSchedulePreEndTurnCleanup=function(...)
        cleanupCount=cleanupCount+1
    end
}
local recover=loadSection(combatSource,"function combatRecoverPreEndTurn()",
    "function __preEndTurn_raw(player, mouseButton, id, rewindReady)",cleanupEnv,
    "return combatRecoverPreEndTurn")
eq(recover(),true,"interrupted cleanup resumes")
eq(cleanupCount,1,"only one cleanup resume scheduled")
cleanupEnv.gStates.combatPreEndTurnRecovery=nil
eq(recover(),false,"no phantom second cleanup")

-- A saved pre-End-Turn reward without its commit marker is applied once;
-- an already committed reward takes the non-duplicating reconciliation path.
local fameSource=read("src/PlayingGame/FameReputation.lua")
local commits,reconciles=0,0
local fameEnv={
    gStates={preEndTurn=true,turnNumber=1},
    turnOrder={{fameGain=3,repGain=0}},
    eventsOnLoadRawBase=function(...) return true end,
    safeWaitFrames=function(_,callback,_frames) callback() end,
    applyPlayerFameReputation=function(_index)
        commits=commits+1
    end,
    syncPostCommitAdjustments=function(_index)
        reconciles=reconciles+1
    end
}
setmetatable(fameEnv,{__index=_G})
local fameStart=assert(fameSource:find(
    "function fameReputationOnLoadRaw(saved_data, loaded_data)",1,true))
local restoreFame=assert(load(fameSource:sub(fameStart)..
    "\nreturn fameReputationOnLoadRaw","fame load recovery","t",fameEnv))()
restoreFame("",nil)
eq(commits,1,"missing commit marker recovered")
fameEnv.gStates.fameRepCommitted={[1]={fame=3,rep=0}}
restoreFame("",nil)
eq(commits,1,"committed fame not applied twice")
eq(reconciles,1,"committed fame routed to adjustment reconciliation")
assert(events:find("gStates.endRoundResetPending==true",1,true)
    and callbacks:find("coralDrawChoiceRestoreState(",1,true),
    "end-of-round and pending Coral draw recovery must remain installed")

-- Startup must reconstruct decisions once, before the first tracker calculation.
assert(events:find("resourceCardsChoicesRestore()",1,true)
    and events:find("attackAssignmentsDamageRestore()",1,true),
    "decision restoration missing from Global load")
assert(events:find("resourceCardsOnLoad(true)",1,true),
    "load must request saved combat-arrow restoration")
assert(not callbacks:find("attackAssignmentsRestore()",1,true)
    and not callbacks:find("resourceCardsPanelChanged(true)",1,true),
    "duplicate callback startup path remains")
local start=assert(cards:find("function resourceCardsOnLoad(restoringSave)",1,true))
local restoredLines=assert(cards:find("attackAssignmentsRestore()",start,true))
local startedScan=assert(cards:find("resourceCardsPanelChanged(true)",start,true))
assert(restoredLines<startedScan,"combat assignments must restore before tracker scan")
assert(events:find("math.abs(pos[3]+33.29)>0.005",1,true)
    and events:find("math.abs(pos[2]-1.09)>0.005",1,true),
    "load should not reposition already-correct Unit/Wound objects")
assert(events:find("resourceCardsChoicesSave()",1,true)
    and events:find("attackAssignmentsDamageSave()",1,true),
    "onSave must capture player decisions")

print("Save/load lifecycle regressions passed")
