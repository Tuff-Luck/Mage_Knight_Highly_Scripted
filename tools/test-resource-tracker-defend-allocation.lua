-- Defend allocation uses the production enemy defences and Ranged/Siege evaluator.
local root="src/PlayingGame/PlayerBoard/"
local cfg={attackTypes={{key="P",attack="attack",ranged="ranged",siege="siege"}},
    artifactCombat={},bowSourceModes={}}
local defences=dofile(root.."ResourceTracker/Combat/EnemyDefences.lua")(cfg)
local function read(path)
    local f=assert(io.open(path,"r"))
    local text=f:read("*a")
    f:close()
    return text
end
local text=read(root.."CardRecognition.lua")
local first=assert(text:find("local function combatRangeResult(",1,true))
local last=assert(text:find("-- Block cells hold block",first,true))
local env=setmetatable({combatEnemyFortificationCount=defences.fortificationCount,
    combatAttackTotal=defences.attackTotal,combatEnemyHasTrait=defences.hasTrait,
    gStates={}},{__index=_G})
local range=assert(load(text:sub(first,last-1).."\nreturn combatRangeResult","range","t",env))()
local allocate=dofile(root.."ResourceTracker/Combat/DefendAllocation.lua")(defences,range)
local function eq(actual,expected,label)
    assert(actual==expected,label..": expected "..tostring(expected)..", got "..tostring(actual))
end
local function enemy(guid,armour,printed,perks)
    return {guid=guid,data=printed or {},perks=perks,baseArmour=armour,elusiveArmour=armour*2}
end
local function group(...)
    return {members={...}}
end
local function assigned(family,amount,extra)
    local source={resources={[family]=amount}}
    for k,v in pairs(extra or {}) do source[k]=v end
    return {sources={source},details={{detail={family=family},source=source}}}
end
local function apply(entries,groups,allocated,phase)
    env.gStates.forkedLightningPhase=phase
    return allocate(entries,groups,allocated,phase)
end
local e={enemy("a",3)}
e[1].defendMeleeBonus=5
local bonuses=apply(e,{group(1)},{[1]=assigned("attack",4)})
eq(next(bonuses),nil,"No defenders means no bonus")
eq(e[1].defendMeleeBonus,nil,"Old late bonus cleared")
-- Stronger defender protects the first ranged target; weaker defender can
-- protect another target later only if it survives the ranged phase.
e={enemy("weak",2,{defend=1}),enemy("melee",4),enemy("strong",3,{}, {defend=2})}
bonuses=apply(e,{group(1),group(2),group(3)},{[1]=assigned("ranged",4),[2]=assigned("attack",6)})
eq(bonuses[1],2,"Stronger perk defender protects first ranged target")
eq(bonuses[2],nil,"Ranged-defeated remaining defender cannot protect melee")
eq(e[1].baseArmour,4,"Ranged protection increases base Armour")
eq(e[1].defendMeleeBonus,nil,"Ranged protection is not late")
eq(e[3].perks.defend,2,"Original perk remains unchanged")
e={enemy("weak",2,{defend=1}),enemy("melee",4),enemy("strong",3,{defend=2})}
e[2].rangeBaseArmour,e[2].rangeElusiveArmour=4,8
bonuses=apply(e,{group(1),group(2),group(3)},{[1]=assigned("ranged",3),[2]=assigned("attack",6)})
eq(bonuses[1],2,"Stronger defender protects ranged attack")
eq(bonuses[2],1,"Surviving weaker defender protects melee")
eq(e[2].defendMeleeBonus,1,"Late bonus is explicitly tracked")
eq(e[2].baseArmour,5,"Late protection increases melee Armour")
eq(e[2].elusiveArmour,9,"Late protection increases Elusive Armour")
eq(defences.rangeGroupEntry({e[2]}).baseArmour,4,"Late bonus cannot retroactively raise range Armour")
-- A joined attack is aimed at every member, even when all icons belong to one.
e={enemy("left",2),enemy("right",3),enemy("d1",3,{defend=3}),enemy("d2",3,{defend=1})}
bonuses=apply(e,{group(1,2),group(3),group(4)},{[1]=assigned("ranged",5)})
eq(bonuses[1],3,"Joined left member protected by stronger defender")
eq(bonuses[2],1,"Joined right member independently protected")
eq(e[2].baseArmour,4,"Joined protection applies to actual member")
-- Only legal ranged/siege attacks can receive early protection.
e={enemy("wall",3,{fortified=true}),enemy("d",3,{defend=2})}
bonuses=apply(e,{group(1),group(2)},{[1]=assigned("ranged",5)})
eq(e[1].defendMeleeBonus,2,"Fortified target's Ranged source falls to melee")
e={enemy("wall",3,{fortified=true}),enemy("d",3,{defend=2})}
bonuses=apply(e,{group(1),group(2)},{[1]=assigned("siege",5)})
eq(bonuses[1],2,"Siege can attack singly fortified target")
eq(e[1].defendMeleeBonus,nil,"Legal Siege protection is early")
e={enemy("fork",3),enemy("d",3,{defend=2})}
bonuses=apply(e,{group(1),group(2)},{[1]=assigned("ranged",5,{forkedLightning=true})},"attack")
eq(e[1].defendMeleeBonus,2,"Melee-selected Forked Lightning is not early")
e={enemy("first",2),enemy("second",2),enemy("d",3,{defend=3})}
e[3].destroyed=true
bonuses=apply(e,{group(1),group(2),group(3)},{[1]=assigned("attack",4),[2]=assigned("attack",4)})
eq(next(bonuses),nil,"Destroyed defender cannot protect")
e={enemy("first",2),enemy("second",2),enemy("d",3,{defend=3})}
e[1].attackOnly=true
bonuses=apply(e,{group(1),group(2),group(3)},{[1]=assigned("attack",4),[2]=assigned("attack",4)})
eq(bonuses[1],nil,"Attack-only reminder is not a protected target")
eq(bonuses[2],3,"Eligible target receives the bonus")
print("Defend allocation, grouped protection and phase timing passed")
