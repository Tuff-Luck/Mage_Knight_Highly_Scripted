-- Regression: missing turn-order tokens yield actionable non-fatal reports.
-- Run from repo root: lua5.2 tools/test-automatic-turn-order-diagnostics.lua
local file=assert(io.open("src/PlayingGame/Turn.lua","r"))
local source=file:read("*a")
file:close()
local start=assert(source:find("local function turnOrderTokenMissingSnapshot(",1,true))
local finish=assert(source:find("\n--Tactic Showing and Hiding",start,true))
local implementation=source:sub(start,finish-1)
    .."\nreturn turnOrderTokenMissingSnapshot, reportTurnOrderTokenMissing"

local token={guid="real123",type="Custom_Token",resting=true,
    getPosition=function() return {x=-2,y=1,z=-20} end}
local candidate={guid="other99",type="Custom_Token",
    getPosition=function() return {x=-2,y=1,z=-21} end}
local objects={real123=token}
objects["turn-zone"]={getObjects=function() return {token,candidate} end}
local reports,delayed,logs={},{},{}
local env={
    gStates={gameScenario="First Conquest",currentRound=1,turnNumber=2,realTurn=2,
        tacticShown=true,firstStarted=true,playerCount=2,coop=0},
    turnOrder={
        {seatPos=2,mage="Goldyx",tactic=1,turnOrderTokenGUID="real123"},
        {seatPos=5,mage="Dummy",tactic=2,turnOrderTokenGUID="missing456"}
    },
    turnOrderArea="turn-zone",
    getObjectFromGUID=function(guid) return objects[guid] end,
    safeWaitFrames=function(scope,fn,frames)
        assert(scope=="Turn" and frames==2,"Expected delayed lookup check")
        delayed[#delayed+1]=fn
    end,
    reportAutomaticLuaDiagnostic=function(name,summary,context)
        reports[#reports+1]={name=name,summary=summary,context=context}
    end,
    log=function(message) logs[#logs+1]=message end
}
setmetatable(env,{__index=_G})
local snapshot,reportMissing=assert(load(implementation,
    "Turn-order diagnostic","t",env))()
local initial=snapshot(2,"missing456")
assert(initial:find("index=2 expected GUID=missing456",1,true))
assert(initial:find("Scenario=First Conquest round=1 turn=2",1,true))
assert(initial:find("seat=5 mage=Dummy tactic=2 guid=missing456 NOT FOUND",1,true))
assert(initial:find("guid=real123 FOUND",1,true))
assert(initial:find("Zone object: other99",1,true))

reportMissing(2,"missing456")
assert(#reports==0 and #delayed==1,"Diagnostic should check before posting")
assert(#logs==1,"Initial disappearance should be logged immediately")
delayed[1]()
assert(#reports==1,"A persistent missing token must create a report")
assert(reports[1].name=="tacticToggle.turnOrderSort")
assert(reports[1].summary:find("missing456",1,true))
assert(reports[1].context:find("After 2 frames: STILL MISSING",1,true))

-- Recovering GUIDs are still reported: this distinguishes a transient lookup
-- from a deleted token without silently masking either problem.
objects.missing456={guid="missing456",type="Custom_Token",
    getPosition=function() return {x=-2,y=1,z=-22} end}
reportMissing(2,"missing456")
assert(#delayed==2)
delayed[2]()
assert(#reports==2)
assert(reports[2].context:find("After 2 frames: REAPPEARED",1,true))
assert(env.turnOrder[2].turnOrderTokenGUID=="missing456",
    "Diagnostics must not rewrite turn-order references")
local eventFile=assert(io.open("src/PlayingGame/Events.lua","r"))
local eventSource=eventFile:read("*a")
eventFile:close()
assert(eventSource:find("if not guidOK or type(destroyedGuid)~=\"string\" or destroyedGuid==\"\" then return end\n\tprotectedDestroyEvidence.observe()",1,true),
    "Valid onObjectDestroy callbacks must update the rolling destruction counter")
-- Starting turn-order tokens must rest at the table height rather than
-- hover above it. The dummy token must remain movable like human tokens.
local setupFile=assert(io.open("src/SetupGame/Players.lua","r"))
local setupSource=setupFile:read("*a")
setupFile:close()
assert(not setupSource:find("params.position={-1.9, 1.2",1,true),
    "Starting turn-order tokens must not spawn at the old floating height")
assert(setupSource:find("params.position={-1.9, 0.97, -19.4}",1,true),
    "Dummy-first turn-order token must rest at table height")
assert(setupSource:find("params.position={-1.9, 0.97, -19.4-(gStates.playerCount*1.4)}",1,true),
    "Dummy-last turn-order token must rest at table height")
assert(setupSource:find("params.position={-1.9, 0.97, -19.4-((turnRef-1)*1.4)}",1,true),
    "Human turn-order tokens must rest at table height")
assert(not setupSource:find("(i==1 or i==3 or i==4 or i==5 or i==11)",1,true),
    "Do not lock the dummy's turn-order token")
assert(setupSource:find("(i==3 or i==4 or i==5 or i==11)",1,true),
    "Retain locks on the dummy's other board components")
assert(setupSource:find("protectedTurnOrderTokenSetup(obj,playerBag,params.position)",1,true))

-- Capture the actual setup/container breadcrumb logic rather than a fabricated report.
local traceStart=assert(eventSource:find(
    "local protectedTurnOrderTokenTrail={}",1,true))
local traceFinish=assert(eventSource:find(
    "\n-- The game intentionally moves certain protected pieces",traceStart,true))
local traceImplementation=eventSource:sub(traceStart,traceFinish-1)
    .."\nreturn protectedTurnOrderTokenRecord, protectedTurnOrderTokenTrail, protectedTurnOrderTokenSetup"
local traceEnv={protectedObjectKind=function() return "Round Order token",true end}
setmetatable(traceEnv,{__index=_G})
local trackToken,tokenHistory,setupToken=assert(load(traceImplementation,
    "Turn token lifecycle trail","t",traceEnv))()
local missingToken={guid="missing456",type="Custom_Token",resting=false,
    getPosition=function() return {x=-1.9,y=1.2,z=-20.8} end}
setupToken(missingToken,{guid="mage-bag"},{-1.9,1.2,-20.8})
trackToken("missing456","Entered container=trash",missingToken)
assert(#tokenHistory.missing456==2)
assert(tokenHistory.missing456[1]:find("cloned bag=mage-bag",1,true))
assert(tokenHistory.missing456[2]:find("Entered container=trash",1,true))
-- TTS can remove the anchors in different orders when exiting. Never infer
-- shutdown from a single missing anchor (which could be an in-game fault).
local exitStart=assert(eventSource:find("local gameExitTeardown=false",1,true))
local exitFinish=assert(eventSource:find(
    "\n-- Keep a short, token-specific lifecycle trail",exitStart,true))
local exitImplementation=eventSource:sub(exitStart,exitFinish-1)
    .."\nreturn eventsExitTeardown"
local anchorPresent={["map-zone"]=true,["519f96"]=true,["turn-zone"]=true}
local stops=0
local exitEnv={
    mapArea="map-zone",turnOrderArea="turn-zone",
    getObjectFromGUID=function(guid) return anchorPresent[guid] and {} or nil end,
    Wait={stopAll=function() stops=stops+1 end}
}
setmetatable(exitEnv,{__index=_G})
local detectExit=assert(load(exitImplementation,"Exit detector","t",exitEnv))()
assert(detectExit()==false)
anchorPresent["519f96"]=false
assert(detectExit()==false and stops==0,"One absent anchor is not shutdown")
anchorPresent["turn-zone"]=false
assert(detectExit()==true and stops==1,
    "Two missing anchors should confirm teardown even with map zone present")
assert(detectExit()==true and stops==1,"Teardown cancellation should run once")

-- The existing deletion-protection audit must also report an actual destroy
-- callback, so the later tactic check can be distinguished from the original event.
local eventStart=assert(eventSource:find(
    "local protectedDestroyAuditPending={}",1,true))
local eventFinish=assert(eventSource:find(
    "\nfunction __tryObjectEnterContainer_raw",eventStart,true))
local eventImplementation=eventSource:sub(eventStart,eventFinish-1)
    .."\nreturn protectedObjectDestroyAudit, protectedDestroyEvidence.observe"
local destroyPending={}
local inTeardown=false
local fakeTime=1700000000.25
objects["map-zone"]={}
objects["519f96"]={}
local destroyEnv={
    eventsExitTeardown=function() return inTeardown end,
    mapArea="map-zone",
    turnOrderArea="turn-zone",
    os={time=function() return fakeTime end,date=os.date},
    gStates={firstStarted=true,gameScenario="First Conquest",
        currentRound=1,turnNumber=2},
    turnOrder=env.turnOrder,
    protectedExpectedScriptRemovals={},
    protectedUnexpectedDestroyReported={},
    protectedTurnOrderTokenTrail=tokenHistory,
    protectedObjectKind=function() return "Round Order token",true end,
    getObjectFromGUID=function(guid) return objects[guid] end,
    safeWaitFrames=function(scope,fn,frames)
        assert(scope=="ProtectedObjects" and frames==120)
        destroyPending[#destroyPending+1]=fn
    end,
    reportAutomaticLuaDiagnostic=env.reportAutomaticLuaDiagnostic,
    log=env.log
}
setmetatable(destroyEnv,{__index=_G})
local destroyAudit,recordDestroy=assert(load(eventImplementation,
    "Protected object audit","t",destroyEnv))()
objects.missing456=nil
recordDestroy()
destroyAudit("missing456")
destroyAudit("missing456")
assert(#destroyPending==1 and #reports==2,
    "Destroy audit should be deferred and pending reports deduplicated")
-- Three unrelated destruction callbacks follow the token, and another token
-- disappears while the map and table surface are still present.
fakeTime=fakeTime+3.25
recordDestroy()
recordDestroy()
recordDestroy()
objects.real123=nil
objects["turn-zone"]=nil
destroyPending[1]()
assert(#reports==3,"Missing protected token should be reported")
assert(reports[3].name=="protectedObjectDestroyAudit")
assert(reports[3].context:find("seat=5 mage=Dummy",1,true))
assert(reports[3].context:find("Lookup after 120 frames: NOT FOUND",1,true))
assert(reports[3].context:find("Entered container=trash",1,true),
    "Destroy report must retain the last recorded container destination")
assert(reports[3].context:find("Token destroyed (UTC): "..
    os.date("!%Y-%m-%d %H:%M:%S UTC",math.floor(fakeTime-3.25)),1,true))
assert(reports[3].context:find("Elapsed since destroy callback: 3s",1,true))
assert(reports[3].context:find("Destruction callbacks last 15s at destroy: 1",1,true))
assert(reports[3].context:find("Destruction callbacks since token destroy: 3",1,true))
assert(reports[3].context:find("Destruction callbacks last 15s at verification: 4",1,true))
assert(reports[3].context:find("Shutdown anchors at destroy: map zone=FOUND, table surface=FOUND, turn-order zone=FOUND",1,true))
assert(reports[3].context:find("Shutdown anchors at verification: map zone=FOUND, table surface=FOUND, turn-order zone=MISSING",1,true))
assert(reports[3].context:find("Other turn-order tokens at destroy: found=1 missing/unavailable=0 [1:real123=FOUND]",1,true))
assert(reports[3].context:find("Other turn-order tokens at verification: found=0 missing/unavailable=1 [1:real123=MISSING]",1,true))

-- Restored or explicitly permitted objects must not generate a false alarm.
destroyAudit("returned123")
objects.returned123=token
destroyPending[2]()
assert(#reports==3,"Restored object incorrectly reported as destroyed")
destroyEnv.protectedExpectedScriptRemovals.allowed123={destination="trash"}
destroyAudit("allowed123")
assert(#destroyPending==2,"Expected removal should not schedule an audit")

-- A destroy event observed while playing can become normal teardown before
-- the grace expires; it must not submit the false-positive remote report.
destroyAudit("shutdown789")
assert(#destroyPending==3 and #reports==3)
inTeardown=true
destroyPending[3]()
assert(#reports==3,"Shutdown should suppress pending destroy reports")
inTeardown=false
-- The one-second rolling buckets expire without collecting unbounded history.
fakeTime=fakeTime+16
recordDestroy()
destroyAudit("genuine789")
assert(#destroyPending==4,"Normal gameplay must still audit later token losses")
destroyPending[4]()
assert(#reports==4 and reports[4].summary:find("genuine789",1,true),
    "A genuine in-game token loss must still be reported")
assert(reports[4].context:find("Destruction callbacks last 15s at destroy: 1",1,true),
    "Old destroy bursts must expire after the 15-second rolling window")

print("Automatic turn-order token diagnostics passed")
