-- Run from repository root: lua5.2 tools/test-ruthless-coercion.lua
-- Krang's basic recruitment declaration and powered Unit-ready visibility.
local function read(path)
    local f=assert(io.open(path,"r"))
    local s=f:read("*a")
    f:close()
    return s
end

local function section(source,first,last)
    local start=assert(source:find(first,1,true),first.." missing")
    local finish=assert(source:find(last,start+1,true),last.." missing")
    return source:sub(start,finish-1)
end

local function eq(actual,expected,label)
    assert(actual==expected,(label or "Mismatch")..": expected "
        ..tostring(expected)..", got "..tostring(actual))
end

local recognition=read("src/PlayingGame/PlayerBoard/CardRecognition.lua")
local assignments=read("src/PlayingGame/AttackAssignments.lua")
local data=read("src/Data.lua")
local guid="0b90e5"
assert(data:find('["0b90e5"]={cardType="Starting", resourceKey="ruthlessCoercion"',1,true),
    "Krang's card mapping changed")
assert(data:find('ruthlessCoercion={normal={influence=2},powered={influence=6}',1,true),
    "Ruthless Coercion base Influence changed")

local rule={recruitDiscount=2,recruitRepPenalty=-1,
    readyWithInfluence={maxLevel=2,costPerLevel=2}}
local state={turnNumber=1,startingCardSelections={[guid]={}}}
local env={
    gStates=state,combatConfig={},
    gameCards={[guid]={resourceKey="ruthlessCoercion"}},
    cardResourceDefinitions={ruthlessCoercion=rule}
}
setmetatable(env,{__index=_G})
local fameCode=section(recognition,
    "combatConfig.startingCardConditionalFameRep=function()",
    "-- The basic Ruthless Coercion recruitment discount")
local bonusCode=section(recognition,
    "local function resourceCardsRecruitInfluenceBonus(",
    "-- One owner for the pending Fame/Reputation")
local fn=assert(load(fameCode..bonusCode..
    "\nreturn resourceCardsRecruitInfluenceBonus,combatConfig.startingCardConditionalFameRep",
    "Ruthless accounting","t",env))
local bonus,reward=fn()
local basic={complete=true,powered=false,resources={influence=2}}
local powered={complete=true,powered=true,resources={influence=6}}

eq(bonus(guid,rule,basic),0,"Untoggled card has no bonus")
state.startingCardSelections[guid].recruited=true
eq(bonus(guid,rule,basic),2,"Declared recruitment grants two Influence")
eq(bonus(guid,rule,powered),0,"Powered side does not get basic bonus")
eq(bonus(guid,rule,{complete=false,powered=false,resources={influence=2}}),0,
    "Incomplete source grants no bonus")
eq(bonus(guid,rule,{complete=true,powered=false}),0,
    "Missing resources grant no bonus")
local fame,rep=reward()
eq(fame,0,"Recruitment has no Fame")
eq(rep,-1,"Declared recruitment deducts one Reputation")
state.startingCardSelections[guid].recruited=false
eq(select(2,reward()),0,"Unselecting restores Reputation")
eq(bonus(guid,rule,basic),0,"Unselecting removes extra Influence")

-- The bonus must be applied before the resource scan adds the card's
-- contribution to totals, rather than directly changing the Unit offer.
local playedCards=read("src/PlayingGame/PlayerBoard/ResourceTracker/PlayedCardScan.lua")
local bonusCall=assert(playedCards:find(
    "local recruitBonus=resourceCardsRecruitInfluenceBonus(card.guid,rule,result)",1,true))
local addTotals=assert(playedCards:find("addResourceAmounts(result,totals)",bonusCall,true))
assert(addTotals>bonusCall,"Recruitment bonus must precede totals accounting")
assert(playedCards:find("adjusted.influence=(tonumber(adjusted.influence) or 0)+recruitBonus",
    bonusCall,true),"Recruitment bonus must change the card's own Influence")

-- The actual on-card click toggles declaration and requests a recalculation.
local clickCode=section(recognition,
    "function resourceCardsStartingCardControlClicked(",
    "-- Player clicks always replace")
