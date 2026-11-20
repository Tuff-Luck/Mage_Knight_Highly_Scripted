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

assert(reader:find('if moveAmount>0 and resourceCardsMoveRole(guid,true)=="combat" then',1,true),
    "Only combat-role Move can become a Calculator source")
assert(reader:find('combatAssignmentState.explicit[source.key]=autoCombatMove and targetGUID~=nil or nil',
    1,true),"Default Cumbersome target must reserve the Move pool")
assert(reader:find('combatEntry.icon="block"',1,true)
    and reader:find('combatEntry.iconForeground="move"',1,true)
    and reader:find('combatEntry.roleBadge=nil',1,true),
    "Combat Move option must show shield beneath Move, not a C text badge")
assert(reader:find('entry.iconForeground="influence"',1,true)
    and reader:find('if category=="influence" and combatPsychicActive',1,true),
    "Psychic Block option must show shield beneath Influence")
assert(reader:find('image=foreground.name,width=49,height=49',1,true)
    and reader:find('rectAlignment="LowerRight",offsetXY="-3 3"',1,true),
    "Overlay must be a smaller, non-clickable foreground image")
assert(reader:find('local shield=resourceCardsChoiceIcon("block")',1,true)
    and reader:find('local movement=resourceCardsChoiceIcon("move")',1,true),
    "Unit combat Move needs the same layered icon")
assert(assets:find('move={name="MKChoiceMove"',1,true)
    and assets:find('block={name="MKChoiceBlock"',1,true)
    and assets:find('influence={name="MKChoiceInfluence"',1,true),
    "Composite layers must reuse registered icon assets")

local nearestCode=section(reader,
    "local function combatNearestEnemyGUID(source,entries,eligible)",
    "combatConfig.attackTypes=")
local assignCode=section(reader,
    "    for _,source in ipairs(sources) do\n        local moveOnly=",
    "        if targetIndex~=nil then")
-- Exercise the real refresh-pass selection up to the point where source
-- details are copied into each enemy row. The later presentation is unrelated.
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
local evaluator=assert(load(nearestCode.."\nreturn function(entries,sources,rowByGUID)\n"..
    assignCode.."\nend\nend","Combat Move nearest-default","t",env))()
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
    evaluator(entries,sources,rowByGUID)
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
