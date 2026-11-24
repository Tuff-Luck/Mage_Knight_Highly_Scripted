-- Exercise production Block allocation, including efficient and inefficient half-points.
local engine=dofile("src/PlayingGame/PlayerBoard/ResourceTracker/BlockSolver.lua")({COMBAT_EFFICIENT_BLOCKS={
    P={block=true,blockFire=true,blockIce=true,blockColdFire=true},
    F={blockIce=true,blockColdFire=true},I={blockFire=true,blockColdFire=true},
    IF={blockColdFire=true},M={blockPsychic=true}}})
local function eq(actual,expected,label)
    assert(actual==expected,label..": expected "..tostring(expected)..", got "..tostring(actual))
end
local function item(key,value,id,extra,swiftDouble)
    local source=extra or {}
    source.key=id
    return {key=key,value=value,source=source,swiftDouble=swiftDouble}
end
local function attack(key,value,extra)
    local a=extra or {}
    a.key,a.value=key,value
    return a
end
local plan,sorted,leftover=engine.solve({attack("F",3)},
    {item("block",3,"a"),item("blockFire",3,"b")},0)
eq(plan[1].blocked,true,"Two inefficient odd amounts sum before rounding")
eq(engine.spent(attack("F",3),sorted,plan[1].used),3,"Displayed Block matches allocation")
eq(#leftover,0,"Both inefficient Blocks required")
plan,sorted,leftover=engine.solve({attack("F",3)},
    {item("blockIce",3,"a"),item("block",1,"b")},0)
eq(plan[1].blocked,true,"Efficient Ice blocks Fire")
eq(#leftover,1,"Spare Block not consumed")
eq(engine.spent(attack("F",3),sorted,plan[1].used),3,"Only needed efficient Block counted")
plan=engine.solve({attack("P",4,{swift=true})},{item("block",4,"a",nil,true)},0)
eq(plan[1].blocked,true,"Swift-double resource covers Swiftness")
plan=engine.solve({attack("P",4,{swift=true})},{item("block",4,"a")},0)
eq(plan[1].blocked,false,"Normal Block does not cover doubled requirement")
plan=engine.solve({attack("M",2)},{item("block",2,"a",{heroPsychicBlock=true})},0)
eq(plan[1].blocked,true,"Special hero Block efficient against Psychic")
plan=engine.solve({attack("P",1)},{item("blockPsychic",10,"a")},0)
eq(plan[1].blocked,false,"Psychic-only Influence cannot block Physical")
eq(engine.legal(attack("P",1),item("blockPsychic",10,"a")),false,"Shared legality rejects Psychic on Physical")
plan=engine.solve({attack("P",4,{cumbersome=true})},{item("block",2,"a")},2)
eq(plan[1].blocked,true,"Move and Block jointly stop Cumbersome")
eq(plan[1].reduction,2,"Move reduces the attack by two")
plan=engine.solve({attack("P",5,{cumbersome=true})},{},2)
eq(plan[1].blocked,false,"Partial Move cannot fully Block")
eq(plan[1].reduction,2,"Partial Move still reduces damage")
plan,sorted,leftover=engine.solve({attack("P",4),attack("P",3,{brutal=true})},
    {item("block",4,"a")},0)
eq(plan[1].blocked,false,"Single resource cannot be spent twice")
eq(plan[2].blocked,true,"Optimiser prefers stopping greater Brutal damage")
local many={}
for i=1,14 do many[i]=item("block",1,tostring(i)) end
plan,sorted,leftover=engine.solve({attack("P",14)},many,0)
eq(plan[1].blocked,true,"More than twelve independent Block items remain supported")
eq(engine.spent(attack("P",14),sorted,plan[1].used),14,"Every needed point used")
print("Exact Block and Cumbersome Move allocation passed")