local refreshes=0
local card={guid=guid,is_face_down=false}
env.getObjectFromGUID=function(id) return id==guid and card or nil end
env.cardPosture=function() return "upright" end
env.cardInSeatPlayArea=function() return true end
env.resourceCardsPanelOpen=function() return true end
env.resourceCardsDetailsOpen=function() return true end
env.resourceCardsPlayerCanEdit=function() return true end
env.resourceCardsSourceChanged=function() refreshes=refreshes+1 end
env.turnOrder={{seatPos=1}}
env.resourceCardScanBySeat={[1]={cards={[guid]=basic}}}
assert(load(clickCode.."\nreturn resourceCardsStartingCardControlClicked",
    "Ruthless button click","t",env))()
env.resourceCardsStartingCardControlClicked({color="Red"},"1",
    "ResourceCardChoice_"..guid.."_recruit")
eq(state.startingCardSelections[guid].recruited,true,"First click selects recruitment")
eq(bonus(guid,rule,basic),2,"Click enables extra Influence")
env.resourceCardsStartingCardControlClicked({color="Red"},"1",
    "ResourceCardChoice_"..guid.."_recruit")
eq(state.startingCardSelections[guid].recruited,false,"Second click deselects")
eq(refreshes,2,"Both clicks refresh the resource tracker")
env.resourceCardScanBySeat[1].cards[guid]=powered
env.resourceCardsStartingCardControlClicked({color="Red"},"1",
    "ResourceCardChoice_"..guid.."_recruit")
eq(state.startingCardSelections[guid].recruited,false,
    "Powered side cannot select the basic recruitment effect")

-- Unit eligibility is shared by the Ready button and its target overlays.
local units={}
local priorSpent=false
local hasHistory=false
local eligibleEnv={
    gameCards={u1={level=1},u2={level=2},u3={level=3}},
    unitLayoutResourceState=function() return {units=units} end,
    unitHistoryUses=function() return hasHistory and {{}} or {} end,
    unitLayoutSnapshot=function() return {commands={{guid="cmd"}}} end,
    resourceUnitsCommandSpent=function() return priorSpent end,
    unitLayoutCommandTarget=function() return {guid="u1"} end
}
setmetatable(eligibleEnv,{__index=_G})
local candidateCode=section(assignments,
    "local function readyUnitCandidates(seat,levelLimit)",
    "local function syncReadyUnitButtons()")
local eligible=assert(load(candidateCode..
    "\nreturn attackAssignmentsHasReadyTarget",
    "Ruthless target eligibility","t",eligibleEnv))()
eq(eligible(1,2),false,"No Units means no Ready button")
units={{guid="u1",unit={guid="u1"},ready=true,unwounded=true}}
hasHistory=true
eq(eligible(1,2),false,"Ready Unit is not a spent target")
units[1].ready=false
eq(eligible(1,2),true,"Spent level 1 Unit with history is targetable")
units[1].unwounded=false
eq(eligible(1,2),false,"Wounded Unit is not readyable")
units={{guid="u3",unit={guid="u3"},ready=false,unwounded=true}}
eq(eligible(1,2),false,"Level 3 Unit is ineligible")
units={{guid="u1",unit={guid="u1"},ready=false,unwounded=true}}
hasHistory=false
priorSpent=true
eq(eligible(1,2),true,"Prior-turn spent Unit remains eligible")
priorSpent=false
eq(eligible(1,2),false,"An unrecorded Unit is not a valid target")
assert(read("src/PlayingGame/PlayerBoard/ResourceTracker/CardControls.lua"):find("and (canReadyUnit or readyCount>0) then",1,true),
    "Ready button must hide without targets but remain available for undo")
assert(read("src/PlayingGame/PlayerBoard/ResourceTracker/CardControls.lua"):find('..":READY_ELIGIBLE:"..tostring(canReadyUnit)',1,true),
    "Ready UI signature must respond to changes in Unit eligibility")
print("Ruthless Coercion recruitment and Ready visibility regressions passed")
