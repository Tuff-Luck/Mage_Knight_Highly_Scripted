-- Noble Manners regression: the explicit Interaction choice is retained,
-- but the powered Reputation follows the current mana link on each scan.
-- Run from repository root: lua5.2 tools/test-noble-manners.lua
local function read(path)
    local f=assert(io.open(path,"r"))
    local s=f:read("*a")
    f:close()
    return s
end
local function eq(actual,expected,label)
    assert(actual==expected,(label or "Mismatch")..": expected "
        ..tostring(expected)..", got "..tostring(actual))
end
local recognition=read("src/PlayingGame/PlayerBoard/CardRecognition.lua")
local first=assert(recognition:find(
    "local function resourceCardsSyncInteractionPower(records)",1,true))
local last=assert(recognition:find(
    "-- One owner for the pending Fame/Reputation",first,true))
local section=recognition:sub(first,last-1)
local selected={interaction=true}
local state={startingCardSelections={noble=selected}}
local env={gStates=state,
    gameCards={noble={resourceKey="nobleManners"}},
    cardResourceDefinitions={nobleManners={
        interactionReward={normal={fame=1},powered={fame=1,rep=1}}}},
    combatConfig={}}
setmetatable(env,{__index=_G})
local api=assert(load(section..[[
return resourceCardsSyncInteractionPower,combatConfig.startingCardConditionalFameRep
]],"Noble Manners accounting","t",env))
local sync,reward=api()
local function rewards(fame,rep,label)
    local actualFame,actualRep=reward()
    eq(actualFame,fame,label.." Fame")
    eq(actualRep,rep,label.." Reputation")
end
local records={noble={complete=true,resources={influence=4},powered=true}}
sync(records)
rewards(1,1,"Interaction powered")
records.noble.powered=false
records.noble.resources={influence=2}
sync(records)
rewards(1,0,"Crystal removed, Interaction stays ON")
records.noble.powered=true
sync(records)
rewards(1,1,"Crystal replaced")
-- Dragging the card out temporarily must not silently undo earned rewards.
sync({})
rewards(1,1,"Card temporarily absent")
selected.interaction=false
selected.interactionPowered=nil
sync(records)
rewards(0,0,"Interaction OFF")
assert(read("src/PlayingGame/PlayerBoard/ResourceTracker/Scanning/ScanPublication.lua"):find("resourceCardsSyncInteractionPower(records)\n    local earnedFame",1,true),
    "Live power must be synchronised before Fame/Reputation totals are calculated")
local objectUI=read("src/PlayingGame/PlayerBoard/ResourceTracker/Interface/CardControls.lua")
assert(objectUI:find("local function showChoiceButtons(",1,true))
assert(not objectUI:find("tooltip%s*="),
    "Card Object UI should not create upside-down tooltips")
for _,path in ipairs({
    "src/PlayingGame/PlayerBoard/Units/UnitHistory.lua",
    "src/PlayingGame/Combat/AttackAssignments.lua",
    "src/PlayingGame/Combat/Combat.lua"
}) do
    assert(not read(path):find("tooltip%s*="),
        path.." should not create object-attached tooltips")
end
assert(read("src/UI/MainGame.xml"):find("tooltip=",1,true),
    "Global UI tooltips must remain available")
print("Noble Manners and object UI tooltip regressions passed")

-- Heroic Tale's shared event ledger must survive a disband, count each
-- separate confirmed claim, and support correction for manual recruitment.
local fameSource=read("src/PlayingGame/GameFlow/FameReputation.lua")
local a=assert(fameSource:find("local function unitRecruitmentSeat",1,true))
local b=assert(fameSource:find("--Resource Tracker Fame/Reputation is runtime-only",a,true))
local refreshes=0
local recruits=setmetatable({
    gStates={turnNumber=1},turnOrder={{seatPos=1},{seatPos=2}},
    resourceCardsSourceChanged=function() refreshes=refreshes+1 end
},{__index=_G})
assert(load(fameSource:sub(a,b-1),"Recruitment ledger","t",recruits))()
eq(recruits.unitRecruitmentCount(1),0,"No recruitment at turn start")
eq(recruits.unitRecruitmentRecord(1,"first"),true,"First confirmed recruit")
eq(recruits.unitRecruitmentRecord(1,"second"),true,"Replacement confirmed recruit")
eq(recruits.unitRecruitmentCount(1),2,"Disbanding does not erase the first recruitment")
eq(recruits.unitRecruitmentRecord(2,"wrong"),false,"Ignore another seat's recruitment")
local spec={normal={rep=1},powered={fame=1,rep=1}}
local result=recruits.unitRecruitmentReward(spec,false,2)
eq(result.fame,0,"Basic Heroic Tale Fame")
eq(result.rep,2,"Basic Heroic Tale Reputation per recruit")
result=recruits.unitRecruitmentReward(spec,true,2,2)
eq(result.fame,4,"Copied powered Heroic Tale Fame")
eq(result.rep,4,"Copied powered Heroic Tale Reputation")
eq(recruits.unitRecruitmentAdjust(1,1),true,"Count a manual recruit")
eq(recruits.unitRecruitmentCount(1),3,"Manual count shared across effects")
eq(recruits.unitRecruitmentAdjust(1,-1),true,"Undo manual correction")
eq(recruits.unitRecruitmentCount(1),2,"Count returns to confirmed claims")
eq(refreshes,4,"Refresh only when the ledger changes")
recruits.gStates.preEndTurn=true
eq(recruits.unitRecruitmentRecord(1,"late"),false,"Late transfer cannot contaminate next turn")
print("Recruitment history and Heroic Tale reward regressions passed")
