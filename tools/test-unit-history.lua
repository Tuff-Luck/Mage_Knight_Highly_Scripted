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
    function o.isSmoothMoving() return false end
    function o.getGMNotes() return guid=="cmd" and "Command Token" or "Bonds of Loyalty" end
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
eq(#token.buttons,0,"no number or arrows for the first activation")
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
eq(token.buttons[1].label,"2","display second activation number")
eq(token.buttons[1].width,0,"activation number has no button surface")
eq(token.buttons[1].height,0,"activation number has no click area")
eq(token.buttons[1].position[2],unitHistory.tokenButtonY.native,"native Command number height")
eq(token.buttons[1].rotation[3],180,"native Command number oriented correctly")
eq(token.buttons[2].position[1],0.31,"native Previous arrow on visual left")
eq(token.buttons[3].position[1],-0.31,"native Next arrow on visual right")
eq(token.buttons[2].position[2],unitHistory.tokenButtonY.native,"Previous arrow height matches number")
eq(token.buttons[3].position[2],unitHistory.tokenButtonY.native,"Next arrow height matches number")
unitHistory.tokenButtonY.native=-0.08
unitHistoryRefreshToken("u1")
eq(token.buttons[1].position[2],-0.08,"editable number height takes effect")
eq(token.buttons[2].position[2],-0.08,"editable Previous arrow height takes effect")
eq(token.buttons[3].position[2],-0.08,"editable Next arrow height takes effect")
unitHistory.tokenButtonY.native=-0.12
unitHistoryRefreshToken("u1")
unitHistoryPrevious(token,"Red")
eq(unitHistorySelectedNumber("u1"),1,"previous selects old use")
eq(unitHistorySelected("u1"),first,"old choices editable")
eq(#token.buttons,2,"number hidden when cycling back to first use")
eq(token.buttons[1].label,"<","previous arrow remains")
eq(token.buttons[2].label,">","next arrow remains")
unitHistoryNext(token,"Red")
eq(unitHistorySelectedNumber("u1"),2,"next returns to latest")
eq(#token.buttons,3,"number returns when cycling to second use")
eq(token.buttons[1].label,"2","second use number restored")
unitHistoryUndoLatest("u1")
eq(#token.buttons,0,"number and arrows cleared after undoing second use")
eq(#unitHistoryUses("u1"),1,"undo latest preserves first use")
eq(gStates.unitReadyLinks.card.usedBy,nil,"ready card reusable after undo")
eq(gStates.unitResourceActivations.u1,first,"live entry restored")
local third={seatPos=1,tokenGUID="cmd",choice=3}
unitHistoryAppend("u1",third,"card")
eq(token.buttons[1].label,"2","restarted second use shows plain number")
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
eq(unitHistoryAppend(nil,{tokenGUID="cmd"},"card"),nil,
    "missing Unit GUID does not dereference a nil history")
-- Official starting cards enforce the level of the currently chosen side.
-- Both an initial illegal target and an existing Ready invalidated by a
-- power change must be rejected without keeping the dependent activation.
object("u2")
unitHistoryReset()
unitHistoryEnsure("u2",{seatPos=1,tokenGUID="cmd",choice=1})
eq(unitHistoryReadyLink("card","u2",1,2),false,
    "basic Rejuvenate cannot ready a Level III Unit")
eq(unitHistoryReadyLink("card","u2",1,3),true,
    "powered Rejuvenate may ready a Level III Unit")
resourceCardsReadySourceLevelLimit=function() return 2 end
eq(unitHistoryValidSources(1),true,
    "losing powered Rejuvenate invalidates its Level III Ready")
eq(gStates.unitReadyLinks.card,nil,"ineligible Level III Ready link removed")
resourceCardsReadySourceLevelLimit=nil

-- Influence-paid Ready sources must fail before mutating history if the
-- remaining Influence does not cover the chosen Unit.
unitHistoryReset()
unitHistoryEnsure("u1",{seatPos=1,tokenGUID="cmd",choice=1})
resourceCardsReadyTargetEligible=function() return false end
eq(unitHistoryReadyLink("card","u1",1,2),false,
    "unpaid Ruthless Coercion Ready cannot create an activation")
eq(gStates.unitReadyLinks.card,nil,"no unpaid Ready link created")
resourceCardsReadyTargetEligible=function() return true end
eq(unitHistoryReadyLink("card","u1",1,2),true,
    "paid Ready can be linked")
unitHistoryCancelReadySource("card")
eq(gStates.unitReadyLinks.card,nil,"paid Ready can be undone")
resourceCardsReadyTargetEligible=nil
unitHistoryReset()

-- A Command spent on a PREVIOUS turn stays exhausted even though the
-- current-turn activation table was cleared. Ready may create a second use
-- without resurrecting the earlier turn's Attack or Block contribution.
local spentCommand=true
resourceUnitsCommandSpent=function(guid) return guid=="cmd" and spentCommand end
resourceUnitsSetCommandSpent=function(guid,spent)
    if guid=="cmd" then spentCommand=spent end
end
unitLayoutSnapshot=function() return {commands={token}} end
token.position.y=1.5
gStates.unitResourceActivations={}
eq(unitHistoryReadyLink("card","u1",1,nil),true,
    "Ready can target a Unit spent on a prior turn")
local spent=unitHistoryUses("u1")[1]
eq(spent.priorTurnSpent,true,"earlier turn is recorded as inert spent state")
unitHistoryRestoreCurrent()
eq(gStates.unitResourceActivations.u1,nil,
    "reopening the tracker does not reanimate last turn's ability")
eq(unitHistoryPriorTurnCommandMoved("cmd",1),true,
    "moving spent Command into ready slot records authorisation")
eq(spentCommand,false,"readying frees Command for later turns")
eq(unitHistoryAwaiting("u1"),"card","prior turn Ready is pending")
local newTurnUse={seatPos=1,tokenGUID="cmd",choice=2}
eq(unitHistoryAppend("u1",newTurnUse,"card"),2,
    "readying a previously used Command makes a fresh activation")
eq(unitHistoryCombatConflict("u1",2,abilities,chosen),false,
    "a previous turn cannot consume this turn's combat activation")
eq(gStates.unitResourceActivations.u1,newTurnUse,
    "only the new turn's activation contributes resources")
unitHistoryCancelReadySource("card")
eq(gStates.unitResourceActivations.u1,nil,
    "undoing Ready restores exhausted state, not last turn's resources")
eq(spentCommand,true,"undoing a consumed Ready restores round-long exhaustion")
eq(#unitHistoryUses("u1"),1,"undo retains inert spent anchor")
unitHistoryReset()

-- Undoing an unconsumed Ready must likewise put the exhausted Command back.
spentCommand=true
token.position.y=1.5
eq(unitHistoryReadyLink("card","u1",1,nil),true,"ready link for previously used Unit")
eq(unitHistoryPriorTurnCommandMoved("cmd",1),true,"Ready enters its slot")
eq(spentCommand,false,"unconsumed Ready clears exhaustion")
token.position.y=1
unitHistoryCancelReadySource("card")
eq(spentCommand,true,"cancelled unconsumed Ready restores exhaustion")
unitHistoryReset()
print("Unit activation history tests passed.")
