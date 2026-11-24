-- Explosive Bolt regressions using production enemy defences and phase evaluator.
local root="src/PlayingGame/PlayerBoard/"
local cfg={attackTypes={{key="P",attack="attack",ranged="ranged",siege="siege"}},
    artifactCombat={},bowSourceModes={}}
local defences=dofile(root.."ResourceTracker/Combat/EnemyDefences.lua")(cfg)
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
local targets,saved,calls={},{},{}
local apply=dofile(root.."ResourceTracker/Combat/ExplosiveBolt.lua")(
    function(entries,groups,allocated) return defend(entries,groups,allocated,env.gStates.forkedLightningPhase) end,
    defences.rangeGroupEntry,range,defences.hasTrait,
    function(key) return targets[key] end,
    function(key) return saved[key] or {} end,
    function(key,guid,arrow)
        calls[#calls+1]={key=key,guid=guid,arrow=arrow}
        targets[key]=guid
    end)
local function eq(actual,expected,label)
    assert(actual==expected,label..": expected "..tostring(expected)..", got "..tostring(actual))
end
local function enemy(guid,armour,printed,perks)
    return {guid=guid,data=printed or {},perks=perks,baseArmour=armour,elusiveArmour=armour*2}
end
local function bolt(guid,amount,extra)
    local s={guid=guid,key=guid,ranged=amount,siege=0,
        resources={ranged=amount},explosiveBolt=1}
    for k,v in pairs(extra or {}) do s[k]=v end
    return s
end
local function group(...)
    return {members={...}}
end
local function assigned(...)
    local sources={...}
    local details={}
    for _,source in ipairs(sources) do
        details[#details+1]={detail={family=source.siege>0 and "siege" or "ranged"},source=source}
    end
    return {sources=sources,details=details}
end
local function reset()
    targets,saved,calls={},{},{}
end
local function effect(entry,guid)
    for _,record in ipairs(entry.explosiveBoltEffects or {}) do
        if record.guid==guid then return record end
    end
    error("Missing Explosive Bolt record "..guid)
end
-- A real ranged defeat unlocks one point, which may enable a second bolt.
local a,b=bolt("a",3),bolt("b",3)
local e={enemy("first",3),enemy("second",4),enemy("third",5)}
targets["a#explosiveAttack"]="second"
targets["b#explosiveAttack"]="third"
apply(e,{group(1),group(2),group(3)},{assigned(a),assigned(b)}, {a,b})
eq(e[2].baseArmour,3,"First independent defeat unlocks next ranged kill")
eq(e[3].baseArmour,4,"Second earned bolt reaches later target")
eq(e[3].rangeBaseArmour,4,"Reduction applies in Ranged and Attack phases")
eq(e[3].effectArmourReduction,1,"Effective reduction recorded")
eq(effect(e[2],"a").earned,1,"First victim counted once")
eq(effect(e[3],"b").applied,1,"Second bonus applied once")
eq(calls[1].arrow,"other","Follow-up arrow uses shared special-effect colour")
eq(targets["a#explosiveAttack"],"second","Chosen target retained")
-- Two mutually dependent attacks cannot manufacture a defeat.
reset()
e={enemy("first",4),enemy("second",4)}
targets["a#explosiveAttack"]="second"
targets["b#explosiveAttack"]="first"
apply(e,{group(1),group(2)},{assigned(a),assigned(b)},{a,b})
eq(e[1].baseArmour,4,"No circular first reduction")
eq(e[2].baseArmour,4,"No circular second reduction")
eq(effect(e[1],"b").earned,0,"No independently defeated enemy")
eq(effect(e[2],"a").applied,0,"No unearned reduction")
-- Joined enemies yield a bonus per victim, not per duplicate source entry.
reset()
local left=bolt("joined",2)
local right=bolt("joined",2)
right.key="joined#second"
e={enemy("left",2),enemy("right",2),enemy("target",5)}
targets["joined#explosiveAttack"]="target"
apply(e,{group(1,2),group(3)},{assigned(left),assigned(right)},{left})
eq(effect(e[3],"joined").earned,2,"Joined group earns one per defeated enemy")
eq(e[3].baseArmour,3,"Duplicate physical source not credited twice")
-- Targeting respects saved assignments and explicit immune targets.
reset()
e={enemy("victim",3),enemy("immune",5,{fResist=true}),enemy("other",4)}
saved["a#explosiveAttack"]={immune=true}
apply(e,{group(1),group(2),group(3)},{assigned(a)},{a})
eq(e[2].baseArmour,5,"Fire Resistance prevents reduction")
eq(effect(e[2],"a").earned,1,"Immune target still displays earned amount")
eq(effect(e[2],"a").applied,0,"Immune target displays no benefit")
eq(targets["a#explosiveAttack"],"immune","Saved explicit immune target retained")
eq(e[3].baseArmour,4,"No unauthorized retarget to nonimmune enemy")
reset()
e={enemy("victim",3),enemy("immune",5,{}, {arcaneImmunity=true})}
apply(e,{group(1),group(2)},{assigned(a)},{a})
eq(e[2].baseArmour,5,"Perk Arcane Immunity prevents reduction")
eq(targets["a#explosiveAttack"],"immune","Default skips ranged-defeated enemy")
reset()
e={enemy("victim",3),enemy("floor",1)}
apply(e,{group(1),group(2)},{assigned(a)},{a})
eq(e[2].baseArmour,1,"Armour floor remains one")
eq(effect(e[2],"a").applied,0,"No reduction below Armour floor")
-- Ordinary Ranged cannot earn a bonus against a fortified enemy.
reset()
e={enemy("wall",3,{fortified=true}),enemy("target",4)}
targets["a#explosiveAttack"]="target"
apply(e,{group(1),group(2)},{assigned(a)},{a})
eq(effect(e[2],"a").earned,0,"Fortification stops Ranged defeat credit")
local siege=bolt("siege",0,{siege=3,resources={siege=3}})
reset()
targets["siege#explosiveAttack"]="target"
apply(e,{group(1),group(2)},{assigned(siege)},{siege})
eq(effect(e[2],"siege").earned,1,"Legal Siege against single fortification earns credit")
eq(e[2].baseArmour,3,"Siege-earned follow-up applied")
reset()
e={enemy("first",3),enemy("target",4)}
apply(e,{group(1),group(2)},{assigned(a)},{})
eq(e[2].baseArmour,4,"No active Explosive Bolt leaves entries unchanged")
eq(#calls,0,"No active bolt performs no targeting work")
print("Explosive Bolt earned reductions, immunity and fixed-point timing passed")
