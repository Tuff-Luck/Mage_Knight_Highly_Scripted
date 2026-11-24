-- Production defence calculations; no TTS objects or saved state required.
local cfg={attackTypes={
    {key="P",attack="attack",ranged="ranged",siege="siege"},
    {key="F",attack="attackFire",ranged="rangedFire",siege="siegeFire"},
    {key="I",attack="attackIce",ranged="rangedIce",siege="siegeIce"},
    {key="IF",attack="attackColdFire",ranged="rangedColdFire",siege="siegeColdFire"}},
    artifactCombat={},bowSourceModes={}}
local engine=dofile("src/PlayingGame/PlayerBoard/ResourceTracker/Combat/EnemyProperties.lua").defences(cfg)
local function eq(actual,expected,label)
    assert(actual==expected,label..": expected "..tostring(expected)..", got "..tostring(actual))
end
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
