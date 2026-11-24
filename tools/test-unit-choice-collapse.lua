package.path="src/?.lua;"..package.path
-- Reproduce the Peasants (484fa3) option expansion / target regression.
-- Run from repository root: lua5.2 tools/test-unit-choice-collapse.lua
local function read(path)
    local f=assert(io.open(path,"r"))
    local value=f:read("*a")
    f:close()
    return value
end

local function extract(source,first,last)
    local begin=assert(source:find(first,1,true),"Missing "..first)
    local finish=assert(source:find(last,begin+#first,true),"Missing "..last)
    return source:sub(begin,finish-1)
end

local function hasButton(xml,id)
    for _,node in ipairs(xml or {}) do
        if node.attributes~=nil and node.attributes.id==id then return true end
    end
    return false
end

dofile("src/PlayingGame/PlayerBoard/Units/UnitResources.lua")
local printed=assert(unitResourceDefinitions["484fa3"],"Peasants not registered")
assert(#printed==4 and printed[4].move==2,"Peasants test needs printed Move 2")

local code=read("src/PlayingGame/PlayerBoard/CardRecognition.lua")
local renderer=extract(code,
    'local showUnitAbilityButtons=require("PlayingGame.PlayerBoard.ResourceTracker.Interface.UnitControls")({',
    "local function clearChoiceButtons()")
local handler=extract(code,
    "function resourceUnitsChoiceClicked(player,value,id)",
    "-- Release a temporary offered Unit")

-- Execute the actual production renderer and click handler with minimal TTS
-- mocks. The movement role and collapsed/expanded UI state share one closure.
local fixture=assert(load([[
local abilities=...
local unit={guid="484fa3",UI={nodes={}}}
local activation={seatPos=1,tokenGUID="command",choice=1}
local gStates={turnNumber=1,unitResourceActivations={[unit.guid]=activation}}
local turnOrder={[1]={seatPos=1}}
local combatCalcOn=true
local combatCumbersomeActive=false
local combatPsychicActive=false
local combatBlocked,hideTargets=false,false
local combatConfig={unitCombatBlocked=function() return combatBlocked end,
    moveRoleAvailable=function() return combatCalcOn end}
local choiceButtonShown,choiceExpandedByGUID={},{}
local choiceLetters={}
local trackerPrivate={unitAbilitiesFor=function() return abilities end}
local function getObjectFromGUID(guid) return guid==unit.guid and unit or nil end
local function resourceCardsPanelOpen() return true end
local function resourceCardsPlayerCanEdit() return true end
local function unitHistorySelected(guid,latest) return latest,1 end
local function unitHistorySelectedNumber() return 1 end
local function unitHistoryKey(guid,index)
    return index==1 and guid or guid.."#use"..index
end
local function unitHistoryIsCombatAbility(ability,role)
    return ability.attack~=nil or ability.block~=nil or (ability.move~=nil and role=="combat")
end
local function unitHistoryDecisionHasCombat(abilities,decision,role)
    return decision.index~=nil and unitHistoryIsCombatAbility(abilities[decision.index],role)
end
local function unitLayoutResourceState()
    return {units={{guid=unit.guid,unwounded=true}}}
end
local function unitManaDecision(unit,abilities,current)
    return {index=current.choice,display={1,2,3,4},ambiguous=false}
end
local function resourceCardsMoveRole(key)
    return (gStates.resourceCardMoveRoles or {})[key] or "movement"
end
local function unitAbilityTargetCategory(ability)
    if not combatCalcOn then return nil end
    if ability.attack then return "attack" end
    if ability.block then return "block" end
    if combatCumbersomeActive and ability.move then return "move" end
    return nil
end
local function unitAbilityTargetKey(guid,index,ability,useIndex)
    return unitHistoryKey(guid,useIndex)
end
local function resourceCardsHideAutomaticEnemyTarget() return hideTargets end
local function resourceCardsChoiceIcon() return nil end
local function resourceCardsChoiceAssetsFor() return nil,{} end
local function resourceObjectUiXmlTable(ui) return ui.nodes end
local function resourceObjectUiSetTable(ui,xml) ui.nodes=xml end
local function removeChoiceButtons(obj) obj.UI.nodes={} end
local function resourceCardsCombatSelectOneUnit() end
local function resourceUnitsReconcileChoiceTargets() end
local function unitHistoryValidSources() end
local function renderSeat() end
]]..renderer.."\ntrackerPrivate.unitManagement=(function()\n"..read("src/PlayingGame/PlayerBoard/ResourceTracker/Units/UnitManagement.lua").."\nend)()\n"..handler..[[
return {
    draw=function()
        showUnitAbilityButtons(unit,abilities,activation,true,nil,1)
        return unit.UI.nodes
    end,
    click=function(index,combat)
        local suffix=combat and "Combat" or ""
        resourceUnitsChoiceClicked({color="Blue"},"",
            "ResourceCardChoice_484fa3_unit"..tostring(index)..suffix)
        return unit.UI.nodes
    end,
    cumbersome=function(value) combatCumbersomeActive=value end,
    combatBlocked=function(value) combatBlocked=value end,
    hideTargets=function(value) hideTargets=value end,
    resetCaches=function()
        choiceButtonShown={}
        choiceExpandedByGUID={}
    end,
    loseControls=function() unit.UI.nodes={} end,
    role=function() return resourceCardsMoveRole(unit.guid) end
}
]],"Peasants Unit option regression","t",_G))(printed)

local function assertCollapsed(buttons,index,category)
    assert(hasButton(buttons,"ResourceCardChoice_484fa3_unit"..index),
        "Selected Peasants option should be visible")
    for i=1,4 do
        if i~=index then
            assert(not hasButton(buttons,"ResourceCardChoice_484fa3_unit"..i),
                "Unselected Peasants option must be collapsed")
        end
    end
    if category~=nil then
        assert(hasButton(buttons,
            "AttackAssignmentSource_484fa3_0_"..category),
            "Selected combat option must restore its target button")
    end
end

-- Command token initially renders just the selected ability.
assertCollapsed(fixture.draw(),1,"attack")
-- First click opens all four Peasants choices and hides the target.
local buttons=fixture.click(1)
for i=1,4 do
    assert(hasButton(buttons,"ResourceCardChoice_484fa3_unit"..i),
        "Clicked selected option must expand all Peasants abilities")
end
assert(not hasButton(buttons,"AttackAssignmentSource_484fa3_0_attack"),
    "Target icon must hide while options are expanded")
-- Selecting another ability collapses and restores its target.
assertCollapsed(fixture.click(2),2,"block")
fixture.click(2)
assertCollapsed(fixture.click(4),4,nil)
-- Unlike the former Move special case, clicking collapsed Move expands.
buttons=fixture.click(4)
for i=1,4 do
    assert(hasButton(buttons,"ResourceCardChoice_484fa3_unit"..i),
        "Collapsed Move must expand Peasants alternatives")
end
assertCollapsed(fixture.click(4),4,nil)

-- When Cumbersome is present, the independent Combat-Move button must
-- remain available without reopening all other Peasants options.
fixture.cumbersome(true)
buttons=fixture.draw()
assert(hasButton(buttons,"ResourceCardChoice_484fa3_unit4Combat"),
    "Cumbersome must expose the separate Combat-Move control")
buttons=fixture.click(4,true)
assert(fixture.role()=="combat","Combat-Move button must select the combat role")
assertCollapsed(buttons,4,"move")
-- A reload/reset replaces both shared UI-cache tables. A renderer retaining
-- the old expanded table would incorrectly reopen all four options.
fixture.click(4)
fixture.resetCaches()
assertCollapsed(fixture.draw(),4,"move")
-- TTS may apply UI asynchronously; recreate missing buttons despite the cache.
fixture.loseControls()
assertCollapsed(fixture.draw(),4,"move")
-- When automatic target buttons are hidden, a change in earlier Command
-- use can change only the selected option's colour, not its visible IDs.
fixture.click(4)
fixture.click(1)
fixture.hideTargets(true)
local function selectedAttackColor()
    local buttons=fixture.draw()
    for _,node in ipairs(buttons) do
        if node.attributes.id=="ResourceCardChoice_484fa3_unit1" then
            return node.attributes.colors
        end
    end
    error("Selected attack control missing")
end
assert(selectedAttackColor():find("#387D30",1,true),"Legal Attack is green")
fixture.combatBlocked(true)
assert(selectedAttackColor():find("#9C3737",1,true),"Historical combat conflict refreshes red Attack")
fixture.combatBlocked(false)
assert(selectedAttackColor():find("#387D30",1,true),"Cleared conflict restores green Attack")
print("Peasants Unit option expansion, collapse, Move target and combat conflict regressions passed")
