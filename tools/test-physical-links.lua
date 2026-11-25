-- Run from repository root: lua5.2 tools/test-physical-links.lua
package.path="src/?.lua;"..package.path
local links=require("PlayingGame.PlayerBoard.ResourceTracker.Core.PhysicalLinks")
local a,b,c={overlap=2},{overlap=2},{overlap=3}
assert(links.unique({})==nil)
assert(links.unique({a})==a)
assert(links.unique({a,b})==nil)
assert(links.unique({b,a})==nil)
assert(links.unique({a,b,c})==c)
assert(links.unique({c,b,a})==c)
local remote={overlap=0}
assert(links.unique({remote})==nil)
assert(links.unique({remote},true)==remote)
assert(links.unique({remote,{overlap=0}},true)==nil)
assert(links.unique({remote,a},true)==a)
local first={overlap=2,priority=1,tieKey="a"}
local second={overlap=2,priority=1,tieKey="b"}
local larger={overlap=5,priority=0,tieKey="c"}
assert(links.unique({first,second,larger})==nil)
assert(links.unique({larger,first})==first)
assert(links.ordered({second,larger,first})==first)
assert(links.ordered({first,second,larger})==first)

-- Exercise actual Faction Reward scan with tied eligible cards.
local env=setmetatable({gameCards={a={cardType="Starting"},b={cardType="Advanced Action"}}},{__index=_G})
local rewards=assert(loadfile("src/PlayingGame/PlayerBoard/ResourceTracker/Scanning/FactionRewardScan.lua","t",env))()
local function scan(areas)
    local records={
        a={resources={attack=3},contributes=true,links={},status="green"},
        b={resources={attack=4},contributes=true,links={},status="green"},
        reward={kind="factionReward",modifier="addFire",links={},status="yellow"}
    }
    local totals={attack=7}
    rewards.modifiers({records=records,objects={a={guid="a"},b={guid="b"},reward={guid="reward"}},
        footprint=function(obj) return obj end,
        overlapArea=function(_,obj) return areas[obj.guid] end,
        cardPosture=function() return "upright" end,
        attackTransforms={},totals=totals,setHighlight=function() end})
    return records,totals
end
local records,totals=scan({a=5,b=5})
assert(records.reward.status=="yellow" and #records.reward.links==0)
assert(totals.attack==7 and totals.attackFire==nil)
records,totals=scan({a=4,b=5})
assert(records.reward.links[1]=="b" and records.b.resources.attackFire==4)
assert(totals.attack==3 and totals.attackFire==4)
-- Vial of Toxin links to a Unit without stealing the activation outline.
local unit={guid="unit"}
env.gameCards.unit={cardType="Regular Unit"}
local records={
    unit={kind="unit",resources={attack=3},contributes=true,links={},status="green"},
    reward={kind="factionReward",modifier="physicalBoost",links={},status="yellow"}
}
local totals={attack=3}
local highlighted={}
rewards.modifiers({records=records,objects={unit=unit,reward={guid="reward"}},
    footprint=function(obj) return obj end,overlapArea=function() return 5 end,
    cardPosture=function() return "upright" end,attackTransforms={},totals=totals,
    addResourceAmounts=function(record,target)
        for field,amount in pairs(record.resources) do target[field]=(target[field] or 0)+amount end
    end,
    setHighlight=function(obj,status) highlighted[obj.guid]=status end})
assert(records.unit.status=="green" and records.unit.links[1]=="reward")
assert(records.reward.status=="purple" and highlighted.reward=="purple")
assert(highlighted.unit==nil and totals.attack==6)
print("Physical link ambiguity and Faction Reward scan passed")
