-- Regression checks for Wolfhawk's enemy skills and cooperative effects.
-- Run from the repository root with: lua5.2 tools/test-wolfhawk-skills.lua
local function eq(actual,expected,label)
    if actual~=expected then
        error((label or "Mismatch")..": expected "..tostring(expected)..
            ", got "..tostring(actual),2)
    end
end
local function source(path)
    local file=assert(io.open(path,"r"))
    local value=file:read("*a")
    file:close()
    return value
end
local function contains(text,needle,label)
    eq(text:find(needle,1,true)~=nil,true,label)
end
local data=source("src/Data.lua")
local calc=source("src/PlayingGame/PlayerBoard/CardRecognition.lua")
local skills=source("src/PlayingGame/PlayerBoard/Skills.lua")
contains(data,'["7d1c32"]={choices={{key="duel",icon="block",block=1,attack=1',
    "Dueling presents a same-enemy combined Block/Attack target")
contains(data,'["b73b21"]={choices=',"Taunt options registered")
contains(data,'attackIncrease=2,armourReduce=2,armourReduceAttackOnly=2',
    "Taunt provocation delayed until the Attack phase")
contains(data,'["2c74ca"]={prey=true,enemyEffect={normal={}}}',
    "Know Your Prey dynamic enemy targeting registered")
contains(data,'wolfHowlPenalty=true',"Wolf's Howl has competitive penalty metadata")
contains(calc,'if skill.guid=="6a33c1"',"Krang's Curse path remains present")
contains(calc,'local rangedReduction=math.max(0,reduction-lateReduction)',
    "Taunt Armour reduction must not be active during the Ranged/Siege phase")
contains(calc,'for _,wound in ipairs(wounds) do',"Wounds inspected in tracker")
contains(calc,'-- Power of Pain / Ritual of Pain can make a sideways Wound',
    "Deadly Aim considers already powered Wounds")
contains(calc,'records[wound.guid].resources~=nil',
    "Deadly Aim rejects inert Wounds")
contains(skills,'gStates.wolfhawkPackUse={recipient=gStates.turnNumber,',
    "Pack recipient receives persistent combat claim")
contains(skills,'gStates.wolfhawkPackUse=nil',"Pack claim expires on recipient turn end")

-- Run the production enemy-effect engine in isolation: no TTS objects needed.
monsterPugs={
    target={name="Test",armour=5},
    immune={name="Immune",armour=5,arcaneImmunity=true}
}
gStates={monsterPerks={}}
assert(loadfile("src/PlayingGame/PlayerBoard/CombatEffects.lua"))()
local effects={}
combatEffectAdd(effects,"target","taunt",{attackIncrease=2,
    armourReduce=2,armourReduceAttackOnly=2})
eq(effects.target.attackReductions[1].amount,-2,"Taunt increases one attack")
eq(effects.target.armourReduce,2,"Taunt lowers Armour")
eq(effects.target.armourReduceAttackOnly,2,"Taunt Armour reduction is delayed")
combatEffectAdd(effects,"target","prey",{removeTrait="fortified"})
eq(effects.target.removedPrinted.fortified,true,"Prey removes printed trait")
combatEffectAdd(effects,"target","preyAttack",{
    convertAttack={slot=2,from="IF",to="I"}})
eq(effects.target.attackConversions[1].slot,2,"Prey selects one printed attack")
combatEffectAdd(effects,"immune","taunt",{attackReduce=1,armourReduce=2})
eq(effects.immune.attackReductions[1].amount,1,
    "Arcane Immunity does not prevent attack reduction")
eq(effects.immune.armourReduce,0,"Arcane Immunity prevents Armour reduction")
combatEffectAdd(effects,"immune","prey",{removeTrait="poison"})
eq(effects.immune.removedPrinted.poison,nil,
    "Arcane Immunity prevents Know Your Prey's non-Attack effects")

