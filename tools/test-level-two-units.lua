-- Level II Unit regressions: Shocktroops' forced damage and Illusionists' Demolish targeting.
-- Run from repository root: lua5.2 tools/test-level-two-units.lua
local function eq(actual,expected,label)
    if actual~=expected then
        error((label or "Mismatch")..": expected "..tostring(expected)
            ..", got "..tostring(actual),2)
    end
end
local function source(path)
    local handle=assert(io.open(path,"r"))
    local content=handle:read("*a")
    handle:close()
    return content
end
local function slice(content,startMarker,endMarker)
    local first=assert(content:find(startMarker,1,true),"missing "..startMarker)
    local last=assert(content:find(endMarker,first+#startMarker,true),"missing "..endMarker)
    return content:sub(first,last-1)
end
local function isolated(content,startMarker,endMarker,name)
    return assert(load(slice(content,startMarker,endMarker).."\nreturn "..name))()
end

local recognition=source("src/PlayingGame/PlayerBoard/CardRecognition.lua")
local assignments=source("src/PlayingGame/AttackAssignments.lua")

-- A forced Unit assignment overrides Assassination; a voluntary one does not.
combatUnitResists=function(unit,attackType)
    return unit.resist~=nil and unit.resist[attackType]==true
end
local resolve=isolated(recognition,"local function combatDamageResolve(",
    "local function combatWoundsText(", "combatDamageResolve")
local function unit(guid)
    return {guid=guid,armour=3,level=2,wounded=false}
end
local function damage(items,units,targets)
    return resolve(items,units,3,function(key) return targets[key] or {} end)
end
local forced=damage({{key="assassin:1",owner="assassin",type="P",damage=5,
    assassination=true,firstDamageUnit="shock"}},
    {shock=unit("shock"),spare=unit("spare")},
    {["assassin:1"]={"spare"}})["assassin:1"]
eq(#forced.units,1,"Assassination forces one Shocktroops assignment")
eq(forced.units[1].unit.guid,"shock","forced recipient is Shocktroops")
eq(forced.units[1].forced,true,"forced flag retained")
eq(forced.unitWounds,1,"Shocktroops takes one Wound")
eq(forced.heroDamage,2,"remaining damage reaches Hero")
eq(forced.heroWounds,1,"Hero receives only remaining damage")
local ordinary=damage({{key="assassin:1",owner="assassin",type="P",
    damage=5,assassination=true}},
    {shock=unit("shock")},{["assassin:1"]={"shock"}})["assassin:1"]
eq(#ordinary.units,0,"ordinary Unit assignment forbidden against Assassination")
eq(ordinary.heroWounds,2,"ordinary Assassination goes entirely to Hero")
local reserved=damage({
    {key="other:1",owner="other",type="P",damage=4},
    {key="assassin:1",owner="assassin",type="P",damage=3,
        assassination=true,firstDamageUnit="shock"}
}, {shock=unit("shock"),spare=unit("spare")},
   {["other:1"]={"shock","spare"}})
eq(reserved["other:1"].units[1].unit.guid,"spare",
    "earlier attack cannot consume reserved Shocktroops")
eq(reserved["assassin:1"].units[1].unit.guid,"shock",
    "Assassination still receives its reserved Shocktroops")

-- The damage arrows and reservations must track forced assignments too.
local arrows=slice(assignments,
    "-- A forced first recipient is also a real damage assignment",
    "if damagePending~=nil then")
assert(arrows:find("if guid~=nil and damageSpec.units[guid]==true then",1,true),
    "Assassination forced arrow must be rendered")
local synchronise=slice(assignments,"function attackAssignmentsDamageSync(spec)",
    "for key,guids in pairs(damageTargets)")
assert(synchronise:find("if guid~=nil and damageSpec.units[guid]==true then",1,true),
    "Shocktroops recipient must be reserved despite Assassination")
local movement=slice(assignments,
    "-- Forced recipients (e.g. Shocktroops) have red arrows",
    "if relevant then")
assert(not movement:find("not attack.assassination",1,true),
    "moving an Assassin or Shocktroops must refresh the forced arrow")
assert(assignments:find("(freeUnit and not attack.assassination)",1,true),
    "unrelated voluntary Unit assignment still disallowed against Assassination")

-- Illusionists must use the same site/wall suppression as the combat calculator.
combatEnemyHasTrait=function(data,perks,key)
    return data[key]==true or (perks~=nil and perks[key]==true)
end
combatEnemyFortificationCount=isolated(recognition,
    "local function combatEnemyFortificationCount(data,perks)",
    "-- owner/slot identify the physical token", "combatEnemyFortificationCount")
local enemyData={}
gStates={monsterPerks={}}
combatEnemyData=function() return enemyData,"enemy" end
combatEffectOf=function() return nil end
assert(load(slice(recognition,
    "function resourceCardsEnemyEffectivelyUnfortified(guid,effects",
    "function resourceCardsCombatTargetRejectMessage(")))()
local function eligible(data,perks,demolish,effect)
    enemyData=data
    gStates.monsterPerks.enemy=perks
    return resourceCardsEnemyEffectivelyUnfortified("enemy",
        effect~=nil and {enemy=effect} or {},demolish)
end
eq(eligible({},nil,false),true,"unfortified enemy targetable normally")
eq(eligible({}, {fortified=true},false),false,
    "site Fortification prevents Illusionists without Demolish")
eq(eligible({}, {fortified=true},true),true,
    "Demolish enables Illusionists against site Fortification")
eq(eligible({}, {wallFortified=true},false),false,
    "Wall Fortification normally prevents Illusionists")
eq(eligible({}, {wallFortified=true},true),true,
    "Demolish also ignores Wall Fortification")
eq(eligible({fortified=true},nil,true),false,
    "Demolish does not ignore printed Fortified")
eq(eligible({fortified=true},{fortified=true},true),false,
    "Demolish preserves printed Fortified when site is also fortified")
eq(eligible({fortified=true},{fortified=true},false,
    {removedPrinted={fortified=true}}),false,
    "removing printed Fortified alone preserves site Fortification")
eq(eligible({fortified=true},{fortified=true},true,
    {removedPrinted={fortified=true}}),true,
    "removing printed Fortified plus Demolish removes both")
eq(eligible({fortified=true},nil,false,{removeFortify=true}),true,
    "explicit Remove Fortification still enables Illusionists")
eq(eligible({attackOnly=true},nil,true),false,
    "attack-only reminders remain ineligible")

-- Both the current scan and manual retargeting must pass Demolish state.
assert(recognition:find("scan~=nil and scan.ignoreSiteFortifications==true",1,true),
    "manual target callback must carry Demolish state")
assert(recognition:find(
    "resourceCardsEnemyEffectivelyUnfortified(guid,enemyEffects,\n                    ignoreSiteFortifications)",1,true),
    "automatic target scan must carry Demolish state")
print("Level II Shocktroops and Illusionists regressions passed")
