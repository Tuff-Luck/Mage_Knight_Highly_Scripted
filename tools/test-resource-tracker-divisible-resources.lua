-- Direct tests of split-resource conservation, eligibility and icon records.
local counts,cumbersome={},{}
local split=dofile("src/PlayingGame/PlayerBoard/ResourceTracker/Combat/DivisibleResources.lua")(
    function(key) return counts end,
    function(guid) return cumbersome[guid]==true end,
    function(entry) return entry.attacks or {} end)
local function eq(actual,expected,label)
    assert(actual==expected,label..": expected "..tostring(expected)..", got "..tostring(actual))
end
local entries={{guid="p"},{guid="a",attacks={{key="M"}}},{guid="b",attacks={{key="P"}}},
    {guid="c",attacks={{key="M"}}}}
local rows={p=1,a=2,b=3,c=4}
local function make()
    return {range={},block={},attack={},sources={},details={}}
end
local function base()
    return {guid="card",key="card#1",name="Test",ranged=0,siege=0,block=0,attack=0,
        move=0,psychicInfluence=0,resources={},details={}}
end
local function run(source,explicit)
    local allocated={[1]=make()}
    split(source,allocated[1],"p",explicit,rows,entries,allocated)
    return allocated
end
local source=base()
source.convertedResource,source.convertedFamily,source.convertedAmount="attackFire","attack",5
source.attack,source.resources.attackFire=5,5
source.details={{key="attackFire",family="attack",amount=5,icon="fire",typeKey="F",text="Fire Attack 5"}}
counts={p=20,a=2,b=1,missing=99}
local a=run(source,false)
eq(source.attack,2,"Converted primary receives unspent points")
eq(source.resources.attackFire,2,"Converted resource amount matches primary")
eq(a[2].sources[1].attack,2,"Two arrows spend two converted points")
eq(a[3].sources[1].attack,1,"Second extra target receives one point")
eq(a[2].sources[1].resources.attackFire,2,"Elemental resource preserved")
eq(a[2].details[1].detail.typeKey,"F","Element preserved on split detail")
eq(a[2].details[1].detail.icon,"fire","Icon preserved")
eq(a[2].sources[1].key,"card#1","Original targeting identity retained")
eq(a[1].details[1].detail.amount,2,"Primary detail reduced")
eq(a[1].sources[1],source,"Primary source identity retained")
eq(source.attack+a[2].sources[1].attack+a[3].sources[1].attack,5,"Converted points conserved")
source=base()
source.convertedResource,source.convertedFamily,source.convertedAmount="siege","siege",3
source.siege,source.resources.siege=3,3
source.details={{key="siege",family="siege",amount=3}}
counts={c=5,a=2,b=4}
a=run(source,false)
eq(a[2].sources[1].siege,2,"Sorted first extra gets first points")
eq(a[3].sources[1].siege,1,"Second extra capped by remainder")
eq(a[4],nil,"Exhausted source cannot allocate further")
eq(source.siege,0,"Fully distributed source has zero primary")
eq(#a[1].details,0,"Exhausted primary hides its icon")
source=base()
source.move,source.moveCounts,source.resources.move=5,true,5
source.details={{family="move",key="move",amount=5,text="Move 5"}}
cumbersome={a=true,c=true}
counts={a=2,b=5,c=1,missing=10}
a=run(source,true)
eq(source.move,2,"Cumbersome Move remainder")
eq(source.resources.move,2,"Move resource pool reduced")
eq(a[2].sources[1].move,2,"First Cumbersome target receives Move")
eq(a[2].sources[1].moveCounts,true,"Split Move remains eligible")
eq(a[3],nil,"Non-Cumbersome target receives no Move")
eq(a[4].sources[1].move,1,"Other Cumbersome target receives Move")
eq(a[1].details[1].detail.text,"Move 2","Primary Move detail refreshed")
eq(source.move+a[2].sources[1].move+a[4].sources[1].move,5,"Move points conserved")
source=base()
source.move=3
source.details={{family="move",key="move",amount=3}}
a=run(source,false)
eq(#a[1].details,0,"Ordinary movement not displayed as combat Move")
eq(a[2],nil,"Unallocated Move does not split")
eq(source.move,3,"Ordinary Move unaffected")
source=base()
source.psychicInfluence,source.psychicInfluenceCounts=4,true
source.details={{family="influence",key="influence",amount=4}}
counts={a=2,b=5,c=10,p=99}
a=run(source,false)
eq(a[2].sources[1].psychicInfluence,2,"Psychic target receives two points")
eq(a[3],nil,"Physical attacker cannot receive Psychic Influence")
eq(a[4].sources[1].psychicInfluence,2,"Later Psychic target capped by remainder")
eq(source.psychicInfluence,0,"Influence remainder exhausted")
eq(#a[1].details,0,"Exhausted Influence icon removed")
eq(a[4].details[1].detail.icon,"MKChoiceBlock","Psychic Influence remains Block")
eq(a[4].sources[1].psychicInfluenceCounts,true,"Split Influence is valid")
eq(a[2].sources[1].psychicInfluence+a[4].sources[1].psychicInfluence,4,"Influence points conserved")
source=base()
source.attack=2
source.details={{family="attack",key="attack",amount=2},{family="influence",amount=3}}
a=run(source,false)
eq(#a[1].details,1,"Uncommitted Influence filtered out")
eq(a[1].details[1].detail.family,"attack","Ordinary Attack detail retained")
eq(a[2],nil,"Ordinary Attack not duplicated across arrows")
print("Divisible combat resources, target eligibility and conservation passed")
