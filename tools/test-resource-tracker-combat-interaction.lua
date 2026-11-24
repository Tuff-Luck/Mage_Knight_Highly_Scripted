-- Exercise extracted combat controls with live assignment tables.
local root="src/PlayingGame/PlayerBoard/ResourceTracker/"
local function eq(actual,expected,label)
    assert(actual==expected,label..": expected "..tostring(expected)..", got "..tostring(actual))
end
local refreshes,changes,selectedRefreshes,arrows=0,0,0,{}
local env={
    gStates={battleHardenedAttackKey="old",elementalResistanceAttackKey="old"},
    resourceCardsCombatTargetAcceptsSource=function(key,target) return target~="illegal" end,
    resourceCardsRefreshCombatEnemies=function() refreshes=refreshes+1 end,
    resourceCardsSourceChanged=function() changes=changes+1 end,
    attackAssignmentsSetSourceTarget=function(key,target,kind)
        arrows[key]={target=target,kind=kind}
    end,
    resourceCardsPanelOpen=function() return true end,
    resourceCardsPlayerCanEdit=function(color) return color=="Blue" end
}
setmetatable(env,{__index=_G})
local interaction=assert(loadfile(root.."Combat/CombatInteraction.lua","t",env))()
local state={seat=1,targets={},explicit={}}
local cfg={artifactCombat={bow=true},slotBowFamilies={},bowSourceModes={},effectSources={},
    resultRowCache={},refreshSelectedSlots=function() selectedRefreshes=selectedRefreshes+1 end}
local locked=false
cfg.phaseKeyLocked=function(key) return locked end
interaction.assignSource("0688d8","a",cfg,state)
eq(state.targets["0688d8"],"a","Explicit source target")
eq(state.explicit["0688d8"],true,"Explicit marker")
eq(env.gStates.battleHardenedAttackKey,nil,"Changing target clears attack selector")
eq(refreshes,1,"Assignment refreshes rows")
eq(changes,1,"Assignment schedules source update")
interaction.assignSource("0688d8","illegal",cfg,state)
eq(state.targets["0688d8"],"a","Ineligible target rejected")
locked=true
interaction.assignSource("0688d8","b",cfg,state)
eq(state.targets["0688d8"],"a","Committed source cannot move")
interaction.forgetSource("0688d8",nil,cfg,state)
eq(state.targets["0688d8"],"a","Committed source cannot be forgotten")
locked=false
interaction.forgetSource("0688d8","b",cfg,state)
eq(state.targets["0688d8"],"b","Replacement arrow preserved")
interaction.forgetSource("0688d8",nil,cfg,state)
eq(state.targets["0688d8"],nil,"Removed arrow clears target")
eq(state.explicit["0688d8"],nil,"Removed arrow clears explicit marker")
state.targets.unit="a"
state.targets["unit#use2"]="b"
state.targets.unrelated="c"
state.explicit.unit=true
state.explicit["unit#use2"]=true
state.selected="unit#use2"
interaction.forgetPhysicalSourceTargets("unit",state)
eq(state.targets.unit,nil,"Physical source cleared")
eq(state.targets["unit#use2"],nil,"Historical source cleared")
eq(state.targets.unrelated,"c","Unrelated target retained")
eq(state.selected,nil,"Removed source selection cleared")
local rows={"a","b"}
local indices={1,2}
local joined={}
local function phaseLock(seat) return locked and {} or nil end
local function activeSeat() return 1 end
local function enemyData(guid) return {attackOnly=guid=="reminder"} end
interaction.toggleGroup(1,phaseLock,activeSeat,rows,indices,enemyData,joined)
eq(joined.a,nil,"Cannot join the first enemy")
interaction.toggleGroup(2,phaseLock,activeSeat,rows,indices,enemyData,joined)
eq(joined.b,true,"Group joins preceding enemy")
locked=true
interaction.toggleGroup(2,phaseLock,activeSeat,rows,indices,enemyData,joined)
eq(joined.b,true,"Committed group cannot be changed")
locked=false
interaction.toggleGroup(2,phaseLock,activeSeat,rows,indices,enemyData,joined)
eq(joined.b,nil,"Group separates")
local expanded={}
local rowOnly=0
cfg.resultRowCache[1]={guid="a",hasDetails=true}
cfg.refreshResultRowOnly=function(row) rowOnly=rowOnly+row end
interaction.toggleResult(1,rows,cfg,expanded)
eq(expanded.a,true,"Result expands")
eq(rowOnly,1,"Cached result updates only its own row")
local slots={CombatSourceSlot1attack1="card"}
local function sources(seat)
    return {{key="card",ranged=0,siege=0,block=0,attack=4}}
end
local function cumbersome(guid) return false end
local function arrowKind(source) return "armour" end
interaction.assignmentClick("CombatSourceSlot1attack1","-1",slots,cfg,rows,state,sources,cumbersome,arrowKind)
eq(state.selected,"card","Click selects source")
interaction.assignmentClick("CombatSourceSlot2attack1","-1",slots,cfg,rows,state,sources,cumbersome,arrowKind)
eq(state.targets.card,"b","Second click retargets")
eq(state.explicit.card,true,"Moved source remains explicit")
eq(arrows.card.kind,"armour","Arrow keeps numeric resource colour")
eq(state.selected,nil,"Retarget clears selected source")
cfg.slotBowFamilies.CombatSourceSlot1attack1="ranged"
interaction.assignmentClick("CombatSourceSlot1attack1","-2",slots,cfg,rows,state,sources,cumbersome,arrowKind)
eq(cfg.bowSourceModes["card#ranged"],"siege","Right-click changes Bow mode")
interaction.assignmentClick("CombatSourceSlot1attack1","-2",slots,cfg,rows,state,sources,cumbersome,arrowKind)
eq(cfg.bowSourceModes["card#ranged"],"double","Right-click restores Bow mode")
interaction.forkedLightningPhaseClicked({color="Blue"},nil,"ResourceCardChoice_d01b70_forkPhase")
eq(env.gStates.forkedLightningPhase,"attack","Forked Lightning chooses melee")
interaction.forkedLightningPhaseClicked({color="Blue"},nil,"ResourceCardChoice_d01b70_forkPhase")
eq(env.gStates.forkedLightningPhase,"range","Forked Lightning chooses ranged")
print("Combat interaction controls passed")