-- Compile and execute the exact elemental conversion helper from the calculator.
local first=assert(calc:find('combatConfig.convertPreyAttacks=function',1,true))
local last=assert(calc:find('\n-- Summoned tokens are not enemies',first,true))
combatConfig={attackTypes={
    {key="P",label="Physical",block="block"},
    {key="F",label="Fire",block="blockIce"},
    {key="I",label="Ice",block="blockFire"},
    {key="IF",label="Cold Fire",block="blockColdFire"}
}}
assert(load(calc:sub(first,last-1)))()
local attacks={
    {slot=1,key="F",label="Fire",block="blockIce"},
    {slot=2,key="IF",label="Cold Fire",block="blockColdFire"}
}
combatConfig.convertPreyAttacks(attacks,{
    attackConversions={{slot=2,from="IF",to="I"}}})
eq(attacks[1].key,"F","Prey leaves unselected attack unchanged")
eq(attacks[2].key,"I","Prey changes selected Cold Fire attack")
eq(attacks[2].block,"blockFire","Prey updates required Block element")

-- Execute the production conditional Dueling Fame fragment for all exclusions.
first=assert(calc:find('    local duelingUnitDamaged=false',1,true))
last=assert(calc:find('    combatDefeatFameRep.fame,combatDefeatFameRep.rep=',first,true))
local fameFunction=assert(load('return function(groups,damageResults,seatScan,entries,'..
    'combatAssignmentState,defeatFame)\n'..calc:sub(first,last-1)..
    '\nreturn defeatFame\nend'))()
local duelingSource={key="7d1c32",dueling=true,duelingEligible=true,kind="skill"}
local groups={{defeated=true,rangeDefeated=false,destroyed=false,
    members={1},sources={duelingSource}}}
local entries={{guid="enemy"}}
local state={targets={["7d1c32"]="enemy"}}
local scan={cards={}}
local function fame(damage,record)
    return fameFunction(groups,damage or {},record or scan,entries,state,0)
end
eq(fame(),1,"Dueling awards Fame after eligible melee victory")
eq(fame({a={units={{wounded=false}}}}),0,
    "Damage assigned to a resisting Unit still disqualifies Fame")
groups[1].rangeDefeated=true
eq(fame(),0,"Ranged/Siege kill cannot earn Dueling Fame")
groups[1].rangeDefeated=false
duelingSource.duelingEligible=false
eq(fame(),0,"Dueling requires a Block-phase target")
duelingSource.duelingEligible=true
groups[1].sources[2]={kind="unit"}
eq(fame(),0,"Unit combat resource on same enemy denies Dueling Fame")
groups[1].sources[2]=nil
eq(fame({}, {cards={u={kind="unit",enemyEffectTargetGUIDs={u="enemy"}}}}),0,
    "Unit effect-only target on same enemy denies Dueling Fame")
state.targets["7d1c32"]="otherEnemy"
eq(fame(),0,"Dueling cannot earn Fame for a different enemy")

-- Run the actual unit modifier, not a copy of its arithmetic.
first=assert(calc:find('    local function unitAbilityResources(ability,counts,crystalCounts)',1,true))
last=assert(calc:find('    local selectedUnitAttacks={}',first,true))
local prefix=[[return function(ability,penalty)
  local howlPenalty=penalty
  local unitCombatBoost=0
  local trackerPrivate={totalsKeys={attack=true,attackFire=true,block=true,
    blockIce=true,ranged=true,siege=true,influence=true,healing=true}}
  local function unitAbilityPaid() return true end
]]
local unitFunction=assert(load(prefix..calc:sub(first,last-1)..
    '\nreturn unitAbilityResources(ability,{}, {})\nend'))()
local result=unitFunction({attackFire=3,blockIce=1,influence=2},true)
eq(result.attackFire,2,"Howl penalizes elemental Unit Attack")
eq(result.blockIce,0,"Howl penalizes elemental Unit Block, minimum zero")
eq(result.influence,2,"Howl leaves Influence unchanged")
eq(unitFunction({attackFire=3},false).attackFire,3,
    "Wolfhawk owner's Unit Attack is not penalized")
print("Wolfhawk skill regression tests passed")
