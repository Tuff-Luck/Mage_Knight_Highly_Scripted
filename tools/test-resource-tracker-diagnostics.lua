-- Exercise the production coordinator wiring and its extracted diagnostics.
-- Run from repository root: lua5.2 tools/test-resource-tracker-diagnostics.lua
local file=assert(io.open("src/PlayingGame/PlayerBoard/CardRecognition.lua","r"))
local source=file:read("*a")
file:close()
local finish=assert(source:find("local shown={}",1,true))
package.path="src/?.lua;"..package.path

local messages,broadcasts={},{}
log=function(message) messages[#messages+1]=message end
broadcastToColor=function(message,color,tint)
    broadcasts[#broadcasts+1]={message=message,color=color,tint=tint}
end
resourceCardsPanelOpen=function() return true end
gStates={turnNumber=1}
turnOrder={{seatPos=2}}
local live={held_by_color="Blue",isSmoothMoving=function() return true end}
getObjectFromGUID=function(guid)
    if guid=="bbbbbb" then return live end
end

-- Load the real module initialization and public callback, not a duplicate
-- of the diagnostic implementation. Inspect the shared runtime table.
local private=assert(load(source:sub(1,finish-1).."\nreturn trackerPrivate",
    "Tracker diagnostics wiring"))()
local command=resourceCardsTraceCommand
assert(type(command)=="function")
assert(private.traceEnabled==false and #private.traceLines==0)
private.traceEvent("ignored",2,"bbbbbb")
assert(private.traceSequence==0 and #private.traceLines==0)
assert(command("invalid","Blue")==false and #messages==0)

-- Queue/status values are read live, including replacements of runtime tables.
private.pendingSeatRender={[2]=true}
private.pendingSeatSettles={[2]={aaa=true,bbb=true}}
private.playCardMovements={
    bbbbbb={seatPos=2,releasing=true,samples=3},
    aaaaaa={seatPos=2,releasing=false,samples=1}
}
assert(command(nil,"Blue"))
local status=messages[#messages]
assert(status:find("Tracker trace OFF; panel=true; seat=2; renderQueued=true; settleWaits=2",1,true))
local first=assert(status:find("aaaaaa(seat=2,held=nil,smooth=false,watch=false,samples=1)",1,true))
local second=assert(status:find("bbbbbb(seat=2,held=Blue,smooth=true,watch=true,samples=3)",1,true))
assert(first<second and broadcasts[1].color=="Blue")
assert(broadcasts[1].message==status:sub(#"[TrackerTrace] "+1))

assert(command("on"))
assert(private.traceEnabled and private.traceSequence==1)
assert(private.traceLines[1]=="0001 trace.enabled seat=- guid=- ")
for index=1,185 do private.traceEvent("sample",2,"bbbbbb",tostring(index)) end
assert(#private.traceLines==180 and private.traceSequence==186)
assert(private.traceLines[1]=="0007 sample seat=2 guid=bbbbbb 6")
assert(private.traceLines[180]=="0186 sample seat=2 guid=bbbbbb 185")

local before=#messages
assert(command("dump"))
assert(messages[before+1]=="[TrackerTrace] BEGIN 180 events")
assert(messages[before+2]=="[TrackerTrace] "..private.traceLines[1])
assert(messages[before+182]=="[TrackerTrace] END")
assert(command("off"))
assert(not private.traceEnabled and private.traceSequence==187)
assert(private.traceLines[180]=="0187 trace.disabled seat=- guid=- ")
private.traceEvent("ignored")
assert(private.traceSequence==187 and #private.traceLines==180)

private.pendingSeatSettles={}
private.pendingSeatRender={}
private.playCardMovements={}
assert(command("on"))
assert(private.traceSequence==1 and #private.traceLines==1)
assert(messages[#messages]:find("settleWaits=0; movements=none; events=1",1,true))
local tick=10
private.profileClock=function() return tick end
local started=private.profileStart()
tick=tick+0.005
private.profileFinish("combat.refresh",started)
started=private.profileStart()
tick=tick+0.010
private.profileFinish("combat.refresh",started)
private.profileCount("block.hit")
assert(private.profileStats["combat.refresh"].count==2)
assert(math.abs(private.profileStats["combat.refresh"].ms-15)<0.001)
assert(math.abs(private.profileStats["combat.refresh"].maxMs-10)<0.001)
assert(private.profileStats["block.hit"].count==1)
assert(command("status"))
assert(messages[#messages]:find("combat.refresh count=2 total=15.00ms avg=7.50ms max=10.00ms",1,true))
-- Exclusive stages share the exact boundary and do not double-count.
local clockReads=0
private.profileClock=function()
    clockReads=clockReads+1
    return tick
end
local boundary=private.profileStart()
tick=tick+0.004
boundary=private.profileCheckpoint("rows.grouping",boundary)
tick=tick+0.006
boundary=private.profileCheckpoint("rows.allocation",boundary)
tick=tick+0.002
private.profileFinish("rows.finalLayout",boundary)
assert(clockReads==4,"One clock sample per stage boundary")
assert(math.abs(private.profileStats["rows.grouping"].ms-4)<0.001)
assert(math.abs(private.profileStats["rows.allocation"].ms-6)<0.001)
assert(math.abs(private.profileStats["rows.finalLayout"].ms-2)<0.001)
assert(math.abs(private.profileStats["rows.grouping"].ms
    +private.profileStats["rows.allocation"].ms
    +private.profileStats["rows.finalLayout"].ms-12)<0.001)
local rowStart=assert(source:find("local function combatAssignmentRefreshRows(entries,sources)",1,true))
local rowEnd=assert(source:find("local function combatCalcShutdown()",rowStart,true))
local rowSource=source:sub(rowStart,rowEnd-1)
local last=1
for _,name in ipairs({"grouping","enemyHeaders","allocation","earlyCombat","damage",
    "lateAttack","bossUpdates","rewards","defeatMarks","resourceDisplay",
    "resultRenderer","columnLayout","woundSummary"}) do
    local pos=assert(rowSource:find('profileCheckpoint("rows.'..name..'",stageProfile)',last,true),
        "Missing ordered combat profiling stage "..name)
    last=pos+1
end
assert(rowSource:find('profileFinish("rows.finalLayout",stageProfile)',last,true))
local scanStart=assert(source:find("local function renderSeat(seatPos)",1,true))
local scanEnd=assert(source:find("local function scheduleSeatRender",scanStart,true))
local scanSource=source:sub(scanStart,scanEnd-1)
last=1
for _,name in ipairs({"observation","unitPreparation","payments","passiveTerrain","playedCards",
    "cardInteractions","units","skills","finalization"}) do
    local pos=assert(scanSource:find('profileCheckpoint("scan.'..name..'",scanStage)',last,true),
        "Missing ordered tracker scan stage "..name)
    last=pos+1
end
assert(scanSource:find('profileFinish("scan.publication",scanStage)',last,true))
local function moduleSource(path)
    local file=assert(io.open("src/PlayingGame/PlayerBoard/ResourceTracker/"..path,"r"))
    local code=file:read("*a") file:close()
    return code
end
local publication=moduleSource("Scanning/ScanPublication.lua")
local previousBoundary=1
for _,name in ipairs({"conversions","fameRep","reputation","trackerText","moveDisplay"}) do
    local position=assert(publication:find('profileCheckpoint("resources.'..name..'",resourceProfile)',previousBoundary,true))
    previousBoundary=position+1
end
assert(publication:find('profileFinish("publish.resources",profile,finished)',previousBoundary,true))
local played=moduleSource("Cards/PlayedCardScan.lua")
previousBoundary=1
for _,name in ipairs({"recognition","choiceButtons","effects"}) do
    local position=assert(played:find('profileCheckpoint("cards.'..name..'",cardProfile)',previousBoundary,true))
    previousBoundary=position+1
end
assert(played:find('profileFinish("cards.highlight",cardProfile)',previousBoundary,true))
-- Actual UI calls contribute once to the total and once to their column.
private.profileClock=function() return tick end
local uiStart=private.profileStart()
tick=tick+0.003
private.profileUIWrite("CombatSourceSlot1block12Amount",uiStart)
assert(private.profileStats["ui.setAttribute"].count==1)
assert(math.abs(private.profileStats["ui.setAttribute"].ms-3)<0.001)
assert(math.abs(private.profileStats["ui.write.block"].ms-3)<0.001)
uiStart=private.profileStart()
tick=tick+0.002
private.profileUIWrite("CombatEnemyRow1Result",uiStart)
assert(private.profileStats["ui.write.Result"].count==1)
assert(math.abs(private.profileStats["ui.setAttribute"].ms-5)<0.001)
-- Sampled heap deltas can suggest collection but do not force it.
local heap=100
private.profileHeap=function() return heap end
local scan=private.profileScanStart()
heap=120 tick=tick+0.010
private.profileScanFinish(scan)
scan=private.profileScanStart()
heap=90 tick=tick+0.030
private.profileScanFinish(scan)
local mem=private.profileMemory
assert(mem.count==2 and mem.firstKB==100 and mem.lastKB==90)
assert(mem.minKB==90 and mem.maxKB==120 and mem.totalDelta==-10)
assert(mem.drops==1 and mem.dropKB==30 and mem.slowestDelta==-30)
assert(math.abs(mem.slowestMs-30)<0.001)
assert(command("status"))
assert(messages[#messages]:find("heap.recent",1,true))
private.profileHeap=function() return nil end
private.profileScanFinish(private.profileScanStart())
assert(private.profileMemory.unavailable and private.profileMemory.count==2)
assert(private.profileStats["tracker.scan"].count==3)
private.profileClock=function() return nil end
local untimed=private.profileCheckpoint("rows.untimed",private.profileStart())
assert(untimed==false and private.profileStats["rows.untimed"].count==1
    and private.profileStats["rows.untimed"].timed==0)
private.profileFinish("clock.unavailable",private.profileStart())
assert(private.profileStats["clock.unavailable"].count==1 and private.profileStats["clock.unavailable"].timed==0)
assert(command("off"))
private.profileClock=function() error("Disabled profiler must not sample the clock") end
assert(private.profileCheckpoint("rows.disabled",private.profileStart())==nil)
assert(private.profileStats["rows.disabled"]==nil)
private.profileHeap=function() error("Disabled profiler must not sample memory") end
assert(private.profileScanStart()==nil)
private.profileScanFinish(nil)
private.profileCount("block.hit")
assert(private.profileStats["block.hit"].count==1,"Disabled trace has no profiling side effects")
assert(command("on"))
assert(next(private.profileStats)==nil,"Starting trace resets profiling counters")
assert(next(private.profileMemory)==nil,"Starting trace resets memory samples")
assert(gStates.traceLines==nil and gStates.traceEnabled==nil,
    "Diagnostics must remain runtime-only")
print("Resource Tracker diagnostics wiring, commands and bounded buffer passed")
