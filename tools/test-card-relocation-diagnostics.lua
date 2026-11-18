-- Verify diagnostic breadcrumbs reveal whether a relocated card lost its
-- choice, calculator target, or persistent arrow, without console spam for
-- moves that preserve all three values.
-- Run from repository root: lua5.2 tools/test-card-relocation-diagnostics.lua
local function read(path)
    local f=assert(io.open(path,"r"))
    local data=f:read("*a")
    f:close()
    return data
end
local source=read("src/PlayingGame/PlayerBoard/CardRecognition.lua")
local a=assert(source:find("trackerPrivate.relocationDiagnostics={}",1,true))
local b=assert(source:find("local function scheduleChoiceResetAfterPlay(guid,seatPos)",a,true))
local traceSection=source:sub(a,b-1)
local card={guid="rage",resting=true,held_by_color=nil,
    isSmoothMoving=function() return false end,
    getPosition=function() return {x=0,y=2,z=0} end}
local zone={getObjects=function() return {card} end}
local selected={rage={effect="attack"}}
local combat={targets={rage="left"}}
local arrows={left=true}
local logs={}
local state={cardOverPlayMat=function() return true end}
local env={
    trackerPrivate=state,
    selectedResourceByGUID=selected,
    combatAssignmentState=combat,
    playerPlayAreas={[1]="play"},
    attackAssignmentsTargetGUIDs=function() return arrows end,
    getObjectFromGUID=function(guid)
        return guid=="rage" and card or guid=="play" and zone or nil
    end,
    log=function(value) logs[#logs+1]=value end
}
setmetatable(env,{__index=_G})
assert(load(traceSection,"Relocation trace","t",env))()
state.relocationDiagnostics.rage={seat=1,option="attack",target="left",
    arrow="left",events={}}
state.tracePlayCard("rage","pickup")
state.tracePlayCard("rage","stable-drop")
assert(#logs==0,"Successful relocations must not produce diagnostics")
selected.rage=nil
state.tracePlayCard("rage","choice-reset")
assert(#logs>=3 and logs[1]:find("UNEXPECTED",1,true),
    "A lost card choice must emit one diagnostic sequence")
assert(logs[#logs]:find("choice-reset",1,true),
    "Trace must attribute the change to the callback that observed it")
local count=#logs
combat.targets.rage="right"
arrows={right=true}
state.tracePlayCard("rage","target-changed")
assert(#logs==count,"One relocation must only report its first divergence once")
print("Card relocation event diagnostics regressions passed")
