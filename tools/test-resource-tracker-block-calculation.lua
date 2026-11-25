-- Related regressions share a runner and fixtures while each case retains local state.
-- Run from repository root: lua5.2 tools/test-resource-tracker-block-calculation.lua

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

run("resource-tracker-block-solver",function()
    -- Exercise production Block allocation, including efficient and inefficient half-points.
    local engine=dofile("src/PlayingGame/PlayerBoard/ResourceTracker/Combat/BlockCalculation.lua").solver({COMBAT_EFFICIENT_BLOCKS={
        P={block=true,blockFire=true,blockIce=true,blockColdFire=true},
        F={blockIce=true,blockColdFire=true},I={blockFire=true,blockColdFire=true},
        IF={blockColdFire=true},M={blockPsychic=true}}})
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
    -- Equal-cost routes have a stable tie-break across input permutations.
    for pass=1,10 do
        local a,b=item("block",2,"a"),item("block",2,"b")
        local p,ordered=engine.solve({attack("P",2),attack("P",2)},
            pass%2==0 and {a,b} or {b,a},0)
        eq(ordered[1].source.key,"a","Source order stable")
        eq(p[1].used[1],true,"Equal allocation uses canonical route")
        eq(p[2].used[2],true,"Second Block uses remaining canonical route")
    end
    local many={}
    for i=1,14 do many[i]=item("block",1,tostring(i)) end
    plan,sorted,leftover=engine.solve({attack("P",14)},many,0)
    eq(plan[1].blocked,true,"More than twelve independent Block items remain supported")
    eq(engine.spent(attack("P",14),sorted,plan[1].used),14,"Every needed point used")
    print("Exact Block and Cumbersome Move allocation passed")
end)

