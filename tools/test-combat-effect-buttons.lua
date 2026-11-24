-- Shared combat effect buttons are presentation/targeting controls, not points.
-- Run from repository root: lua5.2 tools/test-combat-effect-buttons.lua
local function eq(actual,expected,message)
    if actual~=expected then error((message or "Mismatch")..": expected "..
        tostring(expected)..", got "..tostring(actual),2) end
end
local function source(path)
    local handle=assert(io.open(path,"r"))
    local text=handle:read("*a")
    handle:close()
    return text
end
local function slice(text,beginning,ending)
    local a=assert(text:find(beginning,1,true),"missing "..beginning)
    local b=assert(text:find(ending,a+#beginning,true),"missing "..ending)
    return text:sub(a,b-1)
end

gStates={monsterPerks={}}
monsterPugs={enemy={name="Target"},immune={name="Immune",arcaneImmunity=true}}
dofile("src/PlayingGame/PlayerBoard/CombatEffects.lua")
local effects={}
combatEffectAdd(effects,"enemy","6a33c1",{armourReduce=1})
eq(#effects.enemy.applied,1,"one targeted effect descriptor")
eq(effects.enemy.applied[1].key,"6a33c1","skill source key")
combatEffectAdd(effects,"enemy","unit",{attackReduce=2},"unit#effect2")
eq(effects.enemy.applied[2].key,"unit#effect2","unit ability source key")
eq(effects.enemy.applied[2].source,"unit","unit damage source still tracks physical Unit")
combatEffectAdd(effects,"immune","6a33c1",{armourReduce=1})
eq(effects.immune.applied[1].effective.armourReduce,nil,"Arcane Immunity removes Armour effect")
eq(effects.immune.applied[1].spec.armourReduce,1,"Original spec remains for UI tooltip")
-- Exercise the shared classifier on requested (not effective) effects and
-- independent keys from cards, Units, Skills and Faction Rewards.
eq(combatEffectArrowKind({armourReduce=2,attackReduce=1}),"other","Shocktroops / Freezers")
eq(combatEffectArrowKind({removeFortify=true,removeResist=true}),"other","Expose / Delphana Masters")
eq(combatEffectArrowKind({attackReduce=2}),"other","Dodge / Curse")
eq(combatEffectArrowKind({noAttackUnfortified=true}),"other","Illusionists")
eq(combatEffectArrowKind({noAttack=true,moveCost=2,insufficientMove=true}),"other","Wings of Night")
eq(combatEffectArrowKind({cancelOneAttack=true}),"other","Attached Fear")
eq(combatEffectArrowKind({noAttack=true,maxTargets=3}),"other","Full Fear")
local kinds,defence=combatEffectArrowKinds({
    curse={enemyEffectTargetKeys={"6a33c1"}},
    unit={enemyEffectTargetKeys={"unit#effect2"}},
    bolt={enemyEffectTargetKeys={"bolt#explosiveAttack"}},
    mitigation={enemyEffectTargetKeys={"mitigation"},enemyEffectTargetGUIDs={mitigation="enemy"}},
    unresolved={enemyEffectTargetKeys={"unresolved"}}
},effects)
eq(kinds["6a33c1"],"other","Immune target keeps special-effect colour")
eq(kinds["unit#effect2"],"other","Independent Unit effect colour")
eq(kinds["bolt#explosiveAttack"],"other","Calculated Explosive Bolt")
eq(kinds.mitigation,"other","Damage mitigation fallback")
eq(kinds.ordinary,nil,"Ordinary numeric resource not overridden")
eq(kinds.unresolved,nil,"Unresolved effect does not override numeric resource colour")
eq(defence["6a33c1"],true,"Armour reduction requires a defensive target")
eq(defence["unit#effect2"],false,"Attack reduction can target a reminder")
eq(defence["bolt#explosiveAttack"],true,"Explosive Bolt requires Armour")
eq(combatEffectRequiresDefence({noAttack=true}),false,"Attack prevention can target a reminder")
local all={}
combatEffectAdd(all,"enemy","group",{armourReduce=2,all=true})
eq(#all.enemy.applied,0,"Global effects do not create individually retargetable icons")

-- Load the same production descriptor functions used by the Combat Calculator,
-- with deterministic stubs for the physical objects and enemy attacks.
combatConfig={}
skillResourceDefinitions={["0688d8"]={damageMitigation={physical=2,nonphysical=1}}}
combatEnemyFortificationCount=function(data) return data.fortified and 1 or 0 end
combatEnemyHasTrait=function(data,perks,trait) return data[trait]==true end
combatEnemyAttacks=function(entry)
    if entry.noAttack or entry.destroyed then return {} end
    local value=entry.data.attackValue or 0
    for _,reduction in ipairs(entry.effect~=nil and entry.effect.attackReductions or {}) do
        value=math.max(0,value-reduction.amount)
    end
    return {{value=value,key="P",owner=entry.guid,slot=1}}
end
combatEnemyPrintedAttacks=function(data) return {{value=data.attackValue or 0}} end
getObjectFromGUID=function(guid) return {getName=function() return guid end} end
joinLangEnglish=function(s) return s end
local cardRecognition=source("src/PlayingGame/PlayerBoard/CardRecognition.lua")
assert(load(slice(cardRecognition,"combatConfig.effectButtonInfo=function(entry,applied)",
    "-- Attack-phase eligibility comes from the preceding damage phase")))()
local spec={armourReduce=1,armourReduceRangedUnfortifiedOnly=1}
local normal={source="6a33c1",key="6a33c1",spec=spec,effective=spec}
local enemy={guid="enemy",data={attackValue=3},unmodifiedArmour=3,
    effectArmourReduction=1,effect={armourReduce=1,attackReductions={}}}
local icon=combatConfig.effectButtonInfo(enemy,normal)
eq(icon.family,"range","Armour effect in unfortified Ranged/Siege")
eq(icon.arrow,"other","Calculator Armour reduction is purple")
eq(icon.requiresDefence,true,"Armour reduction cannot target reminders")
eq(icon.icon,"MKChoiceArmourReduction","Armour reduction icon")
eq(icon.ineffective,false,"Armour reduction has benefit")
eq(icon.amount,"-1","Armour badge value")
enemy.data.fortified=true
icon=combatConfig.effectButtonInfo(enemy,normal)
eq(icon.family,"attack","Fortified Armour reduction moves to Attack")
eq(icon.ineffective,false,"Fortified enemy still loses Armour in Attack")
assert(icon.tooltip:find("Attack phase only",1,true),"Fortification timing in tooltip")
enemy.data.fortified=false
enemy.unmodifiedArmour=1
icon=combatConfig.effectButtonInfo(enemy,normal)
eq(icon.ineffective,true,"Armour already at minimum shows red")
assert(icon.tooltip:find("minimum",1,true),"Minimum Armour tooltip")

enemy.unmodifiedArmour=3
local attackEffect={attackReduce=1}
local attackApplication={source="6a33c1",key="6a33c1",spec=attackEffect,effective=attackEffect}
enemy.effect={attackReductions={{amount=1,source="6a33c1"}}}
icon=combatConfig.effectButtonInfo(enemy,attackApplication)
eq(icon.family,"block","Enemy Attack reduction in Block column")
eq(icon.arrow,"other","Calculator Attack reduction is purple")
eq(icon.requiresDefence,false,"Attack reduction can target reminders")
eq(icon.icon,"MKChoiceAttackReduction","Attack reduction icon")
eq(icon.ineffective,false,"Actual enemy Attack reduced")
enemy.data.attackValue=0
icon=combatConfig.effectButtonInfo(enemy,attackApplication)
eq(icon.ineffective,true,"No attack available shows red")
assert(icon.tooltip:find("already at 0",1,true),"Unusable Attack reduction tooltip")

enemy.data.attackValue=3
enemy.unmodifiedArmour=4
enemy.effectArmourReduction=0
local immuneApplication={source="6a33c1",key="6a33c1",spec=spec,
    effective={attackReduce=nil},immune=true}
icon=combatConfig.effectButtonInfo(enemy,immuneApplication)
eq(icon.ineffective,true,"Arcane Immune target shows red")
assert(icon.tooltip:find("Arcane Immunity",1,true),"Arcane Immunity tooltip")

local record={enemyGUID="enemy"}
local mitigation={owner="enemy",appliedKey="enemy:1",used=true}
local results={["enemy:1"]={prevented=1}}
icon=combatConfig.mitigationButtonInfo("0688d8",record,enemy,
    {rangeDefeated=false,destroyed=false},results,mitigation)
eq(icon.family,"block","Battle Hardened shown under Block")
eq(icon.ineffective,false,"Prevented Hero damage uses gray")
eq(icon.amount,"1","Show actually prevented Hero damage")
results["enemy:1"].prevented=0
icon=combatConfig.mitigationButtonInfo("0688d8",record,enemy,
    {rangeDefeated=false,destroyed=false},results,mitigation)
eq(icon.ineffective,true,"No Hero damage avoided uses red")
assert(icon.tooltip:find("No Hero damage",1,true),"Mitigation tooltip")
record.enemyGUID="other"
eq(combatConfig.mitigationButtonInfo("0688d8",record,enemy,
    {},results,mitigation),nil,"No icon on unassigned enemy")

-- Choice icons use the same registry and preserve explicitly chosen resource icons.
local uiAssets=source("src/PlayingGame/UIAssets.lua")
assert(uiAssets:find("MKChoiceArmourReduction",1,true),"Armour icon registered")
assert(uiAssets:find("MKChoiceAttackReduction",1,true),"Attack icon registered")
assert(uiAssets:find("armourReduction\",\"attackReduction",1,true),"Reduction assets available to Global UI")
local choiceSource=slice(cardRecognition,
    "local function combatReductionChoiceIcon(rule,powered,choice,category)",
    "-- A single selected icon is centred on the object.")
local optionIcon=assert(load(choiceSource.."return combatReductionChoiceIcon"))()
local reductionRule={enemyEffect={normal={{choice="armour",armourReduce=1},
    {choice="attack",attackReduce=1},{choice="neutral",removeFortify=true}}}}
eq(optionIcon(reductionRule,false,{icon="other"},"armour"),"armourReduction",
    "Armour choice receives reduction artwork")
eq(optionIcon(reductionRule,false,{icon="other"},"attack"),"attackReduction",
    "Attack choice receives reduction artwork")
eq(optionIcon(reductionRule,false,{icon="other"},"neutral"),"other",
    "Other effects retain generic artwork")
eq(optionIcon(reductionRule,false,{icon="attack"},"armour"),"attack",
    "Explicit source resource icon takes priority")
local krang=source("src/Data.lua")
assert(krang:find('key="attack",icon="attackReduction"',1,true),
    "Curse Attack option uses new icon")
assert(krang:find('key="armour",icon="armourReduction"',1,true),
    "Curse Armour option uses new icon")

-- Never change the CombatEnemyPanel XML or column widths for effect buttons.
assert(cardRecognition:find("combatConfig.effectSources[item.source.key]",1,true),
    "Effect sources must use the existing assignment maps")
assert(cardRecognition:find("local function combatEffectTargetEligible(spec)",1,true),
    "Effect-only targeting should use the global reminder eligibility rule")
assert(cardRecognition:find('return not effectSource.requiresDefence',1,true),
    "An Armour effect cannot target an attack-only reminder from the table")
assert(cardRecognition:find("combatAssignmentSlotSources[id]=item.source.key",1,true),
    "Effect buttons must use the ordinary clickable resource slots")
assert(cardRecognition:find('(wounded or ineffective) and "rgb(0.90,0.37,0.35)"',1,true),
    "Red must reuse the existing unavailable/Wounded slot background")
assert(cardRecognition:find('selected and "rgb(1,0.75,0.2)" or "rgb(0.85,0.82,0.72)"',1,true),
    "Effective buttons should retain the same neutral gray as resources")
-- A new Attack-phase effect may change the later enemy Armour, but a
-- committed source must not reapply by moving to a different enemy.
local committed={applied={{source="old",key="old",effective={armourReduce=2}}}}
local latest={applied={{source="old",key="old",effective={armourReduce=2}},
    {source="new",key="new",effective={armourReduce=1}}}}
local late=combatEffectPostDamageSpecs(latest,committed,{old=true})
eq(#late,1,"only one new effect appears after Damage")
eq(late[1].source,"new","new source remains eligible for late Attack")
eq(#combatEffectPostDamageSpecs(latest,nil,{old=true,new=true}),0,
    "moving committed sources cannot grant additional effects")
assert(cardRecognition:find("local newEffects=combatEffectPostDamageSpecs",1,true)
    and cardRecognition:find("entry.attackPhaseDestroyed=true",1,true)
    and cardRecognition:find('effectButton.family="attack"',1,true),
    "late effects must modify Attack only, not the committed Damage preview")
print("Combat effect button regressions passed")
