-- Level IV Unit regressions (base game and Lost Legion).
-- Run from repository root: lua5.2 tools/test-level-four-units.lua
local function eq(actual,expected,label)
    assert(actual==expected,(label or "Mismatch")..": expected "..tostring(expected)
        ..", got "..tostring(actual))
end
local function source(path)
    local file=assert(io.open(path,"r"))
    local text=file:read("*a")
    file:close()
    return text
end
local function slice(text,first,last)
    local a=assert(text:find(first,1,true),"missing "..first)
    local b=assert(text:find(last,a+#first,true),"missing "..last)
    return text:sub(a,b-1)
end

local recognition=source("src/PlayingGame/PlayerBoard/CardRecognition.lua")
local data=source("src/Data.lua")
dofile("src/PlayingGame/PlayerBoard/UnitResources.lua")

-- Each Level IV GUID is registered with its printed ability set.
local mages=unitResourceDefinitions["bb1660"]
local guardians=unitResourceDefinitions["f288ea"]
local delphana=unitResourceDefinitions["9c5c38"]
eq(unitResourceDefinitions["0fe22e"],mages,"second Altem Mages")
eq(unitResourceDefinitions["5726ab"],guardians,"second Altem Guardians")
eq(unitResourceDefinitions["f288e1"],guardians,"third Altem Guardians")
eq(unitResourceDefinitions["5c2da0"],delphana,"second Delphana Masters")
eq(mages[2].attackColdFire,5,"Altem Mages base Attack")
eq(mages[3].blockColdFire,5,"Altem Mages base Block")
eq(mages[4].attackTransform,"coldFire","Black Cold Fire transformation")
eq(mages[5].attackTransform,"siege","Black Siege transformation")
eq(guardians[1].attack,5,"Altem Guardians Attack")
eq(guardians[2].block,8,"Altem Guardians Block")
eq(guardians[2].countsTwiceVsSwift,true,"Altem Guardians Swiftness")
eq(guardians[3].grantUnitResistances,true,"Altem Guardians resistances")
eq(delphana.multi,true,"Delphana Masters multiple paid abilities")
eq(delphana[2].enemyEffect.destroyIfFullyBlocked,true,"Delphana red all-attacks requirement")
eq(delphana[3].enemyEffect.armourReduce,5,"Delphana green Armour reduction")
eq(delphana[4].enemyEffect.removeFortify,true,"Delphana white Fortification")
eq(delphana[4].enemyEffect.removeResist,true,"Delphana white resistances")

-- Normal recruitment is City-only; camp is the Refugee Camp exception.
for _,guid in ipairs({"bb1660","0fe22e"}) do
    local line=assert(data:match('%["'..guid..'"%]=([^\n]+)'),
        "missing Altem Mages recruitment "..guid)
    assert(line:find('recruit={"city", "camp"}',1,true),
        "Altem Mages recruit only in City / Refugee Camp")
    assert(not line:find('"keep"',1,true),"Keep must not recruit Altem Mages")
end

-- Gold counts as one missing basic colour per token only during Day.
local day=true
resourceCardsUsesDayMana=function() return day end
resourceCardsGoldAllowed=function() return day end
resourceCardsBlackAllowed=function() return not day end
local scale=assert(load(slice(recognition,
    "    local function unitManaScaleBonus(counts)",
    "    local function unitAbilityResources(").."\nreturn unitManaScaleBonus"))()
eq(scale({}),0,"unpaid Cold Fire base")
eq(scale({Red=1}),2,"Red +2")
eq(scale({Blue=1}),2,"Blue +2")
eq(scale({Red=1,Blue=1}),4,"Red and Blue +4")
eq(scale({Red=2}),2,"two Reds do not replace Blue")
eq(scale({Gold=1}),2,"one Gold +2")
eq(scale({Gold=2}),4,"two Gold +4")
eq(scale({Red=1,Gold=1}),4,"Red plus Gold +4")
eq(scale({Blue=1,Gold=1}),4,"Blue plus Gold +4")
eq(scale({Red=1,Blue=1,Gold=2}),4,"bonus capped at +4")
day=false
eq(scale({Gold=2}),0,"Gold unusable at Night")
eq(scale({Blue=1,Gold=2}),2,"Night counts only Blue")
assert(recognition:find("bonus=bonus+unitManaScaleBonus(counts)",1,true),
    "live unit resources must use gold-aware bonus")

-- Delphana red is not a Fire Block and does not need its own Block source.
gStates={monsterPerks={}}
monsterPugs={normal={},immune={arcaneImmunity=true}}
dofile("src/PlayingGame/PlayerBoard/CombatEffects.lua")
local effects={}
combatEffectAdd(effects,"normal","9c5c38",delphana[2].enemyEffect,"9c5c38#effect2")
local applied=effects.normal.applied[1]
eq(applied.effective.destroyIfFullyBlocked,true,"red effect retained")
eq(combatEffectDestroysFullyBlocked(applied,true,true),true,
    "all attacks blocked destroys target with other Block sources")
eq(combatEffectDestroysFullyBlocked(applied,false,true),false,
    "one unblocked attack prevents Delphana destruction")
eq(combatEffectDestroysFullyBlocked(applied,true,false),false,
    "an enemy with no attack is not automatically destroyed")
combatEffectAdd(effects,"immune","9c5c38",delphana[2].enemyEffect)
eq(combatEffectDestroysFullyBlocked(effects.immune.applied[1],true,true),false,
    "Arcane Immunity prevents Delphana destruction")
local fireBlock={destroyIfBlocked=true,fireSpell=true}
combatEffectAdd(effects,"normal","spell",fireBlock)
eq(combatEffectDestroysFullyBlocked(effects.normal.applied[2],true,true),false,
    "Spell-specific Block destruction cannot use all-attacks rule")
assert(recognition:find("local _,_,_,allBlocked,_,_,_,successfulSources,successfulOwners=",1,true),
    "combat must use allBlocked result, not a single successful Block")
assert(recognition:find("combatEffectDestroysFullyBlocked(applied,allBlocked,hasAttack)",1,true),
    "red destruction must use full-Block check")
assert(recognition:find("successfulSources[applied.source]==true",1,true),
    "Spell destruction must remain tied to its own Block")
assert(recognition:find("or spec.destroyIfFullyBlocked==true)",1,true),
    "attack-only reminders must not become eligible defensive targets")
assert(recognition:find("Destroy target if all its attacks are successfully Blocked",1,true),
    "Delphana tooltip must describe all-attacks requirement")

-- A Ready then Black transformation must credit use2, not use1; an old
-- transform must not overwrite the currently selected Command highlight.
assert(recognition:find("transformingUnits[recordKey]=selected.attackTransform",1,true),
    "track transform by historical source key")
assert(recognition:find("local record=records[sourceKey]",1,true),
    "attribute transformation contribution to the correct use")
assert(recognition:find("unitHistorySelectedNumber(unitGUID)==record.activationIndex",1,true),
    "do not overwrite another activation's highlight")
print("Level IV Unit regressions passed")