run("resource-tracker-block-results",function()
    -- Production Block result assembly; cache lifecycle remains caller-owned.
    local cfg={sourceFields={{key="block",family="block"},{key="blockIce",family="block"}},
        COMBAT_EFFICIENT_BLOCKS={P={block=true,blockIce=true},F={blockIce=true},M={blockPsychic=true}},
        COMBAT_RED="red"}
    local solver=dofile("src/PlayingGame/PlayerBoard/ResourceTracker/Combat/BlockCalculation.lua").solver(cfg)
    local calls,bonus=0,0
    local actualSolve=solver.solve
    solver.solve=function(...)
        calls=calls+1
        return actualSolve(...)
    end
    local calculate=dofile("src/PlayingGame/PlayerBoard/ResourceTracker/Combat/BlockCalculation.lua").results(cfg,solver,function(entry)
        local attacks={}
        for i,a in ipairs(entry.attacks) do
            local copy={}
            for k,v in pairs(a) do copy[k]=v end
            attacks[i]=copy
        end
        return attacks
    end,function() return bonus end,function(value) return value end)
    local cache={}
    local function enemy(key,attacks)
        for i,a in ipairs(attacks) do a.owner=a.owner or key a.slot=i end
        return {guid=key,attacks=attacks}
    end
    local function source(key,amount,extra)
        local s={key=key,guid=key,block=amount,move=0,resources={block=amount}}
        for k,v in pairs(extra or {}) do s[k]=v end
        return s
    end
    local e=enemy("enemy",{{key="P",value=4}})
    local sources={source("bash",6,{excessBlockArmour=true}),source("spare",2)}
    local lines,damage,count,all,_,_,_,used,owners,excess,keys=calculate(e,sources,cache)
    eq(lines[1],"8/4 Blocked","Spare resources shown as over-block")
    eq(damage,0,"No damage from blocked attack")
    eq(count,0,"No damaging attack")
    eq(all,true,"Every attack blocked")
    eq(used.bash,true,"Successful Shield Bash committed")
    eq(used.spare,nil,"Displayed spare not committed")
    eq(owners.bash.enemy,true,"Successful attack owner retained")
    eq(excess.enemy,4,"Shield Bash counts displayed excess on same attack")
    eq(keys.spare,true,"Spare source contributing frozen Shield Bash reduction is locked")
    eq(calls,1,"Initial solve")
    local cachedLines=calculate(e,sources,cache)
    eq(cachedLines,lines,"Unchanged fingerprint returns cached result")
    eq(calls,1,"Unchanged fingerprint skips DP")
    calculate(e,sources,{})
    eq(calls,2,"Caller cache reset recomputes")
    local _,_,_,_,_,_,_,_,_,surplusExcess,surplusKeys=calculate(
        enemy("surplusBash",{{key="P",value=4}}),
        {source("ordinary",4),source("shieldBash",2,{excessBlockArmour=true})},cache)
    eq(surplusExcess.surplusBash,2,"Surplus Shield Bash grants Armour reduction")
    eq(surplusKeys.shieldBash,true,"Surplus Shield Bash cannot escape committed lock")
    eq(surplusKeys.ordinary,true,"Base Block contributing to reduction committed")
    local _,_,_,_,_,_,_,_,_,_,ordinaryKeys=calculate(
        enemy("ordinarySpare",{{key="P",value=4}}),
        {source("ordinary",4),source("spare",2)},cache)
    eq(ordinaryKeys.spare,nil,"Ordinary spare remains uncommitted without conditional effect")
    bonus=1
    local _,d=calculate(e,{source("normal",4)},cache)
    eq(d,4,"Competitive Block penalty changes threshold but not damage")
    eq(e.attacks[1].value,4,"Printed attack unchanged")
    bonus=0
    e=enemy("multi",{{key="P",value=3},{key="P",value=3,owner="summon"}})
    local _,multiDamage,_,blocked,_,_,_,multiUsed,multiOwners=calculate(e,
        {source("shield",6,{repeatBlocks=2})},cache)
    eq(multiDamage,0,"Repeated Blocks can block separate attacks")
    eq(blocked,true,"Both attacks blocked")
    eq(multiUsed.shield,true,"Repeated source committed")
    eq(multiOwners.shield.multi,true,"First attack owner retained")
    eq(multiOwners.shield.summon,true,"Summoned owner retained")
    e=enemy("psychic",{{key="M",value=1},{key="M",value=1}})
    local _,psychicDamage,_,psychicAll,_,_,_,_,_,_,psychicKeys=calculate(e,
        {source("influence",0,{psychicInfluenceCounts=true,psychicInfluence=2})},cache)
    eq(psychicDamage,0,"Influence split into individual Psychic points")
    eq(psychicAll,true,"Both Psychic attacks blocked")
    eq(psychicKeys.influence,true,"Successful Influence source committed")
    e=enemy("fire",{{key="F",value=3}})
    local _,fireDamage,_,_,_,wrong=calculate(e,{source("ordinary",4)},cache)
    eq(fireDamage,3,"Failed inefficient Block does not reduce damage")
    eq(wrong.ordinaryblock,true,"Inefficient Block marked for display")
    e=enemy("move",{{key="P",value=5,cumbersome=true}})
    local _,moveDamage,_,_,reductions,_,_,_,_,_,_,moveKeys=calculate(e,
        {source("moveA",0,{moveCounts=true,move=2})},cache)
    eq(moveDamage,3,"Cumbersome partial Move reduces damage")
    eq(reductions[1],2,"Effective Move recorded")
    eq(moveKeys.moveA,true,"Spent Move committed")
    local _,_,_,_,_,_,_,_,_,_,_,replacement=calculate(e,
        {source("moveB",0,{moveCounts=true,move=2})},cache)
    eq(replacement.moveB,true,"Replacement same-valued Move committed")
    eq(replacement.moveA,nil,"Old Move cannot survive cache fingerprint")
    print("Block results, fingerprints, Shield Bash and phase resource accounting passed")
end)

if #failures>0 then
    error(table.concat(failures,"\n\n"),0)
end
