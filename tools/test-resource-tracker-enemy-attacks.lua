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
local engine=dofile("src/PlayingGame/PlayerBoard/ResourceTracker/Combat/EnemyAttacks.lua")(kinds,trait,fortifications)
local function eq(a,b,label)
    assert(a==b,label..": expected "..tostring(b)..", got "..tostring(a))
end
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
