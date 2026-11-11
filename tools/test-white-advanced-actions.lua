-- White Advanced Actions: base/Lost Legion rules only (no Forgemaster).
-- Run from repo root: lua5.2 tools/test-white-advanced-actions.lua
local function source(path)
    local f=assert(io.open(path,"r"))
    local text=f:read("*a")
    f:close()
    return text
end
local function eq(actual,expected,label)
    assert(actual==expected,
        tostring(label)..": expected "..tostring(expected)..", got "..tostring(actual))
end
local function contains(s,needle,label)
    assert(s:find(needle,1,true),label or ("Missing: "..needle))
end
local function extract(s,first,last)
    local from=assert(s:find(first,1,true),first)
    local finish=assert(s:find(last,from+1,true),last)
    return s:sub(from,finish-1)
end

local data=source("src/Data.lua")
local reader=source("src/PlayingGame/PlayerBoard/CardRecognition.lua")
local combat=source("src/PlayingGame/PlayerBoard/CombatEffects.lua")
contains(data,'combatConversion="agility"',"Agility shared Move rule")
contains(data,'combatConversion="diplomacy"',"Diplomacy shared Influence rule")
contains(data,'dodgeAttackSplit=true',"Dodge powered split")
contains(data,'conditionalAttackNoWounds=true',"Dodge Wound condition")
contains(data,'removeOneAttackAbilities=true',"Chilling Stare one attack")
contains(reader,'source.dodgeIneligible=true',"Dodge Attack suppression")
contains(reader,'card.guid.."#effect"..index',"Dodge independent effect keys")
contains(reader,'source.convertedResource',"Conversion resource source")
contains(reader,'combatConfig.dodgeSplitMode[card.guid]',"Dodge split mode")
contains(reader,'function resourceCardsConversionClicked',"Conversion UI callback")
contains(combat,'stripAbilities=spec.removeOneAttackAbilities==true',"Chilling Stare marker")
contains(combat,'removeOneAttackAbilities=spec.removeOneAttackAbilities',"Arcane Immunity exception")

-- Evaluate the actual shared-pool allocation helper without TTS.
local conversion=extract(reader,"combatConfig.conversionFor=function",
    "local function combatAssignmentSources(seat)")
local setup=[=[
local combatConfig={conversionState={}}
local combatAssignmentState={explicit={},targets={}}
local resourceCardScanBySeat={[1]={cards={
    ["878d92"]={combatConversion="agility",resources={move=4}},
    ["9757b3"]={resources={move=2}},
    ["8c3de6"]={combatConversion="diplomacy",powered=true,resources={influence=4}},
    ["878d90"]={resources={influence=3}}
}}}
]=]
local run=assert(load(setup..conversion..[=[
local agility,move,agilityOn=combatConfig.conversionFor(1,"agility")
assert(agilityOn and move==6)
agility.attack=2
agility.ranged=2
agility,move=combatConfig.conversionFor(1,"agility")
assert(move==6 and agility.attack==2 and agility.ranged==2)
combatAssignmentState.explicit["9757b3"]=true
combatAssignmentState.targets["9757b3"]="enemy"
agility,move=combatConfig.conversionFor(1,"agility")
assert(move==4 and agility.attack==2 and agility.ranged==1)

local diplomacy,influence,diplomacyOn=combatConfig.conversionFor(1,"diplomacy")
assert(diplomacyOn and influence==7)
diplomacy.block=7
combatAssignmentState.explicit["878d90"]=true
combatAssignmentState.targets["878d90"]="enemy"
diplomacy,influence=combatConfig.conversionFor(1,"diplomacy")
assert(influence==4 and diplomacy.block==4)
return true
]=]))()
eq(run,true,"Shared pool reservations/clamping")

-- The actual attack-selection engine must strip only the chosen attack's
-- offensive abilities, without replacing the attack's Fire/Ice element.
local reductionHelpers=extract(reader,
    "-- An Attack reduction modifies one printed Attack",
    "local function combatEnemyAttacks(entry)")
local strip=assert(load(reductionHelpers.."\nreturn combatApplyAttackReductions"))()
local attacks={
    {value=5,key="F",owner="enemy",brutal=true,swift=true},
    {value=4,key="I",owner="enemy",poison=true,cumbersome=true}}
strip(attacks,{attackReductions={{id="chilling",source="chilling",
    stripAbilities=true,amount=0}}},"enemy",{chilling=2})
eq(attacks[1].brutal,true,"Other attack unchanged")
eq(attacks[1].swift,true,"Other attack still Swift")
eq(attacks[2].value,4,"Chosen attack strength unchanged")
eq(attacks[2].key,"I","Chosen attack element unchanged")
eq(attacks[2].poison,false,"Chosen attack Poison removed")
eq(attacks[2].cumbersome,false,"Chosen attack Cumbersome removed")

local two={
    {value=5,key="P",owner="enemy"},
    {value=4,key="P",owner="enemy"}}
strip(two,{attackReductions={
    {id="dodge",source="dodge",amount=2},
    {id="dodge#2",source="dodge",amount=2}
}},"enemy",{dodge=1,["dodge#2"]=2})
eq(two[1].value,3,"First split Dodge reduction")
eq(two[2].value,2,"Second split Dodge reduction")
print("White Advanced Actions: regression checks passed")
