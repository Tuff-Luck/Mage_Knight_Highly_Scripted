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
contains(reader,'local perUse=powered and 2 or 1',"Powered Dodge has two target buttons")
contains(reader,'local count=(result.powered and 2 or 1)*(result.repeatCount or 1)',"Both reduction effects always processed")
contains(reader,'local targetX=-44',"Dodge target buttons beside ordinary Attack source")
contains(reader,'local targetY=-12',"Dodge target alignment")
contains(reader,'targetX-withinUse*44',"Powered Dodge targets spaced apart")
contains(reader,'(result.enemyGUID==nil or rule.dodgeAttackSplit==true)',
    "Dodge debuff works independently of an Attack assignment")
contains(reader,'{attackReduce=2},key)',"Each Dodge button creates a separate -2 reduction")
assert(not reader:find('dodgeReductionAmounts',1,true),"No combined Dodge reduction")
assert(not reader:find('resourceCardsDodgeSplitClicked',1,true),"Remove obsolete Dodge mode switch")
assert(not reader:find('dodgeSplitMode',1,true),"Remove obsolete Dodge split state")

-- Exercise combatEffectAdd's actual registration of two reductions on one enemy.
-- Both must have separate IDs; targeting either one at any printed attack
-- must NOT affect the targeting of the other.
local effectStart=assert(combat:find("function combatEffectAdd(",1,true))
local effectSource=combat:sub(effectStart)
local add=assert(load([=[
monsterPugs={}
combatEffectImmune=function() return false end
]=]..effectSource.."\nreturn combatEffectAdd"))()
local dodgeEffects={}
add(dodgeEffects,"enemyA","dodge",{attackReduce=2},"dodge#effect1")
add(dodgeEffects,"enemyA","dodge",{attackReduce=2},"dodge#effect2")
eq(#dodgeEffects.enemyA.attackReductions,2,"Same enemy retains both -2 reductions")
eq(dodgeEffects.enemyA.attackReductions[1].amount,2,"First reduction stays -2")
eq(dodgeEffects.enemyA.attackReductions[2].amount,2,"Second reduction stays -2")
eq(dodgeEffects.enemyA.attackReductions[1].id,"dodge","First source ID")
eq(dodgeEffects.enemyA.attackReductions[2].id,"dodge#2","Second independent source ID")
eq(dodgeEffects.enemyA.applied[1].key,"dodge#effect1","First target button")
eq(dodgeEffects.enemyA.applied[2].key,"dodge#effect2","Second target button")
local splitEffects={}
add(splitEffects,"enemyA","dodge",{attackReduce=2},"dodge#effect1")
add(splitEffects,"enemyB","dodge",{attackReduce=2},"dodge#effect2")
eq(#splitEffects.enemyA.attackReductions,1,"Split first enemy has one reduction")
eq(#splitEffects.enemyB.attackReductions,1,"Split second enemy has one reduction")
eq(splitEffects.enemyA.attackReductions[1].amount,2,"Split first enemy -2")
eq(splitEffects.enemyB.attackReductions[1].amount,2,"Split second enemy -2")
contains(reader,'function resourceCardsConversionClicked',"Conversion UI callback")
contains(combat,'stripAbilities=spec.removeOneAttackAbilities==true',"Chilling Stare marker")
contains(combat,'removeOneAttackAbilities=spec.removeOneAttackAbilities',"Arcane Immunity exception")

-- Evaluate the actual shared-pool allocation helper without TTS.
local conversion=extract(reader,"local function combatConversionReserved(key,amount,field)",
    "local function combatAssignmentSources(seat)")
local setup=[=[
local combatConfig={conversionState={}}
local combatAssignmentState={explicit={},targets={}}
local moveRoles={}
local resourceCardsMoveRole=function(guid) return moveRoles[guid] or "combat" end
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
assert(move==6 and agility.attack==2 and agility.ranged==2)
-- An ordinary enemy target does not reserve Move. Actual Cumbersome and
-- Psychic targets are covered by test-resource-tracker-pool-integrity.lua.
moveRoles["9757b3"]="movement"
agility,move=combatConfig.conversionFor(1,"agility")
assert(move==4 and agility.attack==2 and agility.ranged==1)
moveRoles["9757b3"]=nil

local diplomacy,influence,diplomacyOn=combatConfig.conversionFor(1,"diplomacy")
assert(diplomacyOn and influence==7)
diplomacy.block=7
combatAssignmentState.explicit["878d90"]=true
combatAssignmentState.targets["878d90"]="enemy"
diplomacy,influence=combatConfig.conversionFor(1,"diplomacy")
assert(influence==7 and diplomacy.block==7)
return true
]=]))()
eq(run,true,"Shared per-point pools and phase-aware Move")

-- The actual attack-selection engine must strip only the chosen attack's
-- offensive abilities, without replacing the attack's Fire/Ice element.
local reductionHelpers=extract(reader,
    "-- An Attack reduction modifies one printed Attack",
    "local function combatEnemyAttacks(entry,includeCancelled)")
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

-- Two reductions on the same enemy may be directed to the SAME printed
-- attack (-4 total), or to DIFFERENT printed attacks (-2 to each).
local original={{value=5,key="F",owner="enemyA"},
    {value=4,key="I",owner="enemyA"}}
local function cloneAttacks()
    local copy={}
    for i,entry in ipairs(original) do
        copy[i]={value=entry.value,key=entry.key,owner=entry.owner}
    end
    return copy
end
local onSame=cloneAttacks()
strip(onSame,dodgeEffects.enemyA,"enemyA",{dodge=1,["dodge#2"]=1})
eq(onSame[1].value,1,"Two Dodge reductions on Fire Attack 5 become 1")
eq(onSame[2].value,4,"Ice Attack 4 remains unchanged")
local onDifferent=cloneAttacks()
strip(onDifferent,dodgeEffects.enemyA,"enemyA",{dodge=1,["dodge#2"]=2})
eq(onDifferent[1].value,3,"First Dodge reduction on Fire Attack 5")
eq(onDifferent[2].value,2,"Second Dodge reduction on Ice Attack 4")

-- Default auto-targeting still works without an attack-cycle selection.
local auto=cloneAttacks()
strip(auto,dodgeEffects.enemyA,"enemyA",nil)
eq(auto[1].value+auto[2].value,5,"Two independent Dodge reductions total -4")
print("White Advanced Actions: regression checks passed")
