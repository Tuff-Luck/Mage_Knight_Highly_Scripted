-- Run from repository root: lua5.2 tools/test-enemy-effect-records.lua
package.path="src/?.lua;"..package.path
local effects=require("PlayingGame.PlayerBoard.ResourceTracker.Combat.EnemyEffectRecords")
local r={links={},status="yellow",complete=false}
effects.register(r,"card#effect1")
effects.register(r,"card#effect2")
effects.register(r,"card#effect1")
assert(#r.enemyEffectTargetKeys==2 and r.enemyEffectTargetGUIDs==nil)
assert(r.status=="yellow" and not r.complete)
effects.link(r,"card#effect1","enemy",{primary="first",purple=true})
effects.link(r,"card#effect2","enemy",{primary="first",purple=true})
assert(#r.links==2 and r.enemyEffectTargetGUIDs["card#effect1"]=="enemy"
    and r.enemyEffectTargetGUIDs["card#effect2"]=="enemy")
assert(r.enemyGUID=="enemy" and r.status=="purple" and not r.complete)
effects.link(r,"card#rep3","other",{primary="first",purple=true})
assert(r.enemyGUID=="enemy" and r.enemyEffectTargetGUIDs["card#rep3"]=="other")
local unit={links={},status="green",complete=true}
effects.register(unit,"unit#effect2")
effects.link(unit,"unit#effect2","enemy",{})
assert(unit.status=="green" and unit.enemyGUID==nil and unit.complete)
effects.target(unit,"unit#manual","other")
assert(#unit.links==1 and unit.enemyEffectTargetGUIDs["unit#manual"]=="other")
local global={links={},status="blue"}
effects.link(global,nil,"enemy",{purple=true})
assert(global.enemyEffectTargetGUIDs==nil and global.enemyEffectTargetKeys==nil)
local skill={links={},status="yellow",complete=false}
effects.register(skill,"skill")
effects.link(skill,"skill","enemy",{primary="replace",purple=true,complete=true})
assert(skill.complete and skill.enemyGUID=="enemy" and skill.status=="purple")

-- Exercise actual Faction Reward scan with and without a legal target.
local token={guid="reward"}
local target=nil
local applied=0
local spec={attackReduce=2}
local env=setmetatable({gStates={manaSource={}},combatEffectAdd=function(_,guid,source,effect)
    assert(guid=="enemy" and source=="reward" and effect==spec)
    applied=applied+1
end},{__index=_G})
local scan=assert(loadfile("src/PlayingGame/PlayerBoard/ResourceTracker/Scanning/FactionRewardScan.lua","t",env))()
local function read()
    local records={}
    scan.read({objects={reward=token},placements={reward="play"},
        resourceObjectKind=function() return "factionReward" end,
        factionRewardForObject=function() return {name="test",enemyEffect=spec,partial=true} end,
        effectHasTrackedResource=function() return false end,
        combatEffectChosenEnemy=function() return target end,footprint=function() return {} end,
        combatEffectTargetEligible=function() return nil end,
        monsters={},enemyEffects={},showChoiceButtons=function() end,
        addResourceAmounts=function() end,totals={},records=records,current={},
        setHighlight=function() end})
    return records.reward
end
local pending=read()
assert(pending.enemyEffectTargetKeys[1]=="reward" and #pending.links==0 and applied==0)
target={guid="enemy"}
local resolved=read()
assert(resolved.enemyEffectTargetGUIDs.reward=="enemy" and resolved.status=="purple" and applied==1)
print("Enemy effect record regression passed")
