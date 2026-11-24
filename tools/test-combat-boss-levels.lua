-- Regression tests for official Shades of Tezla faction leaders and
-- Apocalypse Dragon head level reductions (no Forgemaster/fan-made content).
-- Run at repository root: lua5.2 tools/test-combat-boss-levels.lua
local function read(path)
    local f=assert(io.open(path,"r"))
    local value=f:read("*a")
    f:close()
    return value
end
local recognition=read("src/PlayingGame/PlayerBoard/CardRecognition.lua")
local combat=read("src/PlayingGame/Combat.lua")
local leaders=read("src/PlayingGame/FactionLeaders.lua")
local dragon=read("src/PlayingGame/ApocalypseDragon.lua")
local ui=read("src/PlayingGame/UI.lua")
local env={gStates={combatBossManual={}}}
local defences=dofile("src/PlayingGame/PlayerBoard/ResourceTracker/Combat/EnemyDefences.lua")({})
local engine=dofile("src/PlayingGame/PlayerBoard/ResourceTracker/Combat/BossAllocation.lua")(defences.hasTrait)
local count=engine.levelCount
local function phase(group,entries,total,kind,blockedAll)
    return engine.phasePlan(group,entries,total,kind,blockedAll,env.gStates.combatBossManual)
end
local function eq(actual,expected,what)
    assert(actual==expected,what..": expected "..tostring(expected)
        ..", got "..tostring(actual))
end
eq(count(0,5,4),0,"No attack")
eq(count(4,5,4),0,"Below Armour")
eq(count(13,5,4),2,"Ranged partial reduction")
eq(count(20,5,4),4,"Ranged complete reduction")
eq(count(80,5,4),4,"Cannot overkill past level zero")
eq(count(7,5,2),1,"Later attack uses remaining levels")
local function boss(guid,armour,level,x)
    return {guid=guid,bossType="dragon",bossLevel=level,
        data={},perks={},baseArmour=armour,elusiveArmour=armour*2,
        rangeBaseArmour=armour,rangeElusiveArmour=armour*2,x=x or 0}
end
local function group(...)
    local out={members={}}
    for i=1,select("#",...) do out.members[i]=i end
    return out
end
local a=boss("aaaaaa",5,4,0)
local result=phase(group(a),{a},13,"range",{})
eq(result.reductions[a.guid],2,"Ranged phase removes two")
eq(result.spent,true,"Ranged resources spent on level reduction")
eq(result.full,false,"Partly reduced boss is alive")
a.bossRangeLevels=2
result=phase(group(a),{a},7,"attack",{})
eq(result.reductions[a.guid],1,"Later phase removes one more")
eq(result.full,false,"One level remains")
result=phase(group(a),{a},13,"attack",{})
eq(result.reductions[a.guid],2,"Can finish surviving levels")
eq(result.full,true,"Final level defeat")

local b=boss("bbbbbb",4,3,1)
a.bossRangeLevels=nil
result=phase(group(a,b),{a,b},22,"range",{})
eq(result.reductions[a.guid],3,"Joined heads share attack budget first")
eq(result.reductions[b.guid],1,"Joined heads both require Armour")
eq(result.full,false,"Both heads not necessarily defeated")
local used=5*result.reductions[a.guid]+4*result.reductions[b.guid]
assert(used<=22,"Joined attack spent more points than available")

local ordinary={guid="cccccc",data={},perks={},baseArmour=3,
    elusiveArmour=6,rangeBaseArmour=3,rangeElusiveArmour=6,x=2}
result=phase(group(a,ordinary),{a,ordinary},8,"range",{})
eq(result.reductions[a.guid],1,"Joined leader/head needs at least one Armour")
eq(result.killed[ordinary.guid],true,"Joined ordinary enemy killed")
eq(result.full,false,"Joined boss still alive")
result=phase(group(a,ordinary),{a,ordinary},7,"range",{})
eq(result.spent,false,"Insufficient joined Attack harms nobody")

env.gStates.combatBossManual[a.guid]=0
result=phase(group(a),{a},15,"range",{})
eq(result.reductions[a.guid],0,"Manual zero overrides single-target Ranged")
result=phase(group(a),{a},0,"attack",{})
eq(result.reductions[a.guid],0,"Manual zero overrides single-target Attack")
env.gStates.combatBossManual[a.guid]=2
result=phase(group(a),{a},0,"attack",{})
eq(result.reductions[a.guid],2,"Manual correction handles unrecognised Attack")
env.gStates.combatBossManual={}

-- Phase-specific Elusive and Defend Armour; no state is written by allocation.
local elusive=boss("elusive",4,3,3)
elusive.data.elusive=true
elusive.rangeElusiveArmour=9
elusive.defendMeleeBonus=1
result=phase(group(elusive),{elusive},8,"range",{})
eq(result.reductions.elusive,1,"Ranged uses phase-specific Elusive Armour minus late Defend")
result=phase(group(elusive),{elusive},4,"attack",{})
eq(result.spent,false,"Unblocked Elusive boss needs higher Armour")
result=phase(group(elusive),{elusive},4,"attack",{elusive=true})
eq(result.reductions.elusive,1,"Blocked Elusive boss uses ordinary Armour")
eq(elusive.bossLevel,3,"Allocation does not mutate boss levels")
local first=boss("first",4,4,0)
local second=boss("second",4,4,1)
env.gStates.combatBossManual={second=3}
result=phase(group(first,second),{first,second},12,"range",{})
eq(result.reductions.first,1,"Joined allocation reserves first boss Armour")
eq(result.reductions.second,2,"Manual preference receives spare budget first")
eq(env.gStates.combatBossManual.second,3,"Allocation does not mutate manual overrides")
env.gStates.combatBossManual={}
first.bossRangeLevels=2
result=phase(group(first),{first},100,"attack",{})
eq(result.reductions.first,2,"Melee caps reduction at remaining boss levels")
eq(result.full,true,"Remaining boss levels can be defeated")
first.rangeDead=true
result=phase(group(first,second),{first,second},4,"attack",{})
eq(result.reductions.first,nil,"Previously range-defeated boss does not consume Attack")
eq(result.reductions.second,1,"Surviving boss receives Attack")

local control={guid="control",bossLevel=0,bossType="control",
    attackOnly=true,data={},perks={},baseArmour=0,elusiveArmour=0}
eq(phase(group(control),{control},100,"range",{}),nil,"Control head never attacked")
assert(recognition:find('bossType=="control"',1,true),"Control guard lost")
assert(read("src/PlayingGame/PlayerBoard/ResourceTracker/Combat/EarlyCombatPhase.lua"):find("group.rangeSpent=plan.spent",1,true)
    and read("src/PlayingGame/PlayerBoard/ResourceTracker/Combat/LateCombatPhase.lua"):find("group.rangeSpent",1,true),
    "Ranged points double-counted")
assert(combat:find("combatDefeatPartial",1,true),"Partial cleanup missing")
assert(combat:find("combatBossPartialRewardEligible",1,true),"Partial Fame state missing")
assert(leaders:find("combatBossSetManual",1,true),"Leader manual override missing")
assert(leaders:find('mouseButton=="-2"',1,true),"Leader Auto reset needs TTS right-click")
assert(dragon:find("combatBossSetManual",1,true),"Dragon manual override missing")
assert(dragon:find('mouseButton=="-2"',1,true),"Dragon Auto reset needs TTS right-click")
assert(ui:find("combatBossPartialRewardEligible",1,true),"Leader partial Fame missing")
print("Official Dragon head and faction leader overkill regression checks passed")
