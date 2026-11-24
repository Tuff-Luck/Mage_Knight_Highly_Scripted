-- A relocated card's unchanged choices must not trigger another full
-- object UI write. Late TTS clears must be repaired without touching its
-- resource choice or combat target. Run with lua5.2 from the repository root.
local function read(path)
    local f=assert(io.open(path,"r"))
    local contents=f:read("*a")
    f:close()
    return contents
end
local function slice(source,first,last)
    local a=assert(source:find(first,1,true),"Missing "..first)
    local b=assert(source:find(last,a+#first,true),"Missing "..last)
    return source:sub(a,b-1)
end
local function eq(value,expected,message)
    assert(value==expected,(message or "Mismatch")..": "..tostring(value)..
        " (expected "..tostring(expected)..")")
end
local cardSource=read("src/PlayingGame/PlayerBoard/CardRecognition.lua")
local uiAssets=read("src/PlayingGame/UIAssets.lua")
assert(uiAssets:find("function resourceObjectUiSameXML(left,right)",1,true),
    "XML helper must prevent unchanged card UI writes")
assert(read("src/PlayingGame/PlayerBoard/ResourceTracker/CardControls.lua"):find("if assets~=nil or not resourceObjectUiSameXML(previousXml,xml) then",
    1,true),"Unchanged card XML must be kept in place")
assert(read("src/PlayingGame/PlayerBoard/ResourceTracker/ObjectEvents.lua"):find('trackerPrivate.checkCardChoicesAfterDrop(obj.guid,seat)',
    1,true),"Known drops must schedule a missing-option recheck")

-- Exercise the exact delayed verifier, independently of full seat scanning.
local verifierCode=slice(cardSource,
    "-- A late TTS object-UI refresh can clear option buttons AFTER the settled",
    "function resourceCardsObjectMoved(obj,stabilized)")
local expected={["ResourceCardChoice_rage_attack"]=true}
local frames={}
local scans=0
local session=1
local open=true
local onMat=true
local inTransit=false
local card={guid="rage",UI={},isDestroyed=function() return false end}
local tracker={
    trackerSession=session,cardButtonIds={},
    traceEnabled=false
}
tracker.cardButtonIds=nil
local combatConfig={
    cardButtonIds={rage={"ResourceCardChoice_rage_attack"}},
    cardInTransit=function() return inTransit end,
    cardChoicesPresent=function()
        return expected["ResourceCardChoice_rage_attack"]==true
    end
}
local shown={rage="N:attack"}
local env={
    trackerPrivate=tracker,combatConfig=combatConfig,choiceButtonShown=shown,
    resourceCardsPanelOpen=function() return open end,
    cardInSeatPlayArea=function() return onMat end,
    getObjectFromGUID=function() return card end,
    queueSeat=function()
        scans=scans+1
        expected["ResourceCardChoice_rage_attack"]=true
    end,
    safeWaitFrames=function(_,callback,delay)
        frames[#frames+1]={callback=callback,delay=delay}
    end
}
setmetatable(env,{__index=_G})
env.trackerPrivate=env.trackerPrivate or {}
env.trackerPrivate.objectEvents=assert(loadfile("src/PlayingGame/PlayerBoard/ResourceTracker/ObjectEvents.lua","t",env))()
assert(load(verifierCode,"Drop option verifier","t",env))()
local function runFrame()
    assert(#frames>0,"Expected a scheduled frame callback")
    local entry=table.remove(frames,1)
    entry.callback()
    return entry.delay
end

env.trackerPrivate.checkCardChoicesAfterDrop("rage",1)
eq(#frames,1,"First check scheduled")
eq(runFrame(),5,"First check is shortly after drop")
eq(scans,0,"Intact UI does not redraw")
eq(runFrame(),12,"Second check catches a late UI owner write")
eq(scans,0,"Intact UI still never redraws")
eq(#frames,0,"Checks stop after the second pass")

env.trackerPrivate.checkCardChoicesAfterDrop("rage",1)
expected["ResourceCardChoice_rage_attack"]=nil
runFrame()
eq(scans,1,"Missing button triggers targeted rescan")
runFrame()
eq(scans,1,"Repaired button is not redrawn a second time")

env.trackerPrivate.checkCardChoicesAfterDrop("rage",1)
runFrame()
expected["ResourceCardChoice_rage_attack"]=nil
runFrame()
eq(scans,2,"Late TTS clear is repaired by second check")

-- Once a card genuinely leaves play, the same stale watcher must not bring
-- its old UI back or change its saved combat assignment.
env.trackerPrivate.checkCardChoicesAfterDrop("rage",1)
onMat=false
expected["ResourceCardChoice_rage_attack"]=nil
runFrame()
eq(scans,2,"No repair outside the play mat")
eq(#frames,0,"Departure stops remaining watchers")
onMat=true

-- An intentional 'hidden' choice, a tracker minimisation or another pickup
-- also cancels the repair without modifying choices.
shown.rage="hidden"
env.trackerPrivate.checkCardChoicesAfterDrop("rage",1)
runFrame()
runFrame()
eq(scans,2,"Intentional hidden UI must stay hidden")
shown.rage="N:attack"
env.trackerPrivate.checkCardChoicesAfterDrop("rage",1)
open=false
runFrame()
eq(scans,2,"Closed tracker must not restore card controls")
open=true

env.trackerPrivate.checkCardChoicesAfterDrop("rage",1)
env.trackerPrivate.checkCardChoicesAfterDrop("rage",1)
local oldest=table.remove(frames,1)
oldest.callback()
eq(scans,2,"Older pickup/drop's watcher is invalidated")
runFrame()
runFrame()
eq(scans,3,"Newest relocation watcher repairs the lost button")

print("Card UI drop stability and late repair regressions passed")
