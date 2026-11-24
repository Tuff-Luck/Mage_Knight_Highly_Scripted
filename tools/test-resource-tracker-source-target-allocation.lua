-- Production source allocation with deterministic arrow and enemy callbacks.
local root="src/PlayingGame/PlayerBoard/ResourceTracker/"
local arrows,clears,ensures,kept,records={},{},{},{},{}
local nearestCalls=0
local function cumbersome(guid) return guid=="c" end
local function attacks(entry) return entry.attacks or {} end
local split=dofile(root.."DivisibleResources.lua")(function() return {} end,cumbersome,attacks)
local engine=dofile(root.."SourceTargetAllocation.lua")(
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
    function() return {cards=records} end,function(key) return kept[key]==true end)
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
local assigned=engine.allocate(entries,sources,rows,state,true)
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
engine.allocate(entries,{source("fresh",{attack=1})},rows,other,false)
eq(other.targets.fresh,"normal","New player's state receives target")
eq(state.targets.fresh,nil,"Previous player's state is not retained")
eq(state.targets.manual,"c","Previous player's manual lock unchanged")
print("Source target authority, eligibility, allocation and cleanup passed")
