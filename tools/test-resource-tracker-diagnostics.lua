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
assert(gStates.traceLines==nil and gStates.traceEnabled==nil,
    "Diagnostics must remain runtime-only")
print("Resource Tracker diagnostics wiring, commands and bounded buffer passed")
