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
    local currentX=x or 0
    function o.isDestroyed() return false end
    function o.isSmoothMoving() return false end
    function o.getPosition() return {currentX,1,0} end
    function o.setTestPosition(nextX) currentX=nextX end
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
local reminder=makeObject("reminder",7)
eligible.reminder=reminder
turnOrder={{seatPos=1}}
playerUnitAreas={}
playerPlayAreas={}
gStates.attackAssignments={{id="1",sourceGUID="redcard",targetGUID="reminder",
    resource="block",kind="attack"}}
attackAssignmentsRestore()
check("attack-only reminder target survives saved-arrow restoration",
    attackAssignmentsTargetGUIDs("redcard").reminder==true)
eligible.reminder=nil
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
local otherUnit=makeObject("secondunit",4)
attackAssignmentsDamageSync({attacks={{key="enemy:1",owner="enemy",damage=4}},
    units={unit=true,secondunit=true}})
local found=false
for _,button in ipairs(enemy.getButtons()) do
    if button.click_function=="attackAssignmentDamageClick1" then found=true end
end
check("unblocked attack supplies damage-targeting button",found)
attackAssignmentDamageClick1(enemy,"Red",false)
attackAssignmentDamageUnitClicked(unit,"Blue")
check("other player cannot complete pending damage targeting",
    #attackAssignmentsDamageTargetsOf("enemy:1")==0)
attackAssignmentDamageClick1(enemy,"Blue",true)
attackAssignmentDamageUnitClicked(unit,"Red")
check("Unit accepts damage from the player who started targeting",
    attackAssignmentsDamageTargetsOf("enemy:1")[1]=="unit")
attackAssignmentDamageClick1(enemy,"Red",false)
attackAssignmentDamageUnitClicked(otherUnit,"Red")
check("one attack can target multiple Units",
    #attackAssignmentsDamageTargetsOf("enemy:1")==2)
attackAssignmentDamageClick1(enemy,"Red",false)
check("first click enters targeting without losing the existing assignments",
    #attackAssignmentsDamageTargetsOf("enemy:1")==2)
attackAssignmentDamageClick1(enemy,"Red",false)
check("second click on the same enemy damage button clears all its Unit targets",
    #attackAssignmentsDamageTargetsOf("enemy:1")==0)
attackAssignmentDamageClick1(enemy,"Red",false)
attackAssignmentDamageUnitClicked(unit,"Red")
check("damage can be assigned again after a double-click reset",
    attackAssignmentsDamageTargetsOf("enemy:1")[1]=="unit")
attackAssignmentsDamageSync({attacks={},units={unit=true}})
check("blocking removes damage allocation",#attackAssignmentsDamageTargetsOf("enemy:1")==0)
attackAssignmentsDamageSync({attacks={{key="enemy:1",owner="enemy",damage=2}},
    units={unit=true}})
check("unblocking has no stale Unit assignment",#attackAssignmentsDamageTargetsOf("enemy:1")==0)
attackAssignmentDamageClick1(enemy,"Red",false)
attackAssignmentDamageUnitClicked(unit,"Red")
attackAssignmentDamageClick1(enemy,"Red",true)
check("right-click returns damage to Hero",#attackAssignmentsDamageTargetsOf("enemy:1")==0)
-- Forced first recipients produce arrows even without manual damageTargets.
attackAssignmentsDamageSync({attacks={{key="enemy:1",owner="enemy",damage=3,
    firstDamageUnit="unit"}},units={unit=true}})
local function forcedArrowEndX()
    for _,line in ipairs(lines) do
        if line.color and line.color[1]==1 and line.color[2]==0.1 then
            return line.points[2][1]
        end
    end
end
check("forced damage assignment draws a red arrow",forcedArrowEndX()==3)
unit.setTestPosition(8)
attackAssignmentsObjectMoved(unit)
check("forced damage arrow follows Unit movement",forcedArrowEndX()==8)
attackAssignmentsDamageClear()
check("closing damage phase clears overlays",
    #enemy.getButtons()==0 and #enemy.getDecals()==0)
print("Combat targeting and lifecycle regression tests passed.")

-- Preview Unit wounds are locked, translucent and non-gameplay until End Turn.
-- These mocks exercise the physical TTS lifecycle without requiring a running table.
local board=makeObject("unit-board",8)
function board.getSnapPoints()
    return {{position={x=7.43,y=0,z=0},tags={"Wound"}},
        {position={x=8,y=0,z=0},tags={"Wound"}},
        {position={x=8.57,y=0,z=0},tags={"Wound"}}}
end
function board.positionToWorld(p) return p end
playerBoard={[1]=board.guid}
function unit.getBoundsNormalized() return {size={x=2,y=0.2,z=3}} end
function otherUnit.getBoundsNormalized() return {size={x=2,y=0.2,z=3}} end

local panelOpen=true
resourceCardsPanelOpen=function() return panelOpen end
gStates.preEndTurn=false
local bag={guid="unit-wound-bag"}
function bag.getName() return "Unit Wounds" end
function bag.getPosition() return {x=8,y=1,z=-28} end
function bag.hasTag() return false end
function bag.getGMNotes() return "" end
objects[bag.guid]=bag
local allPreviewTokens={}
local nextWoundID=0
function bag.takeObject(args)
    nextWoundID=nextWoundID+1
    local token={guid="ghost"..tostring(nextWoundID),type="Custom_Model",locked=false}
    local tags={Wound=true}
    local notes="Unit Wound"
    local p={x=args.position[1],y=args.position[2],z=args.position[3]}
    function token.getGMNotes() return notes end
    function token.setGMNotes(value) notes=value end
    function token.hasTag(tag) return tags[tag]==true end
    function token.addTag(tag) tags[tag]=true end
    function token.removeTag(tag) tags[tag]=nil end
    function token.getPosition() return p end
    function token.setPosition(nextPos) p={x=nextPos[1],y=nextPos[2],z=nextPos[3]} end
    function token.setColorTint(color) token.tint=color end
    function token.lock() token.locked=true end
    function token.destruct() objects[token.guid]=nil token.destroyed=true end
    objects[token.guid]=token
    allPreviewTokens[#allPreviewTokens+1]=token
    args.callback_function(token)
    return token
end
getObjects=function() return {bag} end
dofile("src/PlayingGame/PlayerBoard/UnitLayout.lua")
local function ghosts()
    local found={}
    for _,token in ipairs(allPreviewTokens) do
        if objects[token.guid]~=nil and token.hasTag("CombatPreviewWound") then
            found[#found+1]=token
        end
    end
    return found
end
local function resolveUnit(target,amount,destroyed)
    return {enemy={units={{wounded=true,unit={guid=target},wounds=amount,destroyed=destroyed}}}}
end

attackAssignmentsUnitPreviewSync(1,resolveUnit("unit",1,false))
local preview=ghosts()
check("normal damage draws one locked translucent centre wound",#preview==1
    and preview[1].locked and preview[1].tint.a==150/255
    and preview[1].getPosition().x==8 and preview[1].getPosition().y==1.16)
check("ghost is not treated as a wounded Unit",not unitLayoutIsWound(preview[1]))
attackAssignmentsUnitPreviewSync(1,resolveUnit("unit",1,false))
check("recalculation does not duplicate a ghost",#ghosts()==1)

attackAssignmentsUnitPreviewSync(1,resolveUnit("unit",2,false))
local poison=ghosts()
table.sort(poison,function(a,b) return a.getPosition().x<b.getPosition().x end)
check("Poison has two green locked wounds on outer snaps",#poison==2
    and poison[1].getPosition().x==7.43 and poison[2].getPosition().x==8.57
    and poison[1].tint.g==1 and poison[1].tint.r<1
    and poison[1].locked and poison[2].locked)
attackAssignmentsUnitPreviewSync(1,{enemy={units={{wounded=false,unit={guid="unit"}}}}})
check("full resistance removes all ghost Wounds",#ghosts()==0)

attackAssignmentsUnitPreviewSync(1,resolveUnit("unit",1,true))
local marked=false
for _,button in ipairs(unit.getButtons()) do
    if button.click_function=="attackAssignmentParalysisMarkerNoop" and button.label=="X" then marked=true end
end
check("Paralysis renders a red X without a Wound",marked and #ghosts()==0)
attackAssignmentsUnitPreviewSync(1,{})
local markedAfter=false
for _,button in ipairs(unit.getButtons()) do
    if button.click_function=="attackAssignmentParalysisMarkerNoop" then markedAfter=true end
end
check("undoing Paralysis removes the unit X",not markedAfter)

attackAssignmentsUnitPreviewSync(1,resolveUnit("unit",1,false))
panelOpen=false
attackAssignmentsUnitPreviewClear()
check("turning the tracker off removes physical ghosts",#ghosts()==0)
panelOpen=true
attackAssignmentsUnitPreviewSync(1,resolveUnit("unit",1,false))
preview=ghosts()
attackAssignmentsUnitPreviewCommit(1)
check("End Turn promotes a ghost to a permanent locked Wound",#ghosts()==0
    and preview[1].getGMNotes()=="Unit Wound" and preview[1].locked
    and preview[1].tint.a==1 and unitLayoutIsWound(preview[1]))
attackAssignmentsUnitPreviewClear()
check("tracker cleanup preserves committed Wounds",
    objects[preview[1].guid]~=nil)

trashCan="trash"
objects.trash={putObject=function(target) objects[target.guid]=nil end}
protectedObjectAllowScriptRemoval=function() end
attackAssignmentsUnitPreviewSync(1,resolveUnit("secondunit",1,true))
attackAssignmentsUnitPreviewCommit(1)
check("Paralysis removes the destroyed Unit at End Turn, not a Wound",
    objects.secondunit==nil and #ghosts()==0)
print("Combat Unit wound preview lifecycle regression tests passed.")
