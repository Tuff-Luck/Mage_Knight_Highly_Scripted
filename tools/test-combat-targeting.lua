-- Runtime targeting and damage-overlay regression with mocked TTS objects.
-- Run from the repository root: lua5.2 tools/test-combat-targeting.lua
local function check(name,condition)
    assert(condition,name)
    print("PASS "..name)
end
local objects={}
local lines={}
local function makeObject(guid,x)
    local buttons,decals={},{}
    local o={guid=guid}
    function o.isDestroyed() return false end
    function o.isSmoothMoving() return false end
    function o.getPosition() return {x or 0,1,0} end
    function o.getBounds() return {size={1.5,0.2,2.5}} end
    function o.getScale() return {x=1,y=1,z=1} end
    function o.getButtons() return buttons end
    function o.getDecals() return decals end
    function o.setDecals(value) decals=value end
    function o.createButton(button)
        button.index=#buttons
        buttons[#buttons+1]=button
    end
    function o.removeButton(index)
        for i=#buttons,1,-1 do
            if buttons[i].index==index then table.remove(buttons,i) end
        end
        for i,button in ipairs(buttons) do button.index=i-1 end
    end
    objects[guid]=o
    return o
end
getObjectFromGUID=function(guid) return objects[guid] end
Global={getVectorLines=function() return lines end,setVectorLines=function(value) lines=value end}
Player={Red={getPointerPosition=function() return {5,1,0} end},
    Blue={getPointerPosition=function() return {6,1,0} end}}
safeCallback=function(_,fn) return fn() end
safeWaitTime=function() end -- execute no async callback in a pure Lua test
broadcastToColor=function(col1, col2, col3, col4) end
monsterPugs={enemy={name="Enemy"},remote={name="Remote"}}
gStates={attackAssignments={}}
local redCard=makeObject("redcard",0)
local blueCard=makeObject("bluecard",0)
local enemy=makeObject("enemy",5)
local remote=makeObject("remote",10)
local eligible={enemy=enemy}
resourceCardsCombatTargetObjects=function() return eligible end
dofile("src/PlayingGame/AttackAssignments.lua")

check("Red begins selecting",attackAssignmentsBegin(redCard,"attack","Red"))
check("Blue independently begins selecting",attackAssignmentsBegin(blueCard,"block","Blue"))
attackAssignmentTargetClicked(remote,"Red")
check("out-of-combat targets are rejected",#gStates.attackAssignments==0)
attackAssignmentTargetClicked(enemy,"Green")
check("another player's missing pending choice cannot create an arrow",
    #gStates.attackAssignments==0)
attackAssignmentTargetClicked(enemy,"Red")
check("Red's valid arrow is persisted",#gStates.attackAssignments==1)
attackAssignmentTargetClicked(enemy,"Blue")
check("independent Blue source arrow persists beside Red's",#gStates.attackAssignments==2)
local saved=gStates.attackAssignments
attackAssignmentsClearAll()
check("clearing arrows resets saved entries",#gStates.attackAssignments==0)
gStates.attackAssignments=saved
attackAssignmentsRestore()
check("arrows are restored from persisted state",#gStates.attackAssignments==2)
attackAssignmentsPruneTargets({})
check("stale target arrows are pruned",#gStates.attackAssignments==0)
attackAssignmentsSetSourceTarget("redcard","enemy","armour")
enemy.held_by_color="Red"
attackAssignmentsPruneTargets({})
check("picked-up target retains its arrow",#gStates.attackAssignments==1)
enemy.held_by_color=nil
enemy.resting=false
attackAssignmentsPruneTargets({})
check("falling target retains its arrow after release",#gStates.attackAssignments==1)
enemy.resting=true
attackAssignmentsPruneTargets({})
check("settled target outside combat loses its arrow",#gStates.attackAssignments==0)
attackAssignmentsClearAll()

local unit=makeObject("unit",3)
attackAssignmentsDamageSync({attacks={{key="enemy:1",owner="enemy",damage=4}},
    units={unit=true}})
local found=false
for _,button in ipairs(enemy.getButtons()) do
    if button.click_function=="attackAssignmentDamageClick1" then found=true end
end
check("unblocked attack supplies damage-targeting button",found)
attackAssignmentDamageClick1(enemy,"Red",false)
attackAssignmentDamageUnitClicked(unit,"Red")
check("Unit accepts assigned damage",attackAssignmentsDamageTargetsOf("enemy:1")[1]=="unit")
attackAssignmentsDamageSync({attacks={},units={unit=true}})
check("blocking removes damage allocation",#attackAssignmentsDamageTargetsOf("enemy:1")==0)
attackAssignmentsDamageSync({attacks={{key="enemy:1",owner="enemy",damage=2}},
    units={unit=true}})
check("unblocking has no stale Unit assignment",#attackAssignmentsDamageTargetsOf("enemy:1")==0)
attackAssignmentDamageClick1(enemy,"Red",false)
attackAssignmentDamageUnitClicked(unit,"Red")
attackAssignmentDamageClick1(enemy,"Red",true)
check("right-click returns damage to Hero",#attackAssignmentsDamageTargetsOf("enemy:1")==0)
attackAssignmentsDamageClear()
check("closing damage phase clears overlays",
    #enemy.getButtons()==0 and #enemy.getDecals()==0)
print("Combat targeting and lifecycle regression tests passed.")
