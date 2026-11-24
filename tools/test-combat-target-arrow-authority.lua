-- A settled card's explicit calculator target takes precedence over a
-- leftover arrow. If no target is recorded, recover the persisted arrow.
-- Run: lua5.2 tools/test-combat-target-arrow-authority.lua
local function read(path)
    local f=assert(io.open(path,"r"))
    local text=f:read("*a")
    f:close()
    return text
end
local state={targets={rage="right"},explicit={rage=true}}
local arrows={rage={left=true}}
local env={
    combatAssignmentState=state,
    attackAssignmentsTargetGUIDs=function(key) return arrows[key] or {} end
}
setmetatable(env,{__index=_G})
local recover=dofile("src/PlayingGame/PlayerBoard/ResourceTracker/Combat/SourceTargetAllocation.lua")(env.attackAssignmentsTargetGUIDs).recoverTarget
local function target(source,rows) return recover(source,rows,state) end
local source={key="rage"}
local rows={left=1,right=2}

assert(target(source,rows)=="right" and state.targets.rage=="right",
    "Stale left arrow must not override a deliberate right target")
-- If the calculator has no target, the persistent arrow is a valid
-- recovery source (especially after a save/load).
state.targets.rage=nil
state.explicit.rage=nil
assert(target(source,rows)=="left" and state.targets.rage=="left"
    and state.explicit.rage==true,
    "Missing calculator target should recover the saved left arrow")
-- Deliberate retargeting updates the calculator, even when the old arrow
-- has not yet been synchronized by the UI.
state.targets.rage="right"
arrows.rage={left=true}
assert(target(source,rows)=="right",
    "Manual calculator retarget must remain authoritative")
arrows.rage={left=true,right=true}
state.targets.rage="left"
assert(target(source,rows)=="left",
    "Multiple independent arrows must not replace a valid primary target")
arrows.rage={}
state.targets.rage=nil
assert(target(source,rows)==nil and state.targets.rage==nil,
    "Fresh card with no lock still uses ordinary targeting fallback")
print("Combat calculator target authority regressions passed")
