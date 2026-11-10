-- Regression coverage for Braevalar's combat Skills.
-- Run from repository root: lua5.2 tools/test-braevalar-skills.lua

local function eq(actual, expected, label)
    if actual~=expected then
        error((label or "Mismatch")..": expected "..tostring(expected)
            ..", got "..tostring(actual), 2)
    end
end

local function source(path)
    local file=assert(io.open(path, "r"))
    local contents=file:read("*a")
    file:close()
    return contents
end

local function contains(haystack, needle, label)
    eq(haystack:find(needle, 1, true)~=nil, true, label)
end

local function isolated(text, startMarker, endMarker, returnValue)
    local first=assert(text:find(startMarker, 1, true), startMarker.." not found")
    local last=assert(text:find(endMarker, first+#startMarker, true), endMarker.." not found")
    return assert(load(text:sub(first, last-1).."\nreturn "..returnValue))()
end

local data=source("src/Data.lua")
local recognition=source("src/PlayingGame/PlayerBoard/CardRecognition.lua")
local effects=source("src/PlayingGame/PlayerBoard/CombatEffects.lua")
local assignments=source("src/PlayingGame/AttackAssignments.lua")
local skills=source("src/PlayingGame/PlayerBoard/Skills.lua")

-- Every listed Skill has rule metadata, including the active/competitive pair.
contains(data, '["ae8673"]={damageMitigation={fire=2,ice=2,other=1}}',
    "Elemental Resistance prevention amounts")
contains(data, '["c73c8c"]={choices={{attack=1},{key="other"',
    "Feral Allies Attack/Attack reduction choice")
contains(data, 'enemyEffect={normal={{choice="other",attackReduce=1}}}',
    "Feral Allies effect-only target")
contains(data, '["d01b70"]={forkedLightning=true',
    "Forked Lightning has distinct-source metadata")
contains(data, '["19daf9"]={untracked=true,competitiveBlockBonus=1',
    "Competitive Vengeance registered")
contains(data, '["4ac9f6"]={untracked=true,',
    "Cooperative Vengeance registered")
contains(skills, 'gStates.braevalarVengeanceUse={recipient=gStates.turnNumber',
    "Claimed Vengeance persists through recipient turn")
contains(skills, 'gStates.braevalarVengeanceUse=nil',
    "Claimed Vengeance expires after recipient turn")
contains(assignments, 'pending.sourceGUID~="4ac9f6"',
    "Summoned enemy can be targeted with cooperative Vengeance")
contains(assignments, 'pending.sourceGUID~="19daf9"',
    "Summoned enemy can be targeted with competitive Vengeance")
contains(recognition, 'item.source.forkedLightning',
    "Forked Lightning stays in one phase")
contains(recognition, 'sourceKey:match("^d01b70#fork%d+$")',
    "Forked Lightning duplicate target is forbidden")

-- Arcane Immunity does not stop Attack reduction / granting Cumbersome.
monsterPugs={normal={},immune={arcaneImmunity=true}}
gStates={monsterPerks={},attackedMonsters={}}
assert(loadfile("src/PlayingGame/PlayerBoard/CombatEffects.lua"))()
local tableEffects={}
combatEffectAdd(tableEffects, "normal", "c73c8c", {attackReduce=1})
eq(tableEffects.normal.attackReductions[1].amount,1,
    "Feral Allies reduces one enemy Attack")
combatEffectAdd(tableEffects, "immune", "4ac9f6",
    {attackReduce=1,grantCumbersome=true})
eq(tableEffects.immune.grantCumbersome,true,
    "Nature's Vengeance grants Cumbersome through Arcane Immunity")
eq(tableEffects.immune.attackReductions[1].amount,1,
    "Nature's Vengeance reduces an Arcane-Immune Attack")

-- A Forked Lightning point must choose a different enemy token from other
-- points. Unused bolts are not reassigned to the first enemy.
combatAssignmentState={targets={}}
local points={
    d01b70={0,0,0},a={1,0,0},b={2,0,0},c={3,0,0}
}
getObjectFromGUID=function(guid)
    local pos=points[guid]
    return pos~=nil and {getPosition=function() return pos end} or nil
end
local nearest=isolated(recognition,
    "local function combatNearestEnemyGUID(source,entries)",
    "combatConfig.attackTypes=", "combatNearestEnemyGUID")
local enemies={{guid="a",attackOnly=false},{guid="b",attackOnly=false},
    {guid="c",attackOnly=false}}
for i=1,3 do
    local key="d01b70#fork"..i
    local chosen=nearest({guid="d01b70",key=key,forkedLightning=true,
        ranged=1,siege=0,attack=0},enemies)
    eq(chosen,enemies[i].guid,"Forked Lightning bolt "..i.." goes to distinct enemy")
    combatAssignmentState.targets[key]=chosen
end
eq(nearest({guid="d01b70",key="d01b70#fork4",forkedLightning=true,
    ranged=1,siege=0,attack=0},enemies),nil,
    "Extra bolt cannot target a used enemy")

-- Block-only competitive modifier belongs to active opponents, not the owner.
combatAssignmentActiveSeat=function() return 2 end
gStates.turnNumber=2
gStates.competitiveSkillReminders={
    ["19daf9"]={owner=1,reminders={skillReminder=2}}
}
getObjectFromGUID=function(guid)
    return guid=="skillReminder" and {} or nil
end
local competitive=isolated(recognition,
    "local function combatNatureVengeanceBlockBonus()",
    "local combatBlockResultCache=", "combatNatureVengeanceBlockBonus")
eq(competitive(),1,"Opponent gets +1 to Block requirements")
gStates.turnNumber=1
eq(competitive(),0,"Skill owner never suffers competitive bonus")
gStates.turnNumber=2
gStates.competitiveSkillReminders["19daf9"].reminders={}
eq(competitive(),0,"Expired competitive reminder has no bonus")

-- Damage prevention happens AFTER Unit assignment and Brutal multiplication,
-- is limited to a single attack, and works independently of Battle Hardened.
combatUnitResists=function(unit,typeKey)
    return unit.resist~=nil and unit.resist[typeKey]==true
end
local resolve=isolated(recognition,
    "local function combatDamageResolve(items,units,heroArmour,targetsOf,mitigation,elementMitigation)",
    "local function combatWoundsText(", "combatDamageResolve")
local none=function() return {} end
local function hit(typeKey,damage,mitigation,element)
    local key="e:1"
    local results=resolve({{key=key,owner="e",type=typeKey,damage=damage}},
        {},3,none,mitigation,element)
    return results[key]
end
local resist=function() return {owner="e",attackKey="e:1"} end
local fire=hit("F",5,nil,resist())
eq(fire.elementPrevented,2,"Fire ignores two Hero damage")
eq(fire.heroWounds,1,"Fire prevention changes wound count")
local ice=hit("I",5,nil,resist())
eq(ice.elementPrevented,2,"Ice ignores two Hero damage")
local cold=hit("IF",5,nil,resist())
eq(cold.elementPrevented,1,"Cold Fire ignores only one damage")
local psychic=hit("M",1,nil,resist())
eq(psychic.elementPrevented,1,"Psychic ignores one damage")
eq(psychic.heroWounds,0,"Psychic protection prevents a Wound")
local combined=hit("P",5,{owner="e",physical=2,nonphysical=1},resist())
eq(combined.prevented,2,"Battle Hardened remains separate")
eq(combined.elementPrevented,1,"Elemental Resistance also applies")
local results=resolve({
    {key="e:1",owner="e",type="F",damage=4},
    {key="e:2",owner="e",type="F",damage=4}
}, {},3,none,nil,{owner="e"})
eq(results["e:1"].elementPrevented,2,"First attack is protected")
eq(results["e:2"].elementPrevented,nil,"Skill cannot protect two attacks")
local saved=resolve({
    {key="e:1",owner="e",type="F",damage=3},
    {key="e:2",owner="e",type="F",damage=3}
}, {u={guid="u",name="Unit",armour=3,resist={},wounded=false}},3,
    function(key) return key=="e:1" and {"u"} or {} end,
    nil,{owner="e"})
eq(saved["e:1"].elementPrevented,nil,"Unit damage does not spend Hero safeguard")
eq(saved["e:2"].elementPrevented,2,"Remaining later attack may use it")

print("Braevalar Skills regression checks passed")
