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
local points={}
for i=1,5 do points[i]=item("Influence","blockPsychic",1) end
plan=solve({attack("M",2),attack("M",3)},points,0)
check("one Influence source splits five points across Psychic attacks",plan[1].blocked and plan[2].blocked)
plan=solve({attack("P",6,{cumbersome=true})},{item("block","block",4)},2)
check("Cumbersome Move works together with Block",plan[1].blocked and plan[1].reduction==2)
local attacks={attack("P",6),attack("F",4)}
reduce(attacks,{attackReductions={{amount=3,source="u"}}},nil,2)
check("player can select the second Attack for reduction",attacks[1].value==6 and attacks[2].value==1)
attacks={attack("P",6),attack("F",4)}
reduce(attacks,{attackReductions={{amount=3,source="u"}}},nil,nil)
check("automatic reduction still chooses strongest Attack",attacks[1].value==3 and attacks[2].value==4)
local unit={guid="unit",name="Tester",armour=6,level=2,resist={},wounded=false}
local resolved=damage({{key="enemy:1",type="M",damage=4}}, {unit=unit},2,function() return {"unit"} end)
check("Psychic damage uses Unit level instead of printed Armor",
    resolved["enemy:1"].units[1].wounded and resolved["enemy:1"].heroWounds==1)
print("Combat calculator regression tests passed.")
