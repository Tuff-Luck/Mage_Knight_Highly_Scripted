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
local start=assert(recognition:find("function combatBossLevelCount(",1,true))
local finish=assert(recognition:find("-- Each Defend symbol",start,true))
local code=recognition:sub(start,finish-1)
local env=setmetatable({gStates={combatBossManual={}},
    combatEnemyHasTrait=function(data,perks,key)
        return data[key]==true or (perks~=nil and perks[key]==true)
    end},{__index=_G})
local count,phase=assert(load(code.."\\nreturn combatBossLevelCount,combatBossPhasePlan","boss level rules","t",env))()
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

local control={guid="control",bossLevel=0,bossType="control",
    attackOnly=true,data={},perks={},baseArmour=0,elusiveArmour=0}
eq(phase(group(control),{control},100,"range",{}),nil,"Control head never attacked")
assert(recognition:find('bossType=="control"',1,true),"Control guard lost")
assert(recognition:find("group.rangeSpent",1,true),"Ranged points double-counted")
assert(combat:find("combatDefeatPartial",1,true),"Partial cleanup missing")
assert(combat:find("combatBossPartialRewardEligible",1,true),"Partial Fame state missing")
assert(leaders:find("combatBossSetManual",1,true),"Leader manual override missing")
assert(dragon:find("combatBossSetManual",1,true),"Dragon manual override missing")
assert(ui:find("combatBossPartialRewardEligible",1,true),"Leader partial Fame missing")
print("Official Dragon head and faction leader overkill regression checks passed")
