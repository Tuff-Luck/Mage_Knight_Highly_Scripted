-- A second scan must not replace a locked combat arrow with the
-- card's new nearest enemy during repositioning.
-- Run from repository root: lua5.2 tools/test-combat-target-arrow-authority.lua
local function read(path)
    local f=assert(io.open(path,"r"))
    local text=f:read("*a")
    f:close()
    return text
end
local reader=read("src/PlayingGame/PlayerBoard/CardRecognition.lua")
local first=assert(reader:find("        -- The physical assignment arrow is the persistent target lock.",1,true))
local last=assert(reader:find("        local targetIndex=targetGUID~=nil",first+1,true))
local snippet=reader:sub(first,last-1)

local state={targets={rage="right"},explicit={rage=false}}
local arrows={rage={left=true}}
local env={
    combatAssignmentState=state,
    attackAssignmentsTargetGUIDs=function(key) return arrows[key] or {} end
}
setmetatable(env,{__index=_G})
local target=assert(load("return function(source,rowByGUID)\n"
    ..snippet.."\nreturn targetGUID\nend",
    "Persistent combat arrow priority","t",env))()
local source={key="rage"}
local rows={left=1,right=2}

assert(target(source,rows)=="left" and state.targets.rage=="left",
    "Late enter-zone scan must respect the existing left-target arrow")
-- A deliberate retarget modifies the persistent arrow; its target becomes
-- authoritative even if the calculator retained its preceding target.
arrows.rage={right=true}
assert(target(source,rows)=="right" and state.targets.rage=="right",
    "Manual retarget via the arrow must update the calculator")
-- A source that has multiple independent arrows is not arbitrarily reduced
-- to one; the calculator's existing primary target remains unchanged.
arrows.rage={left=true,right=true}
state.targets.rage="left"
assert(target(source,rows)=="left" and state.targets.rage=="left",
    "Split sources must retain their existing primary target")
-- A fresh played card with no existing arrow is free to be assigned normally.
arrows.rage={}
state.targets.rage=nil
assert(target(source,rows)==nil and state.targets.rage==nil,
    "A new card with no lock must still use the usual targeting fallback")
print("Combat target arrow authority regressions passed")
