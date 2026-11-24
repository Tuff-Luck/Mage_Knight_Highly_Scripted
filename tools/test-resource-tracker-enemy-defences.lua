-- Production defence calculations; no TTS objects or saved state required.
local cfg={attackTypes={
    {key="P",attack="attack",ranged="ranged",siege="siege"},
    {key="F",attack="attackFire",ranged="rangedFire",siege="siegeFire"},
    {key="I",attack="attackIce",ranged="rangedIce",siege="siegeIce"},
    {key="IF",attack="attackColdFire",ranged="rangedColdFire",siege="siegeColdFire"}},
    artifactCombat={},bowSourceModes={}}
local engine=dofile("src/PlayingGame/PlayerBoard/ResourceTracker/EnemyDefences.lua")(cfg)
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
print("Enemy defences, grouped Armour, Resistance and effective Attack passed")
