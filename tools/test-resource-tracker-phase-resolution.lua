-- Integration of the extracted phase helpers with deterministic combat inputs.
local root="src/PlayingGame/PlayerBoard/ResourceTracker/"
local function eq(a,b,label) assert(a==b,label..": expected "..tostring(b)..", got "..tostring(a)) end
local function copy(value)
    if type(value)~="table" then return value end
    local result={}
    for k,v in pairs(value) do result[k]=copy(v) end
    return result
end
local groupsEngine=dofile(root.."Combat/EnemyGroups.lua")
local function groupEntry(members,blocked)
    local armour=0
    for _,member in ipairs(members) do armour=armour+member.baseArmour end
    return {data={},perks={},baseArmour=armour},armour
end
local function rangeGroup(members)
    local armour=0
    for _,member in ipairs(members) do armour=armour+(member.rangeBaseArmour or member.baseArmour) end
    return {baseArmour=armour}
end
local function range(entry,sources)
    local total=0
    for _,source in ipairs(sources) do total=total+(source.ranged or 0) end
    return total,entry.baseArmour,total>=entry.baseArmour,0
end
local function block(entry)
    return {},0,1,entry.blocked,{},false,entry.unblocked or {},nil,nil,
        entry.bash or {},entry.spent or {},entry.moves or {}
end
local function attacks(entry) return entry.attacks or {} end
local function trait(data,perks,key) return data[key]==true end
local function boss() return nil end
local early=dofile(root.."Combat/EarlyCombatPhase.lua")(block,groupEntry,range,rangeGroup,boss,attacks,trait,copy)
local prep=dofile(root.."Combat/DamageCalculation.lua").preparation(function() return {damageMitigation={physical=2,nonphysical=1}} end)
local late=dofile(root.."Combat/LateCombatPhase.lua")(groupEntry,trait,function() return 0 end,
    function(result) return result and result.heroWounds or 0 end,
    function(latest,committed,seen)
        local result={}
        for _,effect in ipairs(latest and latest.applied or {}) do
            if not seen[effect.source] then result[#result+1]=effect end
        end
        return result
    end,copy,
    function(sources,wounded,paralysis)
        local out={}
        for _,source in ipairs(sources) do
            if not wounded[source.guid] and not paralysis[source.guid] then out[#out+1]=source end
        end
        return out
    end,
    function(pools)
        local n=0
        for _,pool in ipairs(pools) do
            for _,source in ipairs(pool.sources) do n=n+(source.resources[pool.category] or 0) end
        end
        return n
    end,boss)
local function enemy(guid,armour,fields)
    local e={guid=guid,data={},baseArmour=armour,elusiveArmour=armour}
    for k,v in pairs(fields or {}) do e[k]=v end
    return e
end
local function source(guid,attack,ranged)
    return {guid=guid,key=guid,attack=attack,ranged=ranged,siege=0,resources={attack=attack,ranged=ranged}}
end
local a,b,c=source("ranged",0,3),source("blocker",2,0),source("melee",4,0)
local entries={enemy("rangedEnemy",3,{blocked=true,attacks={{value=2}}}),
    enemy("diseaseEnemy",6,{blocked=true,attacks={{value=3}},effect={armourSetIfBlocked=3},spent={blocker=true}}),
    enemy("bashEnemy",5,{blocked=true,attacks={{value=3}},bash={bashEnemy=2}}),
    enemy("vampire",4,{data={vampiric=true},unblocked={[2]={attack={owner="vampire",slot=2,key="P"},damage=3}}})}
local groups,of=groupsEngine.build(entries,{})
local allocated={{sources={a}},{sources={b}},{sources={c}}}
local row=early.resolve(entries,groups,allocated,{sources={},details={}},nil)
eq(groups[1].rangeDefeated,true,"Ranged defeat resolved first")
eq(entries[2].baseArmour,3,"Disease sets later Armour")
eq(entries[2].rangeBaseArmour,6,"Disease preserves ranged Armour")
eq(entries[3].baseArmour,3,"Shield Bash reduces own target")
eq(entries[3].rangeBaseArmour,5,"Shield Bash preserves ranged Armour")
eq(early.countBlockedEnemies(entries,groups,row),2,"Only surviving fully blocked enemies count")
local preview={sources={a,b,c}}
early.snapshot(entries,groups,of,row,nil,preview)
eq(preview.spentRange.ranged,true,"Ranged spend captured")
eq(preview.sourceKeys.blocker,true,"Successful Block captured")
eq(preview.sourceKeys.melee,nil,"Unspent Attack not committed")
entries[2].baseArmour=99
groups[1].rangeDefeated=false
row=early.snapshot(entries,groups,of,row,preview,nil)
eq(entries[2].baseArmour,3,"Frozen earlier Armour restored")
eq(groups[1].rangeDefeated,true,"Frozen ranged result restored")
local units={wounded={wounded=false},ready={wounded=false}}
local spec,items=prep.build(entries,groups,row,units,{wounded=true})
eq(spec.units.wounded,nil,"Self-wounded Unit cannot absorb damage")
eq(spec.units.ready,true,"Ready Unit eligible")
eq(#items,1,"Only surviving unblocked attack included")
eq(items[1].key,"vampire:2","Sparse attack slot retained")
eq(row[4].damageItems[2],items[1],"Row links exact damage item")
local scan={cards={["0688d8"]={enemyGUID="vampire"},["ae8673"]={enemyGUID="vampire"}}}
local mitigation,element=prep.mitigationFor(scan,items,{battleHardenedAttackKey="blocked:1",elementalResistanceAttackKey="vampire:2"})
eq(mitigation.attackKey,nil,"Blocked attack cannot consume mitigation")
eq(element.attackKey,"vampire:2","Valid selected attack retained")
late.vampiric(entries,groups,row,items,{["vampire:2"]={heroWounds=2}})
eq(entries[4].baseArmour,6,"Vampiric gains late Armour")
eq(groups[4].attackArmour,6,"Group late Armour recomputed")
local effectScan={enemyEffects={vampire={applied={{source="old",effective={armourReduce=3}},
    {source="new",effective={armourReduce=2}}}}}}
late.lateEffects(entries,groups,row,{sources={{guid="old"}}},effectScan,true)
eq(entries[4].baseArmour,4,"Only new late effect reduces Armour")
eq(entries[4].effect.applied[1].phaseAfterDamage,true,"Late effect tagged")
eq(groups[4].attackArmour,4,"Late group Armour recomputed")
local dodge=source("dodge",2,0)
dodge.dodgeConditional=true
late.dodgeAfterDamage({dodge},{a={heroWounds=1}})
eq(dodge.attack,0,"Hero wound removes Dodge Attack")
eq(dodge.resources.attack,0,"Resource removed as well")
local fame,rep=late.resolve(entries,groups,row,{melee=true},{},nil)
eq(groups[3].attackTotal,0,"Wounded source excluded from melee")
eq(groups[3].defeated,false,"Wounded source cannot defeat enemy")
eq(groups[1].defeated,true,"Earlier ranged defeat remains valid")
eq(late.defeatedCount(entries,groups[1],true),1,"Ranged kill counted once")
eq(fame,0,"No reward source grants no extra Fame")
eq(rep,0,"No reward source grants no extra Reputation")
print("Early, Damage and late Attack phase resolution passed")
