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
local function findUpvalueTable(root,wanted,seen)
    if type(root)~="function" then return nil end
    seen=seen or {}
    if seen[root] then return nil end
    seen[root]=true
    for index=1,200 do
        local name,value=debug.getupvalue(root,index)
        if name==nil then break end
        if name==wanted and type(value)=="table" then return value end
    end
    for index=1,200 do
        local name,value=debug.getupvalue(root,index)
        if name==nil then break end
        if type(value)=="function" then
            local found=findUpvalueTable(value,wanted,seen)
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

-- Poisonous attacks create Wounds for the Hero and extra Poison Wounds to discard.
-- The detailed and collapsed rows use the same wording; collapsing must not
-- display the detailed Hero line a second time.
local damageNotes=assert(findFunction(root,"combatDamageNotes"),"Damage note formatter not reachable")
local compactResult=assert(findFunction(root,"combatCompactResultLines"),"Compact result formatter not reachable")
local poisonResult={units={},heroWounds=3,discard=3,paralyse=false}
local poisonItem={key="poison-example",poison=true}
local poisonNotes=damageNotes(poisonItem,poisonResult)
check("detailed Poison wound text is clear",
    #poisonNotes==1 and poisonNotes[1]==">Hero: 3 Wounds (3 Poison)")
local compactPoison=compactResult({"Not blocked, 5 Damage",poisonNotes[1]},
    {poisonItem},{["poison-example"]=poisonResult})
local compactHeroCount=0
for _,line in ipairs(compactPoison) do
    if line:find(">Hero:",1,true) then compactHeroCount=compactHeroCount+1 end
end
check("collapsed result has one Hero wound summary, with no duplicate discard",
    compactHeroCount==1
        and compactPoison[2]==">Hero: 3 Wounds (3 Poison)")
local plainNotes=damageNotes({key="plain"},{units={},heroWounds=1,discard=0,paralyse=false})
check("non-Poison Hero summary still uses singular Wound",
    plainNotes[1]==">Hero: 1 Wound")

-- Group visual distribution must not change combat maths or target ownership.
local distributeIcons=assert(findFunction(root,"combatGroupResourceRows"),
    "Grouped combat resource display helper not reachable")
local function sampleIcons(prefix,count)
    local icons={}
    for i=1,count do icons[#icons+1]={source={key=prefix..i}} end
    return icons
end
local singleIcons,singleHidden=distributeIcons({1},
    {[1]={range=sampleIcons("range",8),block={},attack={}}},12)
check("eight Ranged icons fit in two six-icon lines for one enemy",
    #singleIcons[1].range==8 and singleHidden==0
        and singleIcons[1].range[8].source.key=="range8")
local joinedIcons,joinedHidden=distributeIcons({1,2},
    {[1]={range={},block=sampleIcons("block",14),attack=sampleIcons("attack",17)},
     [2]={range={},block=sampleIcons("second",3),attack={}}},12)
check("joined Attack excess continues on the next group member",
    #joinedIcons[1].attack==12 and #joinedIcons[2].attack==5
        and joinedIcons[2].attack[1].source.key=="attack13")
check("joined Block overflow follows each member's own Block resources",
    #joinedIcons[1].block==12 and #joinedIcons[2].block==5
        and joinedIcons[2].block[1].source.key=="second1"
        and joinedIcons[2].block[4].source.key=="block13" and joinedHidden==0)
local fullIcons,fullHidden=distributeIcons({1},
    {[1]={range={},block={},attack=sampleIcons("over",15)}},12)
check("unshown resources are counted rather than silently discarded",
    #fullIcons[1].attack==12 and fullHidden==3)
local many={}
for i=1,13 do many[i]=item("block"..i,"block",1) end
local plan=solve({attack("P",13)},many,0)
check("13 Block contributions are not silently truncated",plan[1].blocked)
local stress={}
for i=1,15 do stress[#stress+1]=item("stress"..i,i%2==0 and "blockIce" or "block",2) end
local mixedPlan=solve({attack("P",4),attack("F",3),attack("I",2)},stress,0)
check("mixed multi-attack Block solver handles fifteen separate contributions",
    #mixedPlan==3 and mixedPlan[1].blocked and mixedPlan[2].blocked and mixedPlan[3].blocked)
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
-- A Helm toggle changes Block efficiency without changing printed resources;
-- both the cached result and the displayed amount must update.
local helmEnemy={guid="helmEnemy",data={attack={M={3}}},perks={}}
local helmSource={key="helmSource",guid="helmSource",block=3,move=0,resources={block=3}}
local _,_,unblockedBefore=blockResult(helmEnemy,{helmSource})
helmSource.heroPsychicBlock=true
local helmLines,_,unblockedAfter=blockResult(helmEnemy,{helmSource})
check("Helm activation invalidates Block cache",
    unblockedBefore==1 and unblockedAfter==0)
check("Helm-efficient ordinary Block displays the full value",
    helmLines[1]~=nil and helmLines[1]:find("3/3 Blocked",1,true)~=nil)
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
-- Fortified enemies cannot be attacked by Ranged effects until melee.
-- Defender must protect an actual Ranged target first.
local phaseEntries={
    {guid="defender",data={defend=2},perks={},baseArmour=4,elusiveArmour=4},
    {guid="fortified",data={fortified=true},perks={},baseArmour=4,elusiveArmour=4},
    {guid="ranged",data={},perks={},baseArmour=4,elusiveArmour=4}
}
local phaseGroups={{members={1}},{members={2}},{members={3}}}
local phaseAlloc={
    [2]={sources={},details={{detail={family="ranged"}}}},
    [3]={sources={},details={{detail={family="ranged"}}}}
}
local phaseApplied=defend(phaseEntries,phaseGroups,phaseAlloc)
check("Defender prioritizes legal Ranged targets before melee-only targets",
    phaseApplied[3]==2 and phaseApplied[2]==nil)
local mixedEntries={
    {guid="defenderA",data={defend=2},perks={},baseArmour=4,elusiveArmour=4},
    {guid="defenderB",data={defend=1},perks={},baseArmour=4,elusiveArmour=4},
    {guid="rangedTarget",data={},perks={},baseArmour=4,elusiveArmour=4},
    {guid="meleeTarget",data={},perks={},baseArmour=4,elusiveArmour=4}
}
local mixedGroups={{members={1}},{members={2}},{members={3}},{members={4}}}
local mixedAlloc={
    [3]={sources={},details={{detail={family="ranged"}}}},
    [4]={sources={},details={{detail={family="attack"}}}}
}
local mixedApplied=defend(mixedEntries,mixedGroups,mixedAlloc)
check("Defender remaining after Ranged phase can assist melee",
    mixedApplied[3]==2 and mixedApplied[4]==1
    and mixedEntries[4].defendMeleeBonus==1)
local rangedGroup=assert(findFunction(root,"combatRangeGroupEntry"),"Ranged group resolver not reachable")
local phaseGroup=rangedGroup({mixedEntries[4]})
check("Attack-phase Defender does not retroactively change Ranged armour",
    phaseGroup.baseArmour==4 and mixedEntries[4].baseArmour==5)
local groupedDefenders={
    {guid="guardianA",data={defend=2},perks={},baseArmour=3,elusiveArmour=3},
    {guid="guardianB",data={defend=1},perks={},baseArmour=3,elusiveArmour=3},
    {guid="groupA",data={},perks={},baseArmour=3,elusiveArmour=3},
    {guid="groupB",data={},perks={},baseArmour=3,elusiveArmour=3}
}
local groupedTargets={{members={1}},{members={2}},{members={3,4}}}
local groupedAllocated={
    [4]={sources={},details={{detail={family="attack"}}}}
}
local groupedBonus=defend(groupedDefenders,groupedTargets,groupedAllocated)
check("attacking a joined group makes both members eligible for distinct Defend bonuses",
    groupedBonus[3]==2 and groupedBonus[4]==1)
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
local traitText=assert(findFunction(root,"combatGroupTraitsText"),"Effective trait formatter not reachable")
local stripped={guid="stripped",data={fResist=true,fortified=true,elusive=true},
    perks={},baseArmour=4,elusiveArmour=8,stripFortify=true,stripFireResist=true}
local displayed=traitText(stripped,groupEntry({stripped},{}))
check("effective defenses hide removed fortification and resistance",
    displayed:find("Fortified",1,true)==nil
    and displayed:find("Fire Resist",1,true)==nil
    and displayed:find("Elusive",1,true)~=nil)
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

-- Ranged/Siege and Block are already resolved by the time a Unit receives
-- damage. Only remaining Attack-phase resources can be cancelled.
local phaseConfig=assert(findUpvalueTable(root,"combatConfig"),"Combat phase config not reachable")
local attackTotal=assert(findFunction(root,"combatAttackTotal"),"Combat attack total not reachable")
local woundedUnit={guid="rangedUnit",resources={ranged=3,block=4}}
local survivingCard={guid="attackCard",resources={attack=2}}
local sources={woundedUnit,survivingCard}
local woundedPhase=phaseConfig.unitsWoundedByDamage({
    first={units={{unit={guid="rangedUnit"},wounded=true,wounds=1}}}})
local survivingSources=phaseConfig.attackPhaseSources(sources,woundedPhase)
check("an enemy wound disables the Unit's Attack phase but not its earlier Ranged/Block",
    woundedPhase.rangedUnit==true
    and #survivingSources==1 and survivingSources[1]==survivingCard
    and attackTotal({{sources=sources,category="ranged"}},{},{})==3
    and woundedUnit.resources.block==4)
local fullMelee=attackTotal({{sources=sources,category="ranged"},
    {sources=sources,category="attack"}},{},{})
local reducedMelee=attackTotal({{sources=survivingSources,category="ranged"},
    {sources=survivingSources,category="attack"}},{},{})
check("Ranged 3 insufficient in first phase cannot rescue melee after Unit is wounded",
    fullMelee==5 and reducedMelee==2)
local resistedPhase=phaseConfig.unitsWoundedByDamage({
    first={units={{unit={guid="rangedUnit"},wounded=false,resisted=true}}}})
check("fully resisted Unit damage leaves its Attack-phase resource active",
    #phaseConfig.attackPhaseSources(sources,resistedPhase)==2)
local destroyedPhase=phaseConfig.unitsWoundedByDamage({
    first={units={{unit={guid="rangedUnit"},wounded=true,destroyed=true}}}})
check("Paralysis cancels remaining Unit attacks",
    #phaseConfig.attackPhaseSources(sources,destroyedPhase)==1)
-- Utem Swordsmen wounds itself at the time of its selected ability, not
-- retroactively after the combat. Block 6 is already Wounded during Damage;
-- Attack 6 can be used only after surviving Damage unwounded.
unitResourceDefinitions={swords={
    {attack=3},{block=3},{attack=6,woundsSelf=true},{block=6,woundsSelf=true}}}
gStates={unitResourceActivations={swords={seatPos=1,choice=4}}}
resourceCardScanBySeat[1]={cards={swords={complete=true}}}
local activeSelfWoundGroup={{rangeDefeated=false,destroyed=false,
    sources={{guid="swords",resources={block=6,attack=0,ranged=0}}}}}
local selfEarly,selfLate=phaseConfig.selfWoundingUnitChoices(1,activeSelfWoundGroup)
check("self-wounding Block 6 makes Utem Swordsmen ineligible before damage",
    selfEarly.swords and not selfLate.swords)
gStates.unitResourceActivations.swords.choice=3
selfEarly,selfLate=phaseConfig.selfWoundingUnitChoices(1,activeSelfWoundGroup)
check("self-wounding Attack 6 happens only after damage assignment",
    selfLate.swords and not selfEarly.swords)
activeSelfWoundGroup[1].rangeDefeated=true
selfEarly,selfLate=phaseConfig.selfWoundingUnitChoices(1,activeSelfWoundGroup)
check("a Ranged phase defeat prevents unused Attack 6 from wounding the Unit",
    next(selfEarly)==nil and next(selfLate)==nil)
unitResourceDefinitions=nil
resourceCardScanBySeat[1]=nil
turnOrder={{seatPos=1}}
gStates={turnNumber=1,attackedMonsters={summoned={nil,nil,"summoned","owner"}},
    summonStates={summoned="summoned"}}
playerPlayAreas={[1]="play"}
playerUnitAreas={[1]="units"}
monsterPugs={owner={name="Owner"},summoned={name="Summoned"},
    hidden={name="Hidden"},remote={name="Remote"}}
local function monster(guid,faceDown)
    return {guid=guid,is_face_down=faceDown,isDestroyed=function() return false end,
        isSmoothMoving=function() return false end,resting=true}
end
local owner=monster("owner",false)
local summoned=monster("summoned",false)
local hidden=monster("hidden",true)
local remote=monster("remote",false)
local world={play={getObjects=function() return {owner,hidden,summoned} end},
    units={getObjects=function() return {} end},
    owner=owner,summoned=summoned,hidden=hidden,remote=remote}
getObjectFromGUID=function(guid) return world[guid] end
local targets=resourceCardsCombatTargetObjects()
check("target buttons include only face-up enemies in active combat",
    targets.owner==owner and targets.summoned==summoned
    and targets.hidden==nil and targets.remote==nil)
-- Raising the only owner out of a short zone must not tear down its
-- combat row, its summoned proxy, or the resource target it was assigned.
owner.held_by_color="Red"
world.play.getObjects=function() return {hidden,summoned} end
targets=resourceCardsCombatTargetObjects()
check("held owner remains in combat while above the zone",
    targets.owner==owner and targets.summoned==summoned)
owner.held_by_color=nil
world.play.getObjects=function() return {owner,hidden,summoned} end
targets=resourceCardsCombatTargetObjects()
check("dropping owner back in the zone keeps its target",targets.owner==owner)
owner.held_by_color="Red"
world.play.getObjects=function() return {hidden,summoned} end
targets=resourceCardsCombatTargetObjects()
check("second lift still retains the same combat owner",targets.owner==owner)
owner.held_by_color=nil
owner.resting=false
targets=resourceCardsCombatTargetObjects()
check("released but falling owner stays targeted until it settles",targets.owner==owner)
owner.resting=true
targets=resourceCardsCombatTargetObjects()
check("settled owner outside combat is removed, including summoned proxy",
    targets.owner==nil and targets.summoned==nil)
-- An enemy not previously in combat must never be admitted simply
-- because it is held over the board.
remote.held_by_color="Red"
targets=resourceCardsCombatTargetObjects()
check("unrelated held enemy is never added to combat",targets.remote==nil)
-- Reminder attacks are active combat targets even without monsterPugs entries.
gStates.firstStarted=true
gStates.monsterPerks={
    volkareReminder={arcaneImmunity=true,brutal=true,assassination=true,attack={F={3}}},
    trapReminder={cumbersome=true,brutal=true,attack={P={5}}}}
local volkareReminder=monster("volkareReminder",false)
volkareReminder.getGMNotes=function() return "Volkare Reminder Token" end
local trapReminder=monster("trapReminder",false)
trapReminder.getGMNotes=function() return "Trap Reminder Token" end
world.volkareReminder=volkareReminder
world.trapReminder=trapReminder
world.play.getObjects=function() return {owner,volkareReminder,trapReminder} end
local updated=resourceCardsCombatTargetObjects()
check("Volkare and trap reminders become face-up combat targets",
    updated.volkareReminder==volkareReminder and updated.trapReminder==trapReminder)
local specialData=assert(findFunction(root,"combatEnemyData"),"Combat-only data resolver not reachable")
local volkareData,volkareMode=specialData("volkareReminder",volkareReminder)
local trapData,trapMode=specialData("trapReminder",trapReminder)
check("reminders have attack-only data, not armour",
    volkareMode=="attackOnly" and trapMode=="attackOnly"
    and volkareData.armour==0 and trapData.armour==0)
local enemyAttacks=assert(findFunction(root,"combatEnemyAttacks"),"Attack reader not reachable")
local rolled=enemyAttacks({guid="volkareReminder",data=volkareData,perks=gStates.monsterPerks.volkareReminder})
check("Volkare reminder contributes rolled Fire Attack and Assassination",
    #rolled==1 and rolled[1].key=="F" and rolled[1].value==3 and rolled[1].assassination)
local trapAttack=enemyAttacks({guid="trapReminder",data=trapData,perks=gStates.monsterPerks.trapReminder})
check("trap contributes rolled Cumbersome attack",
    #trapAttack==1 and trapAttack[1].value==5 and trapAttack[1].cumbersome)
resourceCardScanBySeat[1]={cards={cardBlock={resources={block=5}},
    cardAttack={resources={attack=5}}}}
local accepts=resourceCardsCombatTargetAcceptsSource
check("Block sources target reminders; Attack sources cannot",
    accepts("cardBlock","trapReminder") and not accepts("cardAttack","trapReminder"))
check("special reminder attacks can receive direct reduction links",
    accepts("effectOnly","trapReminder"))
trapReminder.is_face_down=true
check("face-down traps leave calculator targets",
    resourceCardsCombatTargetObjects().trapReminder==nil)
trapReminder.is_face_down=false
-- Leader planning copies borrow real leader combat data, but are not real kills.
monsterPugs.realLeader={name="Dark Crusader",armour=7,attack={P={6}},pugType="leader"}
gStates.coopAssaultType="leader"
gStates.coopLeaderPreviewClones={[1]="previewLeader"}
gStates.coopAssaultCityGUID="leaderCity"
factionLeaderForCity=function() return {token="realLeader"} end
local preview=monster("previewLeader",false)
world.previewLeader=preview
world.play.getObjects=function() return {owner,preview} end
local previewData,previewMode=specialData("previewLeader",preview)
check("leader co-op planning copy inherits live leader stats",
    previewMode=="preview" and previewData==monsterPugs.realLeader)
check("leader planning copy becomes an assignable combat target",
    resourceCardsCombatTargetObjects().previewLeader==preview)
print("Combat calculator regression tests passed.")
