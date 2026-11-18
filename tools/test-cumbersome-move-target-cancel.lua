-- Regression: cancelling a Pure Magic Move target must remove BOTH the
-- visible arrow and the Combat Calculator's explicit Cumbersome allocation.
-- Run from repository root: lua5.2 tools/test-cumbersome-move-target-cancel.lua
local function read(path)
    local f=assert(io.open(path,"r"))
    local contents=f:read("*a")
    f:close()
    return contents
end
local function section(source,first,last)
    local a=assert(source:find(first,1,true),"Missing "..first)
    local b=assert(source:find(last,a+#first,true),"Missing "..last)
    return source:sub(a,b-1)
end

local source=read("src/PlayingGame/AttackAssignments.lua")
local reader=read("src/PlayingGame/PlayerBoard/CardRecognition.lua")
local data=read("src/Data.lua")
assert(data:find('pureMagic={',1,true),"Pure Magic definition missing")
assert(data:find('{key="move",move=4}',1,true),"Pure Magic basic Move 4 changed")

local callbacks=section(source,"local function persistAssignments()",
    "function attackAssignmentTargetClicked(")
local forget=section(reader,"function resourceCardsCombatForgetSource(sourceGUID)",
    "-- Clear every target key owned by a physical card or Unit")
local moveGUID="878d89"
local enemyGUID="2116ff"
local initialAssignment={
    id="1",sourceGUID=moveGUID,targetGUID=enemyGUID,resource="move",
    playerColor="Blue",kind="attack"
}
local registry={["1"]=initialAssignment}
local pending={}
local state={targets={[moveGUID]=enemyGUID},explicit={[moveGUID]=true}}
local stored={attackAssignments={initialAssignment}}
local sourceObject={guid=moveGUID,isDestroyed=function() return false end}
local refreshes=0
local syncCount=0
local function assignedMove()
    -- The combat calculator counts Cumbersome Move only with an explicit lock.
    return state.explicit[moveGUID]==true and state.targets[moveGUID]==enemyGUID
        and 4 or 0
end
local env={
    assignmentRegistry=registry,
    targetingByPlayer=pending,
    combatAssignmentState=state,
    gStates=stored,
    Player={Blue={}},
    resourceCardsPlayerCanEdit=function(color) return color=="Blue" end,
    -- Source-target assignment now classifies resource kinds in a helper.
    -- This fixture tests cancellation, not resource-family classification.
    attackAssignmentsKindFor=function() return "attack" end,
    resourceCardsPanelOpen=function() return true end,
    -- The isolated callback is outside committed combat phases.
    combatCommittedSource=function() return false end,
    getObjectFromGUID=function(guid)
        return guid==moveGUID and sourceObject or nil
    end,
    safeCallback=function(_,fn) return fn() end,
    syncTargetButtons=function() syncCount=syncCount+1 end,
    refreshRenderedLines=function() end,
    scheduleRefresh=function() end,
    resourceCardsSourceChanged=function() refreshes=refreshes+1 end
}
setmetatable(env,{__index=_G})
assert(load(forget,"Combat lock removal","t",env))()
local clicked=assert(load(callbacks.."\nreturn attackAssignmentSourceClicked",
    "Combat targeting control","t",env))()
local player={color="Blue"}
local id="AttackAssignmentSource_"..moveGUID.."_0_move"
assert(assignedMove()==4,"Initial explicitly targeted Move must contribute")
clicked(player,"-1",id)
assert(next(registry)==nil,"First click must remove the old Move arrow")
assert(#stored.attackAssignments==0,"Deleted arrow must be removed from saved assignments")
assert(state.targets[moveGUID]==nil and state.explicit[moveGUID]==nil,
    "Removing the arrow must immediately clear the calculator's Move target")
assert(assignedMove()==0,"Cleared Move must not still Block a Cumbersome enemy")
assert(refreshes==1,"Removing the target must schedule a calculator refresh")
assert(pending.Blue~=nil and pending.Blue.sourceGUID==moveGUID,
    "First click must still allow retargeting")
clicked(player,"-1",id)
assert(pending.Blue==nil,"Second click cancels retargeting")
assert(assignedMove()==0 and state.targets[moveGUID]==nil,
    "Cancelling retarget must not resurrect a hidden Move allocation")
assert(syncCount>=2,"Target buttons should refresh on begin and cancel")

-- A right-click begins an additional assignment without deleting the
-- original one. This remains available for compatible split/multi-target plays.
registry["2"]={id="2",sourceGUID=moveGUID,targetGUID=enemyGUID,
    resource="move",kind="attack"}
state.targets[moveGUID]=enemyGUID
state.explicit[moveGUID]=true
clicked(player,"-2",id)
assert(registry["2"]~=nil and state.targets[moveGUID]==enemyGUID,
    "Right-click must preserve existing assignment while adding another target")
assert(assignedMove()==4,"Right-click must not silently unassign the current Move")
clicked(player,"-2",id)
assert(pending.Blue==nil,"Right-click targeting can also be cancelled")

print("Cumbersome Move double-click cancellation regression passed")
