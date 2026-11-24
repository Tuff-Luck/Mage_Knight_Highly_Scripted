-- Conditional Block effects: phase order, actual attack owner and counterattack gating.
local root="src/PlayingGame/PlayerBoard/"
dofile(root.."CombatEffects.lua")
local groupModule=dofile(root.."ResourceTracker/Combat/EnemyGroups.lua")
local calls,defends=0,0
local tokens={summon={},immune={arcaneImmunity=true},fire={fResist=true},perk={}}
local perks={perk={fResist=true}}
local function block(entry,sources)
    calls=calls+1
    return nil,nil,nil,entry.allBlocked,nil,nil,nil,entry.successful or {},entry.owners or {}
end
local engine=dofile(root.."ResourceTracker/Combat/ConditionalBlockEffects.lua")(
    function(entries) defends=defends+1 for _,entry in ipairs(entries) do entry.previewOnly=true end end,
    groupModule.collect,function(members) return members end,
    function(members) return 0,0,members[1].rangedKill==true end,
    function(entry) return entry.attacks or {} end,block,combatEffectDestroysFullyBlocked,
    function(data,extra,trait) return data[trait]==true or (extra~=nil and extra[trait]==true) end,
    function(guid) return tokens[guid] end,function(guid) return perks[guid] end)
local function eq(actual,expected,label)
    assert(actual==expected,label..": expected "..tostring(expected)..", got "..tostring(actual))
end
local function enemy(guid,spec,fields)
    local entry={guid=guid,data={},attacks={{value=3}},effect={applied={{source="shield",effective=spec}}}}
    for k,v in pairs(fields or {}) do entry[k]=v end
    return entry
end
local function run(entries)
    local groups=groupModule.build(entries,{})
    return engine.destroyAfterBlock(entries,groups,{})
end
local full={destroyIfFullyBlocked=true}
local one={destroyIfBlocked=true}
local entries={enemy("full",full,{allBlocked=true}),
    enemy("partial",full,{allBlocked=false}),
    enemy("ranged",full,{allBlocked=true,rangedKill=true}),
    enemy("pending",full,{allBlocked=true,attacks={{pending=true,value=3}}}),
    enemy("zero",full,{allBlocked=true,attacks={{value=0}}})}
local ranged,changed=run(entries)
eq(changed,true,"Full Block triggers destruction")
eq(entries[1].destroyed,true,"Delphana destroys completely Blocked enemy")
eq(entries[2].destroyed,nil,"Partial Block does not trigger Delphana")
eq(entries[3].destroyed,nil,"Ranged defeat does not trigger Block destruction")
eq(ranged[3],true,"Earlier ranged defeat preserved for later combat")
eq(entries[4].destroyed,nil,"Pending attack cannot trigger")
eq(entries[5].destroyed,nil,"Zero attack cannot trigger")
eq(entries[1].previewOnly,nil,"Defender preview cannot mutate real entries")
local function success(owner)
    return {successful={shield=true},owners={shield={[owner]=true}}}
end
entries={enemy("actual",one,success("actual")),
    enemy("summoner",one,success("summon")),
    enemy("immuneSummoner",one,success("immune")),
    enemy("fireSummoner",one,success("fire")),
    enemy("perkSummoner",one,success("perk")),
    enemy("wrongSource",one,{successful={other=true},owners={other={wrongSource=true}}}),
    enemy("missingSummoner",one,success("missing"))}
for _,entry in ipairs(entries) do
    entry.summoned={{guid="summon"},{guid="immune"},{guid="fire"},{guid="perk"},{guid="missing"}}
end
entries[2].data.arcaneImmunity=true
ranged,changed=run(entries)
eq(changed,true,"Actual blocked enemy destroyed")
eq(entries[1].destroyed,true,"One successful shield Block suffices")
eq(entries[2].destroyed,nil,"Summoner not destroyed")
eq(entries[2].summonedDestroyed.summon,true,"Actual nonimmune summon destroyed despite summoner immunity")
eq(entries[3].summonedDestroyed,nil,"Arcane immune summon protected")
eq(entries[4].summonedDestroyed,nil,"Fire resistant summon protected")
eq(entries[5].summonedDestroyed,nil,"Perk resistance protected")
eq(entries[6].destroyed,nil,"Another Block source does not trigger Shield")
eq(entries[7].summonedDestroyed,nil,"Unknown summoned token cannot be destroyed")
local oldDefends=defends
ranged,changed=run({enemy("ordinary",{}, {})})
eq(ranged,nil,"No conditional effect needs no ranged snapshot")
eq(changed,false,"No conditional effect destroys nothing")
eq(defends,oldDefends,"No conditional effect skips preview")
-- Burning Shield's Block and Attack may have different targets.
local fireBlock={guid="burn",conditionalFireAttack=4,block=4}
local otherBlock={guid="failed",conditionalFireAttack=4,block=4}
local counter={guid="burn",conditionalCounterattack=4,attack=0,resources={attackFire=0},
    details={{key="attackFire",text="old"}}}
local failed={guid="failed",conditionalCounterattack=4,attack=4,resources={attackFire=4},
    details={{key="attackFire",text="old"}}}
local targets={{sources={counter,failed},details={{source=counter,detail=counter.details[1]},
    {source=failed,detail=failed.details[1]}}},{sources={fireBlock,otherBlock},details={}}}
engine.burningShield({{guid="attackTarget"},{guid="blockTarget",successful={burn=true}}},
    targets,{sources={},details={}})
eq(counter.attack,4,"Successful Block elsewhere earns Fire Attack")
eq(counter.resources.attackFire,4,"Resource record updated")
eq(counter.details[1].text,"Fire Attack 4 (successful Block)","Counter tooltip updated")
eq(failed.attack,0,"Unsuccessful Block earns no Attack")
eq(failed.resources.attackFire,0,"Failed resource cleared")
eq(#failed.details,0,"Failed counter has no details")
eq(#targets[1].details,1,"Only successful counter remains displayed")
eq(targets[1].details[1].source,counter,"Other counter remains intact")
print("Conditional Block destruction and Burning Shield cross-target timing passed")
