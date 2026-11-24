-- Green Spell regression checks (base/Lost Legion; no Forgemaster).
-- Run from repository root: lua5.2 tools/test-green-spells.lua
local function read(path)
    local f=assert(io.open(path,"r"))
    local s=f:read("*a")
    f:close()
    return s
end
local function between(s,first,last)
    local i=assert(s:find(first,1,true),"Missing "..first)
    local j=assert(s:find(last,i+#first,true),"Missing "..last)
    return s:sub(i,j-1)
end
local function eq(actual,expected,label)
    assert(actual==expected,(label or "Mismatch")..": expected "..tostring(expected)
        ..", got "..tostring(actual))
end
local data=read("src/Data.lua")
local reader=read("src/PlayingGame/PlayerBoard/CardRecognition.lua")
local spells=assert(load("return {\n"..between(data,
    "    -- Spell resources are independent","    -- Full-size Artifacts use a saved Break toggle").."\n}"))()

-- Cure's basic Heal is available without waiting for a Wound draw; the
-- optional per-hand-Wound draw is a confirmed action, not automatic resources.
local cure=spells.spellCure
eq(cure.normal.healing,2,"Cure basic Heal 2")
eq(cure.poweredChoices[1].key,"other","Disease is not extra Heal")
eq(cure.enemyEffect.powered.armourSetIfBlocked,1,"Disease sets Armour to 1")
eq(cure.enemyEffect.powered.all,true,"Disease applies across the encounter")
assert(reader:find('local limit=enemy.effect~=nil and enemy.effect.armourSetIfBlocked or nil',1,true),
    "Disease must be resolved using the blocked-attack result")
assert(reader:find('combatConfig.refreshCureDrawButton(card,',1,true),
    "Cure offers its separate confirmed draw")
local cureLogic=between(reader,"function resourceCardsCureCanDraw(color)",
    "local function resourceCardsDetailsOpen()")
local testCure=assert(load([[
local enabled=true
local record={complete=true,powered=false,resources={healing=2}}
local resourceCardScanBySeat={[1]={cards={["47e71c"]=record}}}
local gStates={turnNumber=1}
local turnOrder={{seatPos=1}}
local function resourceCardsPanelOpen() return enabled end
local function resourceCardsPlayerCanEdit(color) return color=="Blue" end
]]..cureLogic..[[
return {allowed=resourceCardsCureCanDraw,record=record,scan=resourceCardScanBySeat,
    disable=function() enabled=false end,
    enable=function() enabled=true end}
]]))()
eq(testCure.allowed("Blue"),true,"Paid basic Cure offers a draw")
eq(testCure.allowed("Red"),false,"Other player cannot claim Cure draws")
testCure.record.powered=true
eq(testCure.allowed("Blue"),false,"Disease never offers Cure draws")
testCure.record.powered=false
testCure.record.complete=false
eq(testCure.allowed("Blue"),false,"Unpaid Cure cannot draw")
testCure.record.complete=true
testCure.record.resources={}
eq(testCure.allowed("Blue"),false,"Cure must actually Heal")
testCure.record.resources.healing=2
testCure.scan[1].cards["47e71c"]=nil
eq(testCure.allowed("Blue"),false,"Removed Cure cancels drawing")
testCure.scan[1].cards["47e71c"]=testCure.record
testCure.disable()
eq(testCure.allowed("Blue"),false,"Closed tracker disables draw UI")

-- Restoration/Rebirth: base 3 Heal, 5 in Forest, with no fabricated
-- Unit readying. The physical Unit history handles actual ready actions.
local restoration=spells.spellRestoration
eq(restoration.normal.healing,3,"Restoration Heal 3")
eq(restoration.powered.healing,3,"Rebirth Heal 3")
eq(restoration.forestHealing,5,"Forest Heal 5")
assert(reader:find('if currentSpellTerrain()=="forest" then',1,true),
    "Forest modifier uses current Hero terrain")
assert(reader:find('updated.healing=rule.forestHealing',1,true),
    "Forest Heal must replace, not add to, the basic value")

-- Tremor/Earthquake: resolve each option through the production effect
-- descriptor and actual enemy-effect aggregation (not copied constants).
gStates={monsterPerks={}}
monsterPugs={
    plain={name="Plain"},
    fortified={name="Fortified",fortified=true},
    immune={name="Immune",arcaneImmunity=true}
}
dofile("src/PlayingGame/PlayerBoard/CombatEffects.lua")
local tremor=spells.spellTremor
local function apply(powered,choice,target)
    local spec=assert(combatEffectSpec(tremor,powered,choice),
        "Missing Tremor choice "..choice)
    local effects={}
    combatEffectAdd(effects,target,"2eb8d1",spec)
    return effects[target],spec
end
local hit,spec=apply(false,"single","plain")
eq(hit.armourReduce,3,"Tremor reduces one enemy by 3")
eq(spec.all,nil,"Single Tremor is independently targeted")
hit,spec=apply(false,"all","plain")
eq(hit.armourReduce,2,"Tremor reduces all by 2")
eq(spec.all,true,"All Tremor is encounter-wide")
hit,spec=apply(true,"single","fortified")
eq(hit.armourReduce,3,"Earthquake base reduction")
eq(hit.armourReduceFortified,6,"Earthquake Fortified reduction")
eq(spec.armourBeforeFortificationRemoval,nil,"Default Earthquake uses current fortification")
hit=apply(true,"singleBefore","fortified")
eq(hit.armourBeforeFortificationRemoval,3,
    "Explicit first Earthquake preserves Fortified bonus")
hit,spec=apply(true,"allBefore","fortified")
eq(spec.all,true,"All-first Earthquake targets every enemy")
eq(hit.armourReduceFortified,4,"All-first Earthquake Fortified reduction")
eq(hit.armourBeforeFortificationRemoval,2,"All-first Earthquake timing")
hit=apply(false,"single","immune")
eq(hit.armourReduce,0,"Arcane Immunity negates Tremor")
eq(hit.immuneIgnored,true,"Tremor immunity reason recorded")

local disease=assert(combatEffectSpec(cure,true,"other"),
    "Disease must have an effect descriptor")
local diseaseEffects={}
combatEffectAdd(diseaseEffects,"plain","47e71c",disease)
eq(diseaseEffects.plain.armourSetIfBlocked,1,"Disease armour cap stored")
eq(diseaseEffects.plain.noAttack,false,"Disease does not erase enemy attack")
combatEffectAdd(diseaseEffects,"immune","47e71c",disease)
eq(diseaseEffects.immune.armourSetIfBlocked,nil,"Arcane Immunity negates Disease")

-- Underground Attack is a paid, non-numeric assault effect. It shares
-- Demolish's site-only bypass, but only on the stronger side.
local underground=spells.spellUnderground
eq(underground.ignoreSiteFortification,true,"Underground Attack site bypass")
eq(underground.ignoreSiteFortificationPowered,true,"Bypass requires stronger side")
local siteBypassCheck=assert(load([[
local function cardPosture(card) return card.posture end
]]..between(reader,"local function resourceCardsIgnoreSiteFortification(rule,result,card)",
    "-- Ambush can augment exactly one played card")..
    "\nreturn resourceCardsIgnoreSiteFortification"))()
local played={posture="upright",is_face_down=false}
local result={complete=true,powered=true,resources={}}
eq(siteBypassCheck(underground,result,played),true,"Paid Underground Attack bypass")
result.powered=false
eq(siteBypassCheck(underground,result,played),false,"Basic Underground Travel has no bypass")
result.powered=true
result.complete=false
eq(siteBypassCheck(underground,result,played),false,"Unpaid Underground Attack has no bypass")
result.complete=true
result.resources=nil
eq(siteBypassCheck(underground,result,played),false,"Missing paid resources disable bypass")
result.resources={}
played.posture="discard"
eq(siteBypassCheck(underground,result,played),false,"Discarded Underground Attack is inactive")
played.posture="upright"
played.is_face_down=true
eq(siteBypassCheck(underground,result,played),false,"Facedown Underground Attack is inactive")
played.is_face_down=false
eq(siteBypassCheck(underground,result,nil),false,"Removed Underground Attack is inactive")
result.powered=false
eq(siteBypassCheck(spells.spellDemolish,result,played),true,"Demolish keeps basic bypass")
result.powered=true
eq(siteBypassCheck(spells.spellDemolish,result,played),false,"Disintegrate has no bypass")

-- Exercise the calculator's actual stripping logic (not an invented rule).
local fortificationCount=assert(load([[
local function combatEnemyHasTrait(data,perks,key)
    return data[key]==true or (perks~=nil and perks[key]==true)
end
]]..between(reader,"local function combatEnemyFortificationCount(data,perks)",
    "-- owner/slot identify the physical token")..
    "\nreturn combatEnemyFortificationCount"))()
local stripSites=assert(load("return function(entries,seatScan)\n"..
    between(reader,"    -- Ignore site/wall Fortified, but preserve the monster's printed Fortified.",
        "    for _,entry in ipairs(entries) do\n        local obj=getObjectFromGUID")..
    "\nreturn entries\nend"))()
local sitePerks={fortified=true,wallFortified=true}
local entry={data={arcaneImmunity=true},perks=sitePerks}
eq(fortificationCount(entry.data,entry.perks),2,"Site and Wall are two fortifications")
stripSites({entry},{ignoreSiteFortifications=true})
eq(fortificationCount(entry.data,entry.perks),0,"Both site fortifications bypassed")
eq(sitePerks.fortified,true,"Bypass never mutates original site perks")
entry={data={fortified=true},perks=sitePerks}
stripSites({entry},{ignoreSiteFortifications=true})
eq(fortificationCount(entry.data,entry.perks),1,"Printed Fortified survives bypass")
local earthquakeSpec=combatEffectSpec(spells.spellTremor,true,"single")
eq(earthquakeSpec.armourReduce,3,"Earthquake uses base reduction without Fortified")
eq(earthquakeSpec.armourReduceFortified,6,"Printed Fortified still qualifies for Earthquake")
entry={data={},perks={fortified=true}}
stripSites({entry},{ignoreSiteFortifications=false})
eq(fortificationCount(entry.data,entry.perks),1,"Without bypass site stays fortified")

-- The real Ranged/Siege grouping must change along with Fortification counts.
-- Stub only attack summation, keeping the production phase eligibility rules.
local rangeResult=assert(load([[
return function(count)
    local combatEnemyFortificationCount=count
    local function combatEnemyHasTrait(data,perks,key)
        return data[key]==true or (perks~=nil and perks[key]==true)
    end
    local function combatAttackTotal(groups)
        local total=0
        for _,group in ipairs(groups) do
            for _,source in ipairs(group.sources) do
                total=total+(tonumber(source[group.category]) or 0)
            end
        end
        return total
    end
]]..between(reader,"local function combatRangeResult(entry,sources)",
    "-- Block cells hold block")..[[
    return combatRangeResult
end]]))()(fortificationCount)
local attacks={{ranged=6,siege=4}}
entry={data={},perks={fortified=true,wallFortified=true},baseArmour=5}
local total,_,_,layers=rangeResult(entry,attacks)
eq(layers,2,"A site behind a Wall is doubly fortified")
eq(total,0,"Neither Ranged nor Siege can hit twice-fortified enemy")
stripSites({entry},{ignoreSiteFortifications=true})
total,_,_,layers=rangeResult(entry,attacks)
eq(layers,0,"Underground Attack bypasses site and Wall")
eq(total,10,"Ranged and Siege both work after bypass")
entry={data={fortified=true},perks={fortified=true,wallFortified=true},baseArmour=5}
stripSites({entry},{ignoreSiteFortifications=true})
total,_,_,layers=rangeResult(entry,attacks)
eq(layers,1,"Innate Fortification still applies")
eq(total,4,"Only Siege works against printed Fortified")

assert(reader:find("if resourceCardsIgnoreSiteFortification(rule,result,card) then",1,true),
    "Scanner must activate site bypass only when physically played")
assert(reader:find("ignoreSiteFortifications=ignoreSiteFortifications",1,true),
    "Calculator must receive site-bypass state")

-- Two other non-numeric Green spells remain deliberately manual, with no
-- invented numeric resources.
for _,name in ipairs({"Energy Flow","Meditation"}) do
    assert(data:find('name={"'..name..'",',1,true),
        "Unregistered Green manual Spell "..name)
end
eq(spells.spellUtility.normalChoices[1].key,"other","Manual basic Spell")
eq(spells.spellUtility.poweredChoices[1].key,"other","Manual strong Spell")

print("Green Spell regression checks passed")
