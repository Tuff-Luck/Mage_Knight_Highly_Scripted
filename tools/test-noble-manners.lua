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
assert(recognition:find("resourceCardsSyncInteractionPower(records)\n    local earnedFame",1,true),
    "Live power must be synchronised before Fame/Reputation totals are calculated")
local objectUI=recognition:sub(
    assert(recognition:find("local function showChoiceButtons(",1,true)),
    assert(recognition:find("-- One selected icon in the Unit",1,true))-1)
assert(not objectUI:find("tooltip%s*="),
    "Card Object UI should not create upside-down tooltips")
for _,path in ipairs({
    "src/PlayingGame/PlayerBoard/UnitHistory.lua",
    "src/PlayingGame/AttackAssignments.lua",
    "src/PlayingGame/Combat.lua"
}) do
    assert(not read(path):find("tooltip%s*="),
        path.." should not create object-attached tooltips")
end
assert(read("src/UI/MainGame.xml"):find("tooltip=",1,true),
    "Global UI tooltips must remain available")
print("Noble Manners and object UI tooltip regressions passed")
