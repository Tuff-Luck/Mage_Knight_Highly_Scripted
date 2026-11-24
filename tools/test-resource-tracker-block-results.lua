-- Production Block result assembly; cache lifecycle remains caller-owned.
local cfg={sourceFields={{key="block",family="block"},{key="blockIce",family="block"}},
    COMBAT_EFFICIENT_BLOCKS={P={block=true,blockIce=true},F={blockIce=true},M={blockPsychic=true}},
    COMBAT_RED="red"}
local solver=dofile("src/PlayingGame/PlayerBoard/ResourceTracker/BlockSolver.lua")(cfg)
local calls,bonus=0,0
local actualSolve=solver.solve
solver.solve=function(...)
    calls=calls+1
    return actualSolve(...)
end
local calculate=dofile("src/PlayingGame/PlayerBoard/ResourceTracker/BlockResults.lua")(cfg,solver,function(entry)
    local attacks={}
    for i,a in ipairs(entry.attacks) do
        local copy={}
        for k,v in pairs(a) do copy[k]=v end
        attacks[i]=copy
    end
    return attacks
end,function() return bonus end,function(value) return value end)
local cache={}
local function eq(actual,expected,label)
    assert(actual==expected,label..": expected "..tostring(expected)..", got "..tostring(actual))
end
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
eq(keys.spare,nil,"Spare source key not locked")
eq(calls,1,"Initial solve")
local cachedLines=calculate(e,sources,cache)
eq(cachedLines,lines,"Unchanged fingerprint returns cached result")
eq(calls,1,"Unchanged fingerprint skips DP")
calculate(e,sources,{})
eq(calls,2,"Caller cache reset recomputes")
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
