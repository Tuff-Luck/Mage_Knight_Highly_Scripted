-- Flame Wave uses production defensive and Ranged/Siege calculation helpers.
local root="src/PlayingGame/PlayerBoard/"
local cfg={attackTypes={{key="P",attack="attack",ranged="ranged",siege="siege"}},
    artifactCombat={},bowSourceModes={}}
local defences=dofile(root.."ResourceTracker/Combat/EnemyProperties.lua").defences(cfg)
local function read(path)
    local f=assert(io.open(path,"r"))
    local value=f:read("*a")
    f:close()
    return value
end
local text=read(root.."CardRecognition.lua")
local first=assert(text:find("local function combatRangeResult(",1,true))
local last=assert(text:find("-- Block cells hold block",first,true))
local env=setmetatable({combatEnemyFortificationCount=defences.fortificationCount,
    combatAttackTotal=defences.attackTotal,combatEnemyHasTrait=defences.hasTrait,
    gStates={}},{__index=_G})
local range=assert(load(text:sub(first,last-1).."\nreturn combatRangeResult","range","t",env))()
local defend=dofile(root.."ResourceTracker/Combat/DefendAllocation.lua")(defences,range)
local groupsModule=dofile(root.."ResourceTracker/Combat/EnemyGroups.lua")
local previews=0
local apply=dofile(root.."ResourceTracker/Combat/FlameWave.lua")(
    function(entries,groups,allocated)
        previews=previews+1
        return defend(entries,groups,allocated,env.gStates.forkedLightningPhase)
    end,groupsModule.collect,defences.rangeGroupEntry,range)
local function eq(actual,expected,label)
    assert(actual==expected,label..": expected "..tostring(expected)..", got "..tostring(actual))
end
local function enemy(guid,armour,data,flags)
    local e={guid=guid,data=data or {},baseArmour=armour,elusiveArmour=armour*2}
    for k,v in pairs(flags or {}) do e[k]=v end
    return e
end
local function shot(amount,family)
    family=family or "ranged"
    local source={guid="shot",key="shot",resources={[family]=amount},
        ranged=family=="ranged" and amount or 0,siege=family=="siege" and amount or 0}
    return {sources={source},details={{source=source,detail={family=family,amount=amount}}}}
end
local function wave(family,initial,other)
    local key=family=="attack" and "attackFire" or "blockFire"
    local s={flameWave=true,resources={[key]=initial},details={{key=key,amount=initial,text="old"},
        {key="unrelated",amount=other or 0}}}
    s[family]=initial+(other or 0)
    return s
end
local function run(entries,joined,allocated,sources)
    local groups=groupsModule.build(entries,joined or {})
    apply(entries,groups,allocated or {},sources)
end
local attack,block=wave("attack",5,3),wave("block",7,2)
local entries={enemy("killed",3),enemy("survivor",4),enemy("reminder",1,{}, {attackOnly=true}),
    enemy("destroyed",3,{}, {destroyed=true})}
run(entries,{}, {[1]=shot(3)}, {attack,block})
eq(attack.resources.attackFire,7,"One surviving enemy grants two Fire Attack")
eq(attack.attack,10,"Other Attack contribution retained")
eq(attack.details[1].text,"Fire Attack 7","Attack display refreshed")
eq(attack.details[2].amount,3,"Unrelated detail unchanged")
eq(block.resources.blockFire,9,"One surviving enemy grants two Fire Block")
eq(block.block,11,"Other Block contribution retained")
eq(block.details[1].text,"Fire Block 9","Block display refreshed")
run(entries,{}, {[1]=shot(3)}, {attack,block})
eq(attack.attack,10,"Repeated recalculation does not accumulate bonus")
eq(block.block,11,"Repeated Block recalculation stable")
-- A defender protects the first Ranged target in preview only.
entries={enemy("victim",3),enemy("defender",4,{defend=2})}
attack=wave("attack",5)
run(entries,{}, {[1]=shot(3)}, {attack})
eq(attack.attack,9,"Defender saves ranged target and both enemies count")
eq(entries[1].baseArmour,3,"Defender preview does not mutate real Armour")
eq(entries[1].defendMeleeBonus,nil,"Preview does not leak late bonus")
-- A joined group is either defeated together or counted per surviving member.
entries={enemy("first",2),enemy("second",3),enemy("last",4)}
attack=wave("attack",5)
run(entries,{second=true},{[1]=shot(5)},{attack})
eq(attack.attack,7,"Joined ranged defeat excludes both members")
run(entries,{second=true},{[1]=shot(4)},{attack})
eq(attack.attack,11,"Surviving joined group counts each enemy")
entries={enemy("wall",3,{fortified=true})}
block=wave("block",7)
run(entries,{}, {[1]=shot(3)}, {block})
eq(block.block,9,"Fortified enemy survives ordinary Ranged")
run(entries,{}, {[1]=shot(3,"siege")}, {block})
eq(block.block,7,"Legal Siege defeat leaves only base Block")
attack=wave("attack",5)
run({}, {}, {}, {attack})
eq(attack.attack,5,"No surviving enemies leaves base Attack")
local previous=previews
local ordinary={resources={attack=4},attack=4,details={}}
run(entries,{}, {}, {ordinary})
eq(previews,previous,"No Flame Wave skips preview")
eq(ordinary.attack,4,"Ordinary resources unaffected")
print("Flame Wave surviving-enemy count, Defender timing and resource updates passed")
