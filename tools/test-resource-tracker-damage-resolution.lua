-- Direct tests of the production resolver with caller-owned runtime dependencies.
local fortitude={}
local summons={child="parent"}
local engine=dofile("src/PlayingGame/PlayerBoard/ResourceTracker/DamageResolution.lua")(
    function(guid) return guid=="retired" and {name={"Retired Unit"}} or nil end,
    function(owner,summoner) return summons[owner]==summoner end,
    function() return fortitude end)
local function eq(actual,expected,label)
    assert(actual==expected,label..": expected "..tostring(expected)..", got "..tostring(actual))
end
local function unit(resist,extra)
    local u={guid="u",armour=3,level=2,resist=resist or {},wounded=false}
    for key,value in pairs(extra or {}) do u[key]=value end
    return u
end
local function attack(key,damage,extra)
    local a={owner="enemy",key=key,type="P",damage=damage}
    for k,v in pairs(extra or {}) do a[k]=v end
    return a
end
local function targets() return {"u"} end
local function none() return {} end
local function hit(a,u,mitigation,element,veil,prior)
    return engine.resolve({a},u and {u=u} or {},3,u and targets or none,
        mitigation,element,veil,prior)[a.key]
end
eq(engine.unitResists(unit({F=true}),"IF"),false,"Cold Fire requires both resistances")
eq(engine.unitResists(unit({F=true,I=true}),"IF"),true,"Both elements resist Cold Fire")
local result=hit(attack("r",3,{type="F"}),unit({F=true}))
eq(result.units[1].wounded,false,"Resisting Unit absorbs Armour without wound")
eq(result.heroWounds,0,"Fully absorbed damage does not reach Hero")
result=hit(attack("r",7,{type="F",poison=true}),unit({F=true}))
eq(result.unitWounds,2,"Poison wounds a resisting Unit only after Armour exceeded")
eq(result.heroDamage,1,"Resistance absorbs twice Armour on a wounded Unit")
eq(result.discard,1,"Remaining Poison wound adds discard")
result=hit(attack("m",4,{type="M"}),unit({}))
eq(result.heroDamage,2,"Psychic uses Unit level rather than Armour")
result=hit(attack("p",5,{paralyse=true}),unit({}, {arcaneImmunity=true}))
eq(result.units[1].destroyed,false,"Arcane Immunity protects Unit from Paralyse")
eq(result.unitWounds,1,"Immune Unit still wounded")
result=hit(attack("p",5,{paralyse=true}),unit({}))
eq(result.units[1].destroyed,true,"Paralyse destroys ordinary Unit")
eq(result.units[1].absorbed,3,"Destroyed Unit retains absorbed damage")
result=hit(attack("p",5,{paralyse=true}),nil,nil,nil,nil,{p={destroyed={retired=3}}})
eq(result.heroDamage,2,"Previously destroyed Unit continues absorbing damage")
eq(result.units[1].unit.name,"Retired Unit","Retired name from live card data callback")
eq(result.units[1].alreadyApplied,true,"Retired Unit does not generate another physical wound")
local mitigation={owner="parent",physical=2,nonphysical=1}
local element={owner="parent"}
result=hit(attack("s",5,{owner="child",type="F"}),nil,mitigation,element)
eq(result.prevented,1,"Summoner Battle Hardened applies to summoned attack")
eq(result.elementPrevented,2,"Summoner Elemental Resistance applies to summoned attack")
eq(result.heroDamage,2,"Mitigation remains additive after Unit damage")
eq(mitigation.appliedKey,"s","Battle Hardened records actual printed attack")
eq(element.appliedKey,"s","Elemental Resistance records actual printed attack")
local u=unit({}, {fortitudeUsed=true,fortitudeGUID="banner"})
result=hit(attack("first",3,{poison=true,paralyse=true}),u)
eq(result.unitWounds,0,"Fortitude prevents Poison and normal Unit wounds")
eq(result.units[1].destroyed,nil,"Fortitude prevents destruction")
eq(fortitude.banner.attackKey,"first","Fortitude usage stored with caller")
eq(hit(attack("first",3),u).unitWounds,0,"Same attack rescans are protected")
eq(hit(attack("second",3),u).unitWounds,1,"Different attack cannot reuse Fortitude")
local hits=engine.resolve({attack("one",3,{poison=true,paralyse=true}),
    attack("two",3,{poison=true})},{},3,none,nil,nil,true)
eq(hits.one.heroWounds,0,"Veil ignores first Hero wound")
eq(hits.one.paralyse,false,"Ignored wound does not paralyse")
eq(hits.one.discard,0,"Ignored wound does not generate Poison discard")
eq(hits.two.heroWounds,1,"Later wound is not ignored")
eq(hits.two.discard,1,"Later Poison discard applies")
print("Ordered damage resolution, Unit resistance, Hero mitigation and Fortitude passed")
