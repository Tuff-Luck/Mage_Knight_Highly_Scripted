-- Pure calculator regression tests. Run with: lua5.2 tools/test-combat-calculator.lua
-- The real CardRecognition.lua is loaded; local helpers are discovered through
-- Lua 5.2's debug upvalues so production math is tested without a TTS runtime.
dofile("src/PlayingGame/PlayerBoard/CardRecognition.lua")
local function findFunction(root,wanted,seen)
    if type(root)~="function" then return nil end
    seen=seen or {}
    if seen[root] then return nil end
    seen[root]=true
    for index=1,200 do
        local name,value=debug.getupvalue(root,index)
        if name==nil then break end
        if name==wanted and type(value)=="function" then return value end
    end
    for index=1,200 do
        local name,value=debug.getupvalue(root,index)
        if name==nil then break end
        if type(value)=="function" then
            local found=findFunction(value,wanted,seen)
            if found~=nil then return found end
        end
    end
end
local root=resourceCardsRefreshCombatEnemies
local solve=assert(findFunction(root,"combatSolveBlocks"),"Block solver not reachable")
local reduce=assert(findFunction(root,"combatApplyAttackReductions"),"Attack reduction not reachable")
local damage=assert(findFunction(root,"combatDamageResolve"),"Damage resolver not reachable")
local function item(source,key,value)
    return {source={key=source},key=key,value=value}
end
local function attack(key,value,extra)
    local result={key=key,value=value}
    for k,v in pairs(extra or {}) do result[k]=v end
    return result
end
local function check(label,condition)
    assert(condition,label)
    print("PASS "..label)
end
local many={}
for i=1,13 do many[i]=item("block"..i,"block",1) end
local plan=solve({attack("P",13)},many,0)
check("13 Block contributions are not silently truncated",plan[1].blocked)
plan=solve({attack("M",3)},{item("physical","block",5)},0)
check("wrong-type Block halves once against Psychic",not plan[1].blocked)
plan=solve({attack("M",3)},{item("physical","block",5),item("mind","blockPsychic",1)},0)
check("Psychic Block plus half Physical Block succeeds",plan[1].blocked)
plan=solve({attack("P",1)},{item("mind","blockPsychic",100)},0)
check("Psychic Block is illegal against Physical Attack",not plan[1].blocked)
plan=solve({attack("M",3)},{item("physical","block",6)},0)
check("six ordinary Block stops Psychic Attack three inefficiently",plan[1].blocked)
local heroBlock=item("hero","block",3)
heroBlock.source.heroPsychicBlock=true
plan=solve({attack("M",3)},{heroBlock},0)
check("Helm of Mind Shielding makes a Hero's normal Block efficient against Psychic",plan[1].blocked)
local unitBlock=item("unit","block",3)
plan=solve({attack("M",3)},{unitBlock},0)
check("Helm does not grant Psychic Block to Units",not plan[1].blocked)

local points={}
for i=1,5 do points[i]=item("Influence","blockPsychic",1) end
plan=solve({attack("M",2),attack("M",3)},points,0)
check("one Influence source splits five points across Psychic attacks",plan[1].blocked and plan[2].blocked)
plan=solve({attack("P",6,{cumbersome=true})},{item("block","block",4)},2)
check("Cumbersome Move works together with Block",plan[1].blocked and plan[1].reduction==2)
local attacks={attack("P",6),attack("F",4)}
reduce(attacks,{attackReductions={{amount=3,source="u"}}},nil,{u=2})
check("player can select the second Attack for reduction",attacks[1].value==6 and attacks[2].value==1)
attacks={attack("P",6),attack("F",4)}
reduce(attacks,{attackReductions={{amount=3,source="u"}}},nil,nil)
check("automatic reduction still chooses strongest Attack",attacks[1].value==3 and attacks[2].value==4)
attacks={attack("P",6),attack("F",4)}
reduce(attacks,{attackReductions={{amount=3,source="a",id="a"},
    {amount=3,source="b",id="b"}}},nil,{a=1,b=2})
check("independent reduction sources choose different attack slots",
    attacks[1].value==3 and attacks[2].value==1)
local blockResult=assert(findFunction(root,"combatBlockResult"),"Block result not reachable")
gStates={attackedMonsters={},monsterPerks={}}
local enemy={guid="cacheenemy",data={attack={P={4}}},perks={}}
local source={key="blockSource",guid="blockSource",block=4,move=0,resources={block=4}}
local lines1,_,damageCount1=blockResult(enemy,{source})
local lines2,_,damageCount2=blockResult(enemy,{source})
check("unchanged Block result reuses exact solver outcome",
    lines1==lines2 and damageCount1==damageCount2)
source.block=3
source.resources.block=3
local lines3,_,damageCount3=blockResult(enemy,{source})
check("changed Block input invalidates Block cache",
    lines3~=lines2 and damageCount3==1)
enemy.data.attack.P={3}
local lines4,_,damageCount4=blockResult(enemy,{source})
check("changed attack strength invalidates Block cache",
    lines4~=lines3 and damageCount4==0)
enemy.data.attack.P={4}
enemy.data.poison=true
local _,_,_,_,_,_,unblocked=blockResult(enemy,{source})
check("Poison ability survives cached Block pipeline",
    unblocked[1]~=nil and unblocked[1].attack.poison==true)
