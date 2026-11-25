-- Related regressions share a runner and fixtures while each case retains local state.
-- Run from repository root: lua5.2 tools/test-resource-tracker-enemy-properties.lua

local function eq(actual,expected,label)
    assert(actual==expected,(label or "Mismatch")..": expected "..tostring(expected)..", got "..tostring(actual))
end

local failures={}
local function run(name,body)
    local ok,message=xpcall(body,debug.traceback)
    if not ok then
        failures[#failures+1]=name..": "..tostring(message)
    end
end

run("resource-tracker-enemy-attacks",function()
    -- Actual enemy attack calculation, without any TTS objects or saved state.
    local kinds={{key="P",label="Physical",block="block"},
        {key="F",label="Fire",block="blockFire"},
        {key="I",label="Ice",block="blockIce"},
        {key="IF",label="Cold Fire",block="blockColdFire"},
        {key="M",label="Psychic",block="blockPsychic"}}
    local function trait(data,perks,key)
        return data[key]==true or (perks~=nil and perks[key]==true)
    end
    local function fortifications(data,perks)
        if trait(data,perks,"unfortified") then return 0 end
        return (data.fortified and 1 or 0)+(perks and perks.fortified and 1 or 0)
            +(perks and perks.wallFortified and 1 or 0)
    end
    local engine=dofile("src/PlayingGame/PlayerBoard/ResourceTracker/Combat/EnemyProperties.lua").attacks(kinds,trait,fortifications)
    local data={attack={P={4,3},F={5},M={2}},brutal=true,poison=true}
    local printed=engine.printed(data,{boost=2,elemental=true,attack={F={6}}},false,"enemy")
    eq(printed[1].value,8,"Boost applied once plus elemental bonus")
    eq(printed[2].value,5,"Second Attack has only elemental bonus")
    eq(printed[3].value,8,"Perk attack overrides printed value")
    eq(printed[4].brutal,false,"Psychic never inherits Brutal")
    eq(printed[4].poison,false,"Psychic never inherits Poison")
    eq(printed[3].owner,"enemy","Physical owner preserved")
    eq(printed[3].slot,3,"Stable original slot")
    local effect={attackReductions={{source="a",id="a",amount=2},
        {source="b",id="b",amount=3}}}
    local entry={guid="enemy",data=data,effect=effect}
    local attacks=engine.enemyAttacks(entry,false,{b=2})
    eq(attacks[2].value,0,"Explicit reduction applies to selected Attack")
    eq(attacks[3].value,3,"Other reduction uses strongest remaining Attack")
    eq(data.attack.F[1],5,"Printed values not mutated")
    local again=engine.enemyAttacks(entry,false,{b=2})
    eq(again[3].value,3,"Repeated calculation is not cumulative")
    entry.effect={attackReductions={{source="fear",amount=0,cancelAttack=true}}}
    attacks=engine.enemyAttacks(entry)
    eq(#attacks,3,"One Attack cancelled")
    eq(attacks[3].slot,4,"Remaining Attack retains original slot")
    attacks=engine.enemyAttacks(entry,true)
    eq(#attacks,4,"Cycle can include cancelled Attack")
    eq(attacks[3].cancelled,true,"Strongest Attack cancelled")
    local summoner={guid="summoner",data={attack={P={3}},monsters={1,2}},
        summoned={{guid="summon",data={attack={F={7}},poison=true},
            effect={attackConversions={{slot=1,from="F",to="I"}},
                attackReductions={{source="strip",amount=1,stripAbilities=true}},
                grantCumbersome=true}}},
        effect={attackConversions={{slot=1,from="P",to="F"}},grantCumbersome=true}}
    attacks=engine.enemyAttacks(summoner)
    eq(attacks[1].key,"F","Summoner changes own element")
    eq(attacks[1].cumbersome,true,"Summoner receives Cumbersome")
    eq(attacks[2].key,"I","Summoned token changes own element")
    eq(attacks[2].value,6,"Summoned reduction applied once")
    eq(attacks[2].owner,"summon","Summoned owner retained")
    eq(attacks[2].poison,false,"Strip applies to summoned attack")
    eq(attacks[2].cumbersome,false,"Stripped attack cannot regain Cumbersome")
    eq(attacks[3].pending,true,"Undrawn summon remains pending")
    summoner.summoned[1].effect={noAttackUnfortified=true}
    attacks=engine.enemyAttacks(summoner)
    eq(#attacks,2,"Unfortified summoned attack prevented")
    summoner.summoned[1].data.fortified=true
    attacks=engine.enemyAttacks(summoner)
    eq(#attacks,3,"Fortified summoned attack survives")
    summoner.summoned[1].effect.removeFortify=true
    eq(#engine.enemyAttacks(summoner),2,"Removed fortification prevents attack")
    print("Enemy attack construction, reduction, cancellation and summons passed")
end)

run("resource-tracker-enemy-defences",function()
    -- Production defence calculations; no TTS objects or saved state required.
    local cfg={attackTypes={
        {key="P",attack="attack",ranged="ranged",siege="siege"},
        {key="F",attack="attackFire",ranged="rangedFire",siege="siegeFire"},
        {key="I",attack="attackIce",ranged="rangedIce",siege="siegeIce"},
        {key="IF",attack="attackColdFire",ranged="rangedColdFire",siege="siegeColdFire"}},
        artifactCombat={},bowSourceModes={}}
    local engine=dofile("src/PlayingGame/PlayerBoard/ResourceTracker/Combat/EnemyProperties.lua").defences(cfg)
    eq(engine.fortificationCount({fortified=true},{wallFortified=true}),2,"Printed and Wall layers")
    eq(engine.fortificationCount({fortified=true},{unfortified=true,wallFortified=true}),0,"Unfortified overrides layers")
    local function enemy(guid,data,perks,base,elusive)
        return {guid=guid,data=data,perks=perks,baseArmour=base,elusiveArmour=elusive}
    end
    local a=enemy("a",{fResist=true,elusive=true,fortified=true},nil,3,6)
    local b=enemy("b",{iResist=true},{wallFortified=true},4,8)
    local group,melee=engine.groupEntry({a,b},{})
    eq(group.baseArmour,7,"Joined base Armour")
    eq(group.elusiveArmour,10,"Only Elusive member doubles Armour")
    eq(melee,10,"Unblocked Elusive member")
    eq(engine.fortificationCount(group.data,group.perks),1,"Joined fortification uses max, not sum")
    eq(engine.resists(group.data,group.perks,"IF"),false,"Separate Fire and Ice do not resist Cold Fire")
    eq(engine.resists(group.data,group.perks,"F"),true,"Fire Resistance shared")
    eq(engine.resists(group.data,group.perks,"I"),true,"Ice Resistance shared")
    local _,blockedMelee=engine.groupEntry({a,b},{a=true})
    eq(blockedMelee,7,"Blocked Elusive member uses base Armour")
    a.data.iResist=true
    group=engine.groupEntry({a,b},{})
    eq(engine.resists(group.data,group.perks,"IF"),true,"One member with both resists Cold Fire")
    a.stripFireResist=true
    group=engine.groupEntry({a,b},{})
    eq(engine.resists(group.data,group.perks,"IF"),false,"Strip Fire removes Cold Fire Resistance")
    a.rangeBaseArmour=4
    a.rangeElusiveArmour=7
    a.defendMeleeBonus=1
    a.bossLevel=2
    local range=engine.rangeGroupEntry({a,b})
    eq(range.baseArmour,7,"Late Defend bonus does not inflate early Armour")
    eq(range.elusiveArmour,10,"Ranged Elusive Armour separate from melee")
    eq(range.fullLevelArmour,16,"Additional boss level consumes early effective Armour")
    local sources={{key="a",resources={attackFire=3}},{key="b",resources={attackIce=3,attack=2}},
        {key="c",dueling=true,duelingEligible=false,resources={attack=9}}}
    local groups={{sources=sources,category="attack"}}
    eq(engine.attackTotal(groups,{fResist=true,iResist=true},nil,"attack"),5,"Resisted values halved together and Dueling excluded")
    cfg.artifactCombat.sword=true
    eq(engine.attackTotal(groups,{pResist=true},nil,"attack"),10,"Live Sword configuration doubles Physical and strips Resistance")
    eq(engine.attackTotal(groups,{pResist=true,arcaneImmunity=true},nil,"attack"),8,"Arcane Immunity preserves Physical Resistance")
    eq(a.data.fResist,true,"Group calculation never mutates printed data")
    -- Individual modifiers preserve original fortification and do not edit shared data.
    local printed={fortified=true,fResist=true,defend=2}
    local perks={fortified=true,wallFortified=true,iResist=true}
    local c=enemy("c",printed,perks,5,10)
    engine.prepareFortifications({c},true)
    eq(c.originalFortification,3,"Original fortification preserved before site bypass")
    eq(engine.fortificationCount(c.data,c.perks),1,"Site bypass leaves printed layer")
    eq(perks.wallFortified,true,"Saved perk data never mutated")
    local function effect(fields)
        local result={armourReduce=0,armourReduceFortified=0,armourReduceByResist=0}
        for key,value in pairs(fields or {}) do result[key]=value end
        return result
    end
    local function actualAttack() return {{value=4}} end
    local function pendingAttack() return {{pending=true}} end
    engine.applyEffects(c,effect({removedPrinted={fortified=true,defend=true},
        armourReduce=1,armourBeforeFortificationRemoval=2,armourReduceByResist=1}),actualAttack)
    eq(c.baseArmour,1,"Resistance and prior fortification reduction; minimum one")
    eq(c.elusiveArmour,5,"Same reduction applied to Elusive Armour")
    eq(c.effectArmourReduction,5,"Total reduction retains both resistances and former fortification")
    eq(c.data.defend,0,"Printed Defend removed numerically")
    eq(printed.defend,2,"Original Defend never mutated")
    eq(printed.fortified,true,"Original printed fortification never mutated")
    local function taunt(attacks,extras)
        local e=enemy("taunt",{},nil,5,10)
        engine.prepareFortifications({e},false)
        local spec=effect({armourReduce=2,armourReduceFortified=2,armourReduceAttackOnly=2})
        for key,value in pairs(extras or {}) do spec[key]=value end
        engine.applyEffects(e,spec,attacks)
        return e
    end
    local t=taunt(actualAttack)
    eq(t.baseArmour,3,"Taunt applies to melee Armour")
    eq(t.rangeBaseArmour,5,"Taunt cannot reduce Ranged Armour")
    eq(t.rangeElusiveArmour,10,"Taunt cannot reduce Ranged Elusive Armour")
    t=taunt(pendingAttack)
    eq(t.baseArmour,5,"Pending summon does not qualify for Taunt")
    t=taunt(actualAttack,{noAttack=true})
    eq(t.baseArmour,5,"Attack prevention cancels Taunt discount")
    local curse=enemy("curse",{fortified=true},nil,5,10)
    engine.prepareFortifications({curse},false)
    engine.applyEffects(curse,effect({armourReduce=2,armourReduceFortified=2,
        armourReduceRangedUnfortifiedOnly=2}),actualAttack)
    eq(curse.baseArmour,3,"Fortified Curse reduces melee Armour")
    eq(curse.rangeBaseArmour,5,"Fortified Curse cannot reduce Ranged Armour")
    local expose=enemy("expose",{fortified=true,pResist=true,fResist=true},nil,5,10)
    engine.prepareFortifications({expose},false)
    engine.applyEffects(expose,effect({removeFortify=true,removeResist=true,removeFireResist=true}),actualAttack)
    eq(expose.stripFortify,true,"Remove Fortification flag preserved")
    eq(expose.stripResist,true,"Remove Resistance flag preserved")
    eq(expose.stripFireResist,true,"Remove Fire Resistance flag preserved")
    print("Enemy defences, individual modifiers, grouped Armour, Resistance and effective Attack passed")
end)

run("resource-tracker-enemy-groups",function()
    -- Enemy group boundaries and resource collection use the production helpers.
    local engine=dofile("src/PlayingGame/PlayerBoard/ResourceTracker/Combat/EnemyGroups.lua")
    local entries={}
    for i=1,7 do entries[i]={guid=tostring(i)} end
    local joined={["1"]=true,["2"]=true,["3"]=true,["5"]=true,["6"]=true}
    local groups,of=engine.build(entries,joined)
    eq(#groups,3,"Consecutive joined enemies form groups")
    eq(#groups[1].members,3,"First group contains three enemies")
    eq(groups[1].leader,1,"First member is leader even if first join flag set")
    eq(groups[2].leader,4,"Second group begins at unjoined enemy")
    eq(groups[3].leader,7,"Single enemy is its own group")
    eq(of[3],groups[1],"Member maps to group")
    eq(of[6],groups[2],"Second group's members map correctly")
    eq(#groups[1].sources,0,"Fresh groups have empty source lists")
    local a,b,c={key="a"},{key="b"},{key="c"}
    local assigned={[1]={sources={a,b}},[3]={sources={c}},[4]={sources={{key="other"}}}}
    local members,sources=engine.collect(groups[1],entries,assigned)
    eq(#members,3,"All members included even without allocation")
    eq(members[2],entries[2],"Original member identity retained")
    eq(#sources,3,"All assigned sources included")
    eq(sources[1],a,"First assigned source first")
    eq(sources[2],b,"Within-member source order retained")
    eq(sources[3],c,"Later member appended")
    eq(#groups[1].sources,0,"Collection does not mutate group")
    eq(#assigned[1].sources,2,"Collection does not mutate allocations")
    members,sources=engine.collect(groups[3],entries,{})
    eq(#members,1,"Singleton has one member")
    eq(#sources,0,"Unassigned singleton has no sources")
    entries[2].destroyed=true
    local rebuilt,map=engine.build(entries,joined)
    eq(#rebuilt,5,"Destroyed member splits adjacent groups")
    eq(map[1].leader,1,"Surviving left member isolated")
    eq(map[2].leader,2,"Destroyed member isolated")
    eq(map[3].leader,3,"Surviving right member isolated")
    eq(#map[2].members,1,"Destroyed member not joined to live enemy")
    eq(#groups[1].members,3,"Original group not mutated by rebuild")
    entries[2].destroyed=nil
    entries[5].attackOnly=true
    rebuilt,map=engine.build(entries,joined)
    eq(#rebuilt,5,"Attack-only reminder splits adjacent groups")
    eq(map[5].leader,5,"Attack-only reminder is isolated")
    eq(map[6].leader,6,"Following joined enemy starts new group")
    eq(joined["5"],true,"Saved join flags untouched")
    local empty,emptyMap=engine.build({},joined)
    eq(#empty,0,"Empty combat has no groups")
    eq(next(emptyMap),nil,"Empty combat has no member map")
    print("Enemy group construction, rebuilding and ordered resources passed")
end)

if #failures>0 then
    error(table.concat(failures,"\n\n"),0)
end
