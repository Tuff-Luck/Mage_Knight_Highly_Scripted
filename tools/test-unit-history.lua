-- Run from repository root with: lua5.2 tools/test-unit-history.lua
-- Unit activation histories are independent of Tabletop Simulator rendering.
local function eq(actual,expected,label)
    if actual~=expected then
        error(tostring(label)..": expected "..tostring(expected)
            ..", got "..tostring(actual),2)
    end
end

gStates={unitResourceActivations={},unitActivationHistory={},unitReadyLinks={}}
gameCards={u1={level=1},u2={level=3}}
local objects={}
local function object(guid)
    local o={guid=guid,buttons={},held_by_color=nil,
        position={x=1,y=1,z=1},moved=false}
    function o.isDestroyed() return false end
    function o.getButtons() return o.buttons end
    function o.createButton(spec)
        spec.index=#o.buttons
        o.buttons[#o.buttons+1]=spec
    end
    function o.removeButton(index)
        table.remove(o.buttons,index+1)
        for i,b in ipairs(o.buttons) do b.index=i-1 end
    end
    function o.getPosition() return o.position end
    function o.setPositionSmooth(pos)
        o.position={x=pos[1],y=pos[2],z=pos[3]}
        o.moved=true
    end
    objects[guid]=o
    return o
end
local token=object("cmd")
local unit=object("u1")
local card=object("card")
getObjectFromGUID=function(guid) return objects[guid] end
unitLayoutCommandTarget=function(command)
    return command.position.y>=1.3 and unit or nil
end
resourceCardsPlayerCanEdit=function() return true end
resourceCardsReadySourceValid=function(key) return key=="card" or key=="u1" end
resourceUnitsRefreshButtons=function() end
resourceCardsSourceChanged=function() end
resourceCardsCombatForgetSource=function() end
attackAssignmentsPruneSourceTargets=function() end
resourceUnitsPruneHistoricalTargets=function() end
attackAssignmentsRefreshReadyUI=function() end
dofile("src/PlayingGame/PlayerBoard/UnitHistory.lua")

local first={seatPos=1,tokenGUID="cmd",choice=1,
    lastCounts={Green=1}}
gStates.unitResourceActivations.u1=first
unitHistoryEnsure("u1",first)
unitHistoryRefreshToken("u1")
eq(unitHistoryKey("u1",1),"u1","legacy first source")
eq(unitHistoryKey("u1",2),"u1#use2","second source")
eq(#token.buttons,1,"single activation number")
eq(token.buttons[1].label,"1","first label")
eq(unitHistoryReadyLink("card","u1",1,nil),true,"target readying card")
eq(unitHistoryReadyPermission("u1"),"card","source authorises readying")
eq(unitHistoryMarkReady("u1","card"),true,"mark command returned")
eq(first.frozenCounts.Green,1,"preserve earlier paid mana")
local second={seatPos=1,tokenGUID="cmd",choice=2}
eq(unitHistoryAppend("u1",second,"card"),2,"append second activation")
eq(#unitHistoryUses("u1"),2,"two independent activations")
eq(gStates.unitReadyLinks.card.usedBy,2,"record ready dependency")
eq(unitHistorySelectedNumber("u1"),2,"select latest by default")
eq(#token.buttons,3,"previous-number-next token controls")
unitHistoryPrevious(token,"Red")
eq(unitHistorySelectedNumber("u1"),1,"previous selects old use")
eq(unitHistorySelected("u1"),first,"old choices editable")
unitHistoryNext(token,"Red")
eq(unitHistorySelectedNumber("u1"),2,"next returns to latest")
unitHistoryUndoLatest("u1")
eq(#unitHistoryUses("u1"),1,"undo latest preserves first use")
eq(gStates.unitReadyLinks.card.usedBy,nil,"ready card reusable after undo")
eq(gStates.unitResourceActivations.u1,first,"live entry restored")
local third={seatPos=1,tokenGUID="cmd",choice=3}
unitHistoryAppend("u1",third,"card")
gStates.unitResourceActivations={}
unitHistoryRestoreCurrent()
eq(gStates.unitResourceActivations.u1,third,"saved multi-use history restored")
unitHistoryCancelReadySource("card")
eq(#unitHistoryUses("u1"),1,"undo ready card removes dependent use")
eq(gStates.unitResourceActivations.u1,first,"undo keeps original ability")
eq(gStates.unitReadyLinks.card,nil,"ready dependency retired")
-- A source removed while the token is in its ready slot must restore spent.
unitHistoryReadyLink("card","u1",1,nil)
unitHistoryMarkReady("u1","card")
token.position.y=1
unitHistoryCancelReadySource("card")
eq(token.moved,true,"unconsumed Ready undo restores spent token physically")
-- Moving/Healing uses don't spend a Unit's one combat activation per turn.
-- The first selected combat use wins, and edits to an earlier use recalculate
-- eligibility without discarding later choices.
local abilities={
    {key="move",move=2},{key="attack",attack=3},
    {key="healing",healing=2},{key="other",enemyEffect={noAttack=true}},
    {key="other",boostOtherUnits=true}
}
local firstChoice={seatPos=1,tokenGUID="cmd",choice=1}
local secondChoice={seatPos=1,tokenGUID="cmd",choice=2}
local function chosen(use) return {index=use.choice} end
unitHistoryReset()
unitHistoryEnsure("u1",firstChoice)
unitHistoryAppend("u1",secondChoice,"card")
eq(unitHistoryCombatConflict("u1",2,abilities,chosen),false,
    "Move then combat is allowed")
firstChoice.choice=2
eq(unitHistoryCombatConflict("u1",2,abilities,chosen),true,
    "second combat use blocked for the turn")
firstChoice.choice=3
eq(unitHistoryCombatConflict("u1",2,abilities,chosen),false,
    "editing the first use to Heal permits later combat")
firstChoice.choice=4
eq(unitHistoryCombatConflict("u1",2,abilities,chosen),true,
    "targeted combat effects also spend the combat use")
firstChoice.choice=5
eq(unitHistoryCombatConflict("u1",2,abilities,chosen),true,
    "passive combat bonuses also spend the combat use")
firstChoice.choice=1
eq(unitHistoryIsCombatAbility(abilities[1]),false,"Move is noncombat")
eq(unitHistoryIsCombatAbility(abilities[3]),false,"Heal is noncombat")
eq(unitHistoryDecisionHasCombat(abilities,{index=2}),true,"Attack is combat")
local multi={multi=true,abilities[2],abilities[4]}
eq(unitHistoryDecisionHasCombat(multi,{selected={[1]=true,[2]=true}}),true,
    "multiple effects from one activation count as combat")
eq(unitHistoryDecisionHasCombat(multi,{selected={}}),false,
    "undecided multi ability is not a combat use")
unitHistoryReset()
eq(next(gStates.unitActivationHistory),nil,"turn reset clears history")
eq(next(gStates.unitReadyLinks),nil,"turn reset clears ready links")
print("Unit activation history tests passed.")
