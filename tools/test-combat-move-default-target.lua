-- Combat Move selects the nearest eligible Cumbersome enemy. Its default is
-- a real allocation/arrow, whereas ordinary Movement never enters combat sources.
-- Run from repo root: lua5.2 tools/test-combat-move-default-target.lua
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
local reader=read("src/PlayingGame/PlayerBoard/CardRecognition.lua")
local assets=read("src/PlayingGame/UIAssets.lua")
local unitControls=read("src/PlayingGame/PlayerBoard/ResourceTracker/Interface/UnitControls.lua")
local cardOptions=read("src/PlayingGame/PlayerBoard/ResourceTracker/Interface/CardControlOptions.lua")

assert(reader:find('if moveAmount>0 and resourceCardsMoveRole(guid,true)=="combat" then',1,true),
    "Only combat-role Move can become a Calculator source")
assert(read("src/PlayingGame/PlayerBoard/ResourceTracker/Combat/SourceTargetAllocation.lua"):find('combatAssignmentState.explicit[source.key]=autoCombatMove and targetGUID~=nil or nil',
    1,true),"Default Cumbersome target must reserve the Move pool")
assert(cardOptions:find('combatEntry.icon="block"',1,true)
    and cardOptions:find('combatEntry.stackedIcons={"block","move"}',1,true)
    and cardOptions:find('combatEntry.roleBadge=nil',1,true),
    "Combat Move option must use full-size shield + Move icons, not a C badge")
assert(cardOptions:find('entry.stackedIcons={"block","influence"}',1,true)
    and cardOptions:find('if category=="influence" and combatPsychicActive',1,true),
    "Psychic Block option must use full-size shield + Influence icons")
assert(read("src/PlayingGame/PlayerBoard/ResourceTracker/Interface/CardControls.lua"):find('image=stackedAsset.name,width=82,height=82',1,true)
    and read("src/PlayingGame/PlayerBoard/ResourceTracker/Interface/CardControls.lua"):find('for _,stackedIcon in ipairs(entry.stackedIcons)',1,true),
    "Composite icons must reuse Tempered Steel's full-size stacked rendering")
assert(cardOptions:find('if combatCalcOn and combatCumbersomeActive then',1,true)
    and cardOptions:find('if selected~=nil and combatCalcOn and combatCumbersomeActive',1,true),
    "Combat Move choice must disappear when no Cumbersome enemy is available")
assert(unitControls:find('if combatMoveAvailable then',1,true)
    and unitControls:find('if combatMoveAvailable\n',1,true),
    "Unit Combat Move must disappear when no Cumbersome enemy is available")
assert(read("src/PlayingGame/PlayerBoard/ResourceTracker/Interface/CardControls.lua"):find('..":PSY:"..tostring(combatPsychicActive)',1,true),
    "Card icons must refresh when the last Psychic attacker disappears")
assert(unitControls:find('local shield=resourceCardsChoiceIcon("block")',1,true)
    and unitControls:find('local movement=resourceCardsChoiceIcon("move")',1,true),
    "Unit combat Move needs the same layered icon")
assert(assets:find('move={name="MKChoiceMove"',1,true)
    and assets:find('block={name="MKChoiceBlock"',1,true)
    and assets:find('influence={name="MKChoiceInfluence"',1,true),
    "Composite layers must reuse registered icon assets")

local nearestCode=section(reader,
    "local function combatNearestEnemyGUID(source,entries,eligible)",
    "combatConfig.attackTypes=")
-- Exercise the real target selection with the production nearest-enemy helper.
local positions={
    moving={0,0,0},
    normal={1,0,0},
    farCumbersome={7,0,0},
    nearCumbersome={3,0,0}
}
local cumbersome={farCumbersome=true,nearCumbersome=true}
local state={targets={},explicit={}}
local clears=0
local env={
    combatAssignmentState=state,
    combatCumbersomeActive=true,
    getObjectFromGUID=function(guid)
        if positions[guid]==nil then return nil end
        return {getPosition=function() return positions[guid] end}
    end,
    combatGUIDHasCumbersome=function(guid) return cumbersome[guid]==true end,
    attackAssignmentsTargetGUIDs=function() return {} end,
    attackAssignmentsClearForObject=function() clears=clears+1 end,
    resourceCardsCombatTargetAcceptsSource=function() return true end
}
setmetatable(env,{__index=_G})
local nearest=assert(load(nearestCode.."\nreturn combatNearestEnemyGUID","Nearest enemy","t",env))()
local evaluator=dofile("src/PlayingGame/PlayerBoard/ResourceTracker/Combat/SourceTargetAllocation.lua")(
    env.attackAssignmentsTargetGUIDs,env.attackAssignmentsClearForObject,
    env.resourceCardsCombatTargetAcceptsSource,env.combatGUIDHasCumbersome,nearest).resolveTarget
local entries={
    {guid="normal",attackOnly=false},
    {guid="farCumbersome",attackOnly=false},
    {guid="nearCumbersome",attackOnly=false}
}
local rowByGUID={normal=1,farCumbersome=2,nearCumbersome=3}
local function source(key,move,attack)
    return {guid="moving",key=key,move=move or 0,
        ranged=0,siege=0,block=0,attack=attack or 0,
        psychicInfluence=0}
end
local function scan(sources)
    for _,item in ipairs(sources) do
        evaluator(item,entries,rowByGUID,state,env.combatCumbersomeActive)
    end
end
scan({source("combatMove",4)})
assert(state.targets.combatMove=="nearCumbersome",
    "Nearest normal enemy is not eligible for Cumbersome Move")
assert(state.explicit.combatMove==true,
    "Auto-targeted Move must count as allocated Cumbersome Block")
-- An existing hand-selected far target must never be replaced by nearest.
state.targets.combatMove="farCumbersome"
state.explicit.combatMove=true
scan({source("combatMove",4)})
assert(state.targets.combatMove=="farCumbersome" and state.explicit.combatMove,
    "Manual target is authoritative even when a nearer enemy exists")
-- If a previous target stops being Cumbersome, retarget to the nearest legal one.
state.targets.combatMove="normal"
state.explicit.combatMove=true
scan({source("combatMove",4)})
assert(state.targets.combatMove=="nearCumbersome"
    and state.explicit.combatMove and clears==1,
    "Invalid Cumbersome target must be cleared and reassigned")
-- When no enemy has Cumbersome there is no valid automatic Move allocation.
cumbersome.nearCumbersome=nil
cumbersome.farCumbersome=nil
env.combatCumbersomeActive=false
state.targets.combatMove=nil
state.explicit.combatMove=nil
scan({source("combatMove",4)})
assert(state.targets.combatMove==nil and state.explicit.combatMove==nil,
    "Combat Move must not target an ordinary enemy")
-- The ordinary numeric attack path still auto-targets the nearest enemy.
scan({source("attack",0,3)})
assert(state.targets.attack=="normal" and state.explicit.attack==nil,
    "Ordinary combat Attack nearest-target behaviour must stay unchanged")

print("Combat Move default target and shield-overlay regression passed")
