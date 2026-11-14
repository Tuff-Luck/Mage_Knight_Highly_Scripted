-- Single-enemy combat: only redundant automatic target buttons are hidden.
-- Run from repo root: lua5.2 tools/test-single-enemy-target-buttons.lua
local function read(path)
    local f=assert(io.open(path,"r"))
    local result=f:read("*a")
    f:close()
    return result
end
local function slice(source,first,last)
    local a=assert(source:find(first,1,true),"Missing "..first)
    local b=assert(source:find(last,a+#first,true),"Missing "..last)
    return source:sub(a,b-1)
end
local function eq(actual,expected,label)
    assert(actual==expected,(label or "Mismatch")..": expected "..tostring(expected)
        ..", got "..tostring(actual),2)
end
local function hasButton(xml,id)
    for _,node in ipairs(xml or {}) do
        if node.attributes~=nil and node.attributes.id==id then return node end
    end
end

local source=read("src/PlayingGame/PlayerBoard/CardRecognition.lua")
local assets=read("src/PlayingGame/UIAssets.lua")
local newURL="https://steamusercontent-a.akamaihd.net/ugc/16695628476303620030/8C3369792E242542F0F8F489F12A4CABFA278F98/"
assert(assets:find('unitTarget={name="MKUnitEnemyTarget",url="'..newURL..'"}',1,true),
    "Dedicated Unit target icon must be registered with the exact URL")
assert(assets:find('"target","unitTarget","siege"',1,true),
    "New target image must be preloaded as a Custom UI Asset")

-- Exercise the actual combat enemy counter on face-up, face-down, summoned,
-- reminder, and multiple enemy cases.
local calcCode=slice(source,"local function combatCalcUpdate(monsters)",
    "-- A token lifted above a short scripting zone")
local env={
    gStates={monsterPerks={}},
    trackerPrivate={},
    resourceCardsDetailsOpen=function() return true end,
    combatEnemyData=function(guid,obj) return obj and obj.data end,
    combatEntryHasCumbersome=function() return false end,
    combatIsSummonedToken=function(guid) return guid=="summon" end
}
setmetatable(env,{__index=_G})
local calc=assert(load(calcCode.."\nreturn combatCalcUpdate",
    "single enemy counter","t",env))()
local function enemy(data)
    return {data=data,resting=true,is_face_down=false,isDestroyed=function() return false end}
end
local a=enemy({name="Enemy",attack={P=3}})
local b=enemy({name="Enemy 2",attack={P=2}})
local reminder=enemy({name="Volkare Reminder",attackOnly=true})
local summoned=enemy({name="Summoned"})
calc({a=a})
eq(env.trackerPrivate.singleAutoEnemyGUID,"a","Lone ordinary enemy")
calc({a=a,b=b})
eq(env.trackerPrivate.singleAutoEnemyGUID,nil,"Two enemies restore target buttons")
calc({a=a,reminder=reminder})
eq(env.trackerPrivate.singleAutoEnemyGUID,nil,"Attack-only reminder preserves targeting")
calc({a=a,summon=summoned})
eq(env.trackerPrivate.singleAutoEnemyGUID,nil,"Summoned token preserves targeting")
b.is_face_down=true
calc({a=a,b=b})
eq(env.trackerPrivate.singleAutoEnemyGUID,"a","Face-down enemy is not a live target")
b.is_face_down=false
calc({reminder=reminder})
eq(env.trackerPrivate.singleAutoEnemyGUID,nil,"Reminder alone never hides target buttons")
calc({})
eq(env.trackerPrivate.singleAutoEnemyGUID,nil,"No enemy cannot hide target buttons")

dofile("src/PlayingGame/PlayerBoard/UnitResources.lua")
local northern=assert(unitResourceDefinitions["f17813"],"Northern Monks definition")
local sorcerers=assert(unitResourceDefinitions["c3e3c5"],"Sorcerers definition")

-- Run the Unit target rendering and shared policy in a minimal TTS Object UI.
local targetFunctions=slice(source,
    "local function unitAbilityTargetCategory(ability)",
    "-- The printed normal and powered effects share one choice")
local unitButtons=slice(source,
    "local function showUnitAbilityButtons(unit,abilities,activation,unwounded,decision,useIndex)",
    "local function clearChoiceButtons()")
local ui=assert(load([[
local trackerPrivate={singleAutoEnemyGUID=nil}
local combatCalcOn=true
local combatPsychicActive=false
local combatCumbersomeActive=false
local combatConfig={sourceFields={{key="attack"},{key="attackIce"},
    {key="block"},{key="blockIce"},{key="ranged"},{key="move"}},
    unitCombatBlocked=function() return false end}
local combatAssignmentState={targets={}}
local pending=false
local eligible=true
local function attackAssignmentsIsTargeting() return pending end
local function attackAssignmentsTargetGUIDs() return {} end
local function resourceCardsCombatTargetAcceptsSource() return eligible end
local function unitHistoryKey(guid,index)
    return index==1 and guid or guid.."#use"..tostring(index)
end
local function unitHistorySelectedNumber() return 1 end
local function unitHistoryIsCombatAbility() return false end
local function unitManaDecision() error("Explicit decision required") end
local choiceButtonShown,choiceExpandedByGUID={},{}
local choiceLetters={}
local function resourceObjectUiXmlTable(objUI) return objUI.nodes or {} end
local function resourceCardsChoiceIcon(category)
    return {name=category=="unitTarget" and "MKUnitEnemyTarget" or "MKTargetIcon"}
end
local function resourceCardsChoiceAssetsFor() return nil,{} end
local function resourceObjectUiSetTable(objUI,xml) objUI.nodes=xml end
local function removeChoiceButtons(unit) unit.UI.nodes={} end
]]..targetFunctions..unitButtons..[[
return {
    single=function(guid) trackerPrivate.singleAutoEnemyGUID=guid end,
    pending=function(on) pending=on end,
    eligible=function(on) eligible=on end,
    retarget=function(key,guid) combatAssignmentState.targets[key]=guid end,
    hide=resourceCardsHideAutomaticEnemyTarget,
    render=function(unit,abilities,decision,use)
        showUnitAbilityButtons(unit,abilities,{seatPos=1,choice=1},true,decision,use or 1)
        return unit.UI.nodes
    end
}
]],"Unit single enemy button policy","t",_G))()
local monk={guid="f17813",UI={nodes={}}}
local blueAttack={index=3,display={1,2,3,4}}
local attackTarget="AttackAssignmentSource_f17813_0_attackIce"

ui.single(nil)
local xml=ui.render(monk,northern,blueAttack)
local button=assert(hasButton(xml,attackTarget),"Two-enemy Ice Attack target button")
eq(button.children[1].attributes.image,"MKUnitEnemyTarget",
    "New image used by Unit enemy-target button")

ui.single("enemy")
xml=ui.render(monk,northern,blueAttack)
assert(not hasButton(xml,attackTarget),"One enemy hides auto Ice Attack target")
assert(hasButton(xml,"ResourceCardChoice_f17813_unit3"),
    "Unit ability choice remains despite hidden target")
ui.pending(true)
xml=ui.render(monk,northern,blueAttack)
assert(hasButton(xml,attackTarget),"Pending retarget must remain cancellable")
ui.pending(false)
ui.retarget(monk.guid,"otherEnemy")
xml=ui.render(monk,northern,blueAttack)
assert(hasButton(xml,attackTarget),"Explicit assignment to other enemy must not be concealed")
ui.retarget(monk.guid,nil)
ui.eligible(false)
xml=ui.render(monk,northern,blueAttack)
assert(hasButton(xml,attackTarget),"Illegal sole target keeps manual button")
ui.eligible(true)
ui.single(nil)
xml=ui.render(monk,northern,blueAttack)
assert(hasButton(xml,attackTarget),"Second enemy restores target button")

-- A Unit with separate ranged and enemy-effect arrows (Sorcerers) must
-- hide only the redundant controls and retain their underlying ability.
local sorc={guid="c3e3c5",UI={nodes={}}}
local white={index=2,display={1,2,3}}
ui.single(nil)
xml=ui.render(sorc,sorcerers,white)
assert(hasButton(xml,"AttackAssignmentSource_c3e3c5_0_ranged"),
    "Multiple enemies show Sorcerers ranged target")
assert(hasButton(xml,"AttackAssignmentSource_c3e3c5_0_effect@effect2"),
    "Multiple enemies show Sorcerers effect target")
ui.single("enemy")
xml=ui.render(sorc,sorcerers,white)
assert(not hasButton(xml,"AttackAssignmentSource_c3e3c5_0_ranged"),
    "Single enemy hides ranged target")
assert(not hasButton(xml,"AttackAssignmentSource_c3e3c5_0_effect@effect2"),
    "Single eligible enemy hides automatic separate effect target")
assert(hasButton(xml,"ResourceCardChoice_c3e3c5_unit2"),
    "Sorcerers paid ability remains selectable")

-- Explicit Move/Psychic assignment, manual enemy effects and friendly Ready
-- targeting must always stay available, even with exactly one enemy.
eq(ui.hide("f17813","move",false),false,"Cumbersome Move explicit")
eq(ui.hide("f17813","influence",false),false,"Psychic Influence explicit")
eq(ui.hide("f17813","unitReady",false),false,"Friendly Ready")
eq(ui.hide("f17813","blockSource",false),false,"Spirit Guides friendly link")
eq(ui.hide("f17813#effect1","effect",false),false,"Manual enemy effect")
eq(ui.hide("f17813#effect1","effect",true),true,"Automatic enemy effect")
local readyUnit={guid="cafe01",UI={nodes={}}}
xml=ui.render(readyUnit,{{key="ready",icon="move"}},{index=1,display={1}})
local readyButton=assert(hasButton(xml,"AttackAssignmentSource_cafe01_0_unitReady"),
    "Friendly Ready target remains")
eq(readyButton.children[1].attributes.image,"MKTargetIcon",
    "Friendly Ready keeps its existing image")

assert(source:find("resourceCardsHideAutomaticEnemyTarget(card.guid,",1,true),
    "Card target buttons must use the same one-enemy policy")
assert(source:find('..":TARGETS:"..tostring(trackerPrivate.singleAutoEnemyGUID)',1,true),
    "Card UI signatures must respond when enemy count changes")
assert(source:find("entry.splitTargets==nil",1,true),
    "Cards with special split targets must retain manual buttons")

print("Single-enemy target visibility and Unit icon regressions passed")