local defend=assert(findFunction(root,"combatApplyDefend"),"Defender resolver not reachable")
local function defenderEntries()
    return {{guid="defender",data={defend=1},perks={},baseArmour=4,elusiveArmour=4},
        {guid="target",data={},perks={},baseArmour=4,elusiveArmour=4}}
end
local groups={{members={1}},{members={2}}}
local allocated={[2]={sources={},details={{detail={family="influence"}}}}}
check("Psychic Influence Block does not trigger Defender",
    next(defend(defenderEntries(),groups,allocated))==nil)
allocated[2].details[1].detail.family="attack"
check("a genuine Attack activates Defender",
    defend(defenderEntries(),groups,allocated)[2]==1)
local groupEntry=assert(findFunction(root,"combatGroupEntry"),"Group resolver not reachable")
local grouped,groupArmour=groupEntry({
    {guid="a",data={fResist=true,elusive=true},perks={},baseArmour=3,elusiveArmour=6},
    {guid="b",data={iResist=true,fortified=true},perks={},baseArmour=4,elusiveArmour=4}},
    {a=false,b=true})
check("group inherits elemental resistance and fortification",
    grouped.data.fResist and grouped.data.iResist and grouped.data.fortified
    and grouped.baseArmour==7 and groupArmour==10)
check("separate Fire and Ice resistances do not give Cold Fire resistance",
    not grouped.data.coldFireResist)
local readUnits=assert(findFunction(root,"combatDamageUnits"),"Damage Unit scanner not reachable")
resourceCardScanBySeat[1]={unitState={units={{guid="unit",unwounded=true}},
    nativeCommandCount=2},preventUnitDamage=true}
local forbiddenUnits,nativeCount=readUnits(1)
check("Into the Heat removes Unit damage recipients without changing native Command count",
    next(forbiddenUnits)==nil and nativeCount==2)
gameCards={unit={armour=3,level=2,name={"Tester"},resistance={}}}
resourceCardScanBySeat[1]={unitState={units={{guid="unit",unwounded=true}},
    nativeCommandCount=2},allUnitResistances=true}
local enhancedUnits=readUnits(1)
check("Altem Guardians and Mist Form grant all three Unit resistances",
    enhancedUnits.unit.resist.P and enhancedUnits.unit.resist.F and enhancedUnits.unit.resist.I)
resourceCardScanBySeat[1]=nil
local unit={guid="unit",name="Tester",armour=6,level=2,resist={},wounded=false}
local resolved=damage({{key="enemy:1",type="M",damage=4}}, {unit=unit},2,function() return {"unit"} end)
check("Psychic damage uses Unit level instead of printed Armor",
    resolved["enemy:1"].units[1].wounded and resolved["enemy:1"].heroWounds==1)
local resistant={guid="resist",name="Fireguard",armour=3,level=2,
    resist={F=true},wounded=false}
resolved=damage({{key="fire",type="F",damage=3,poison=true}},
    {resist=resistant},2,function() return {"resist"} end)
check("full Unit resistance absorbs Fire with no Poison wound",
    not resolved.fire.units[1].wounded and resolved.fire.heroWounds==0)
resolved=damage({{key="fire",type="F",damage=8,poison=true}},
    {resist=resistant},2,function() return {"resist"} end)
check("partial Unit resistance still gives two Poison Wounds",
    resolved.fire.units[1].wounds==2 and resolved.fire.heroWounds==1
    and resolved.fire.discard==1)
resolved=damage({{key="assassin",type="P",damage=4,assassination=true}},
    {resist=resistant},2,function() return {"resist"} end)
check("Assassination excludes Unit allocations",
    #resolved.assassin.units==0 and resolved.assassin.heroWounds==2)
local forced={guid="forced",name="Guard",armour=3,level=1,resist={},wounded=false}
resolved=damage({
    {key="ordinary",type="P",damage=4},
    {key="shock",type="P",damage=3,firstDamageUnit="forced",paralyse=true}},
    {forced=forced},2,function() return {"forced"} end)
check("forced Shocktroops recipient reserved and Paralyse destroys it",
    #resolved.ordinary.units==0 and resolved.ordinary.heroWounds==2
    and resolved.shock.units[1].unit.guid=="forced"
    and resolved.shock.units[1].destroyed)
turnOrder={{seatPos=1}}
gStates={turnNumber=1,attackedMonsters={summoned={nil,nil,"summoned","owner"}},
    summonStates={summoned="summoned"}}
playerPlayAreas={[1]="play"}
playerUnitAreas={[1]="units"}
monsterPugs={owner={name="Owner"},summoned={name="Summoned"},
    hidden={name="Hidden"},remote={name="Remote"}}
local function monster(guid,faceDown)
    return {guid=guid,is_face_down=faceDown,isDestroyed=function() return false end}
end
local owner=monster("owner",false)
local summoned=monster("summoned",false)
local hidden=monster("hidden",true)
local remote=monster("remote",false)
local world={play={getObjects=function() return {owner,hidden,summoned} end},
    units={getObjects=function() return {} end},remote=remote}
getObjectFromGUID=function(guid) return world[guid] end
local targets=resourceCardsCombatTargetObjects()
check("target buttons include only face-up enemies in active combat",
    targets.owner==owner and targets.summoned==summoned
    and targets.hidden==nil and targets.remote==nil)
world.play.getObjects=function() return {hidden,summoned} end
targets=resourceCardsCombatTargetObjects()
check("summoned token is not targetable without its summoner",targets.summoned==nil)
print("Combat calculator regression tests passed.")
