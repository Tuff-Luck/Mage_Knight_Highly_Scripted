-- White Advanced Actions: official card rules and shared Forgemaster card copies.
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
contains(data,'dodgeAttackSplit=true',"Dodge retains independent reduction targets")
contains(data,'normal={attack=1},powered={attack=2}',"Dodge automatic Attack 1 / 2")
contains(data,'conditionalAttackNoWounds=true',"Dodge Wound condition")
assert(not data:find('key="safe"',1,true),"Dodge must not have a Safe option")
assert(not data:find('key="eligible"',1,true),"Dodge must not have an Eligible option")
contains(data,'removeOneAttackAbilities=true',"Chilling Stare one attack")
contains(reader,'source.dodgeIneligible=true',"Dodge Attack suppression")
contains(reader,'dodgeConditional=complete and rule~=nil and rule.conditionalAttackNoWounds==true,',
    "Dodge conditional Attack without card options")
contains(reader,'card.guid.."#effect"..index',"Dodge independent effect keys")
contains(reader,'source.convertedResource',"Conversion resource source")
contains(reader,'local count=powered and 2 or 1',"Powered Dodge has two target buttons")
contains(reader,'local count=result.powered and 2 or 1',"Both reduction effects always processed")
contains(reader,'local targetX=-44',"Dodge target buttons beside ordinary Attack source")
contains(reader,'local targetY=-12',"Dodge target alignment")
contains(reader,'targetX-(index-1)*44',"Powered Dodge targets spaced apart")
contains(reader,'(result.enemyGUID==nil or rule.dodgeAttackSplit==true)',
    "Dodge debuff works independently of an Attack assignment")
contains(reader,'{attackReduce=reduction.amount}',"Stacked Dodge reduction is applied together")
assert(not reader:find('resourceCardsDodgeSplitClicked',1,true),"Remove obsolete Dodge mode switch")
assert(not reader:find('dodgeSplitMode',1,true),"Remove obsolete Dodge split state")

-- Exercise the target grouping function used when applying the effects.
-- Both arrows to one enemy must reduce ONE printed Attack by 4.
local groupSource=extract(reader,"combatConfig.dodgeReductionAmounts=function",
    "combatConfig.conversionState={}")
local group=assert(load("local combatConfig={}\n"..groupSource..
    "\nreturn combatConfig.dodgeReductionAmounts"))()
local same=group({{guid="enemyA",key="dodge#effect1"},
    {guid="enemyA",key="dodge#effect2"}})
eq(same.enemyA.amount,4,"Dodge same-enemy reduction stacks to 4")
eq(same.enemyA.key,"dodge#effect1","Dodge combined reduction retains first key")
local split=group({{guid="enemyA",key="dodge#effect1"},
    {guid="enemyB",key="dodge#effect2"}})
eq(split.enemyA.amount,2,"Dodge split first enemy")
eq(split.enemyB.amount,2,"Dodge split second enemy")
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
