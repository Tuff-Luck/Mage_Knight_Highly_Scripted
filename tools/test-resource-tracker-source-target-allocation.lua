-- Production source allocation with deterministic arrow and enemy callbacks.
local root="src/PlayingGame/PlayerBoard/ResourceTracker/"
local arrows,clears,ensures,kept,records={},{},{},{},{}
local nearestCalls,scanCalls=0,0
local cumbersomeCalls,attackCalls={},{}
local function cumbersome(guid)
    cumbersomeCalls[guid]=(cumbersomeCalls[guid] or 0)+1
    return guid=="c"
end
local function attacks(entry)
    attackCalls[entry.guid]=(attackCalls[entry.guid] or 0)+1
    return entry.attacks or {}
end
local split=dofile(root.."Combat/DivisibleResources.lua")(function() return {} end,cumbersome,attacks)
local engine=dofile(root.."Combat/SourceTargetAllocation.lua")(
    function(key) return arrows[key] or {} end,
    function(key) clears[#clears+1]=key arrows[key]=nil end,
    function(key,guid) return guid~="bad" end,cumbersome,
    function(source,entries,eligible)
        nearestCalls=nearestCalls+1
        for _,entry in ipairs(entries) do
            if not entry.attackOnly and entry.guid~=source.possessExclude
                and (not eligible or eligible(entry.guid)) then return entry.guid end
        end
    end,
    function(key) return arrows[key]~=nil end,
    function(key,guid,kind) ensures[#ensures+1]={key,guid,kind} arrows[key]={[guid]=true} end,
    function() return "attack" end,attacks,split,
    function() scanCalls=scanCalls+1 return {cards=records} end,function(key) return kept[key]==true end)
local function eq(actual,expected,label)
    assert(actual==expected,label..": expected "..tostring(expected)..", got "..tostring(actual))
end
local entries={{guid="normal",attacks={{key="P"}}},{guid="c",attacks={{key="P"}}},
    {guid="psychic",attacks={{key="M"}}},{guid="bad",attacks={{pending=true}}},
    {guid="reminder",attackOnly=true,attacks={{key="P"}}}}
local rows={normal=1,c=2,psychic=3,bad=4,reminder=5}
local function source(key,values)
    local item={guid=key,key=key,name=key,ranged=0,siege=0,attack=0,block=0,move=0,
        psychicInfluence=0,resources={},details={}}
    for k,v in pairs(values or {}) do item[k]=v end
    return item
end
local state={targets={manual="c",possess="normal",fork="bad",badAttack="reminder",
    influence="psychic",stale="normal",effect="normal",locked="c",duel="bad"},
    explicit={manual=true,possess=true,fork=true,badAttack=true,influence=true,stale=true,
        effect=true,locked=true,duel=true}}
arrows={manual={normal=true},saved={c=true}}
kept.locked=true
records.one={enemyEffectTargetKeys={"effect"}}
local sources={source("manual",{attack=2}),source("saved",{attack=2}),
    source("possess",{attack=2,possessExclude="normal"}),source("fork",{attack=1,forkedLightning=true}),
    source("badAttack",{attack=2}),source("move",{move=3}),source("influence",{psychicInfluence=3}),
    source("unassignedInfluence",{psychicInfluence=2}),source("duel",{attack=2,dueling=true})}
local violations={}
local assigned=engine.allocate(entries,sources,rows,state,true,function(...)
    violations[#violations+1]={...}
end)
eq(#violations,0,"Valid allocations conserve each source family")
eq(state.targets.manual,"c","Manual target wins against stale arrow")
eq(state.targets.saved,"c","Saved arrow restored")
eq(state.explicit.saved,true,"Saved target is explicit")
eq(state.targets.possess,"c","Possessed enemy cannot target itself")
eq(state.targets.fork,"normal","Rejected Forked Lightning target is replaced")
eq(state.targets.badAttack,"normal","Attack-only reminder rejected for Attack")
eq(state.targets.move,"c","Combat Move finds Cumbersome enemy")
eq(state.explicit.move,true,"Automatic Move reserves pool")
eq(sources[6].moveCounts,true,"Combat Move eligibility set")
eq(sources[7].psychicInfluenceCounts,true,"Explicit Psychic Influence counts")
eq(state.targets.unassignedInfluence,nil,"Influence never auto-targets")
eq(sources[9].duelingEligible,false,"Pending-only attacks cannot trigger Dueling")
eq(state.targets.stale,nil,"Inactive source lock pruned")
eq(state.explicit.stale,nil,"Inactive explicit flag pruned")
eq(state.targets.effect,"normal","Effect-only source lock preserved")
eq(state.targets.locked,"c","Committed source lock preserved")
eq(#clears,3,"Only invalid targets clear physical arrows")
eq(#assigned[2].sources,4,"Target allocation retains all four Cumbersome sources")
eq(assigned[3].sources[1],sources[7],"Psychic source remains assigned")
eq(assigned[5],nil,"No offensive allocation to attack-only reminder")
local other={targets={},explicit={}}
local beforeScanCalls=scanCalls
engine.allocate(entries,{source("fresh",{attack=1})},rows,other,false)
eq(scanCalls,beforeScanCalls,"Numeric-only targets skip effect-index scan")
local profiler={}
dofile(root.."Core/Diagnostics.lua")(profiler)
profiler.traceEnabled=true
local tick=0
profiler.profileClock=function() tick=tick+0.001 return tick end
local profileState={targets={},explicit={}}
engine.allocate(entries,{source("profiled",{block=1}),source("unassigned",{psychicInfluence=1})},
    rows,profileState,false,nil,profiler)
eq(profiler.profileStats["targets.resolve"].count,2,"Every source target resolution timed")
eq(profiler.profileStats["targets.arrows"].count,1,"Only assigned source arrow reconciliation timed")
eq(profiler.profileStats["targets.distribute"].count,1,"Only assigned source distribution timed")
eq(profiler.profileStats["allocation.targets"].count,1,"Parent allocation timer retained")
profiler.traceEnabled=false
profiler.profileClock=function() error("Disabled profiling sampled clock") end
engine.allocate(entries,{source("profiled",{block=1})},rows,profileState,false,nil,profiler)
eq(other.targets.fresh,"normal","New player's state receives target")
eq(state.targets.fresh,nil,"Previous player's state is not retained")
eq(state.targets.manual,"c","Previous player's manual lock unchanged")
-- Multiple sources aimed at one enemy reuse the same fresh observations.
local cacheState={targets={p1="psychic",p2="psychic",p3="psychic"},
    explicit={p1=true,p2=true,p3=true}}
local beforeAttacks=attackCalls.psychic or 0
local beforeCumbersome=cumbersomeCalls.psychic or 0
local psychicSources={source("p1",{psychicInfluence=2}),source("p2",{psychicInfluence=3}),
    source("p3",{dueling=true,attack=2})}
engine.allocate(entries,psychicSources,rows,cacheState,false)
eq(attackCalls.psychic-beforeAttacks,1,"One attack observation per enemy per allocation")
eq(cumbersomeCalls.psychic-beforeCumbersome,1,"One Cumbersome observation per enemy per allocation")
eq(psychicSources[1].psychicInfluenceCounts,true,"First Psychic source eligible")
eq(psychicSources[2].psychicInfluenceCounts,true,"Second Psychic source eligible")
entries[3].attacks={{key="P"}}
local changedSource=source("p1",{psychicInfluence=2})
engine.allocate(entries,{changedSource},rows,cacheState,false)
eq(changedSource.psychicInfluenceCounts,false,"Next allocation observes changed enemy attacks")
entries[3].attacks={{key="M"}}
-- A deliberately faulty allocator duplicates one source. Diagnostics must
-- report its over-allocation without changing the combat calculation.
local faulty=dofile(root.."Combat/SourceTargetAllocation.lua")(
    function() return {} end,function() end,function() return true end,cumbersome,
    function() return "normal" end,function() return false end,function() end,
    function() return "attack" end,attacks,
    function(source,target)
        target.sources[#target.sources+1]=source
        target.sources[#target.sources+1]=source
    end,function() return {cards={}} end,function() return false end)
local bad={}
local faultyResult=faulty.allocate(entries,{source("duplicate",{attack=3})},rows,
    {targets={},explicit={}},false,function(...) bad[#bad+1]={...} end)
eq(#bad,1,"Duplicate allocation produces one diagnostic")
eq(bad[1][1],"duplicate","Diagnostic identifies source")
eq(bad[1][2],"attack","Diagnostic identifies resource family")
eq(bad[1][3],3,"Original budget retained")
eq(bad[1][4],6,"Actual allocation reported")
eq(#faultyResult[1].sources,2,"Diagnostic does not mutate combat result")
-- Nearest-target position cache is scoped to a single allocation, including
-- absent objects. Other callers must still read current table positions.
local file=assert(io.open("src/PlayingGame/PlayerBoard/CardRecognition.lua","r"))
local code=file:read("*a") file:close()
local start=assert(code:find("local function combatNearestEnemyGUID(",1,true))
local finish=assert(code:find("combatConfig.attackTypes=",start,true))
local reads={}
local coordinates={source={0,0,0},a={1,0,0},b={2,0,0}}
local env={combatAssignmentState={targets={}},getObjectFromGUID=function(guid)
    if coordinates[guid]==nil then return nil end
    return {getPosition=function()
        reads[guid]=(reads[guid] or 0)+1
        return coordinates[guid]
    end}
end}
setmetatable(env,{__index=_G})
local nearest=assert(load(code:sub(start,finish-1).."\nreturn combatNearestEnemyGUID","Nearest target","t",env))()
local src={guid="source",key="source",attack=1,ranged=0,siege=0}
local enemies={{guid="a"},{guid="b"}}
local positions={}
eq(nearest(src,enemies,nil,positions),"a","Nearest target selected")
eq(nearest(src,enemies,nil,positions),"a","Repeat uses same position snapshot")
eq(reads.source,1,"Source position reused")
eq(reads.a,1,"First enemy position reused")
eq(reads.b,1,"Second enemy position reused")
coordinates.b={0.5,0,0}
eq(nearest(src,enemies,nil,{}),"b","Next allocation observes moved enemy")
eq(nearest(src,enemies),"b","Standalone caller observes live positions")
-- Removing Cumbersome must never clear a mixed source's Psychic/Block target.
local mixed=source("mixed",{move=2,psychicInfluence=3})
local mixedState={targets={mixed="psychic",moveOnly="c",blockMove="normal"},
    explicit={mixed=true,moveOnly=true,blockMove=true}}
local beforeClear=#clears
eq(engine.clearUnavailableMoveTarget(mixed,mixedState),false,"Mixed Psychic source retains target")
eq(mixedState.targets.mixed,"psychic","Psychic target retained")
eq(mixedState.explicit.mixed,true,"Psychic explicit state retained")
eq(engine.clearUnavailableMoveTarget(source("blockMove",{move=2,block=3}),mixedState),false,"Mixed Block target retained")
eq(mixedState.explicit.blockMove,true,"Block explicit state retained")
eq(engine.clearUnavailableMoveTarget(source("moveOnly",{move=2}),mixedState),true,"Pure Move target cleared")
eq(mixedState.targets.moveOnly,nil,"Pure Move target removed")
eq(mixedState.explicit.moveOnly,nil,"Pure Move explicit state removed")
eq(#clears,beforeClear+1,"Only pure Move arrows removed")

-- Immutable snapshot reuse must not change the prior preview or committed copy.
local snapStart=assert(code:find("local function combatFrozenCopy(",1,true))
local snapEnd=assert(code:find("-- A committed Damage phase",snapStart,true))
local freeze=assert(load(code:sub(snapStart,snapEnd-1).."\nreturn combatFrozenCopy"))()
local original={a={block=3},b={attack=2},old=true}
local frozen=freeze(original)
eq(freeze(original,frozen),frozen,"Identical snapshot reuses root")
original.a.block=4 original.old=nil
local changed=freeze(original,frozen)
eq(changed.a.block,4,"Changed value captured")
eq(frozen.a.block,3,"Previous snapshot remains immutable")
eq(changed.b,frozen.b,"Unchanged subtree reused")
eq(changed.old,nil,"Removed key not retained")
local committed=freeze(changed)
changed.a.block=9
eq(committed.a.block,4,"Commit makes independent deep copy")
print("Source target authority, eligibility, allocation and cleanup passed")
