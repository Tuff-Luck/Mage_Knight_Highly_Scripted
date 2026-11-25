-- Run from repository root: lua5.2 tools/test-highlight-policy.lua
package.path="src/?.lua;"..package.path
local policy=require("PlayingGame.PlayerBoard.ResourceTracker.Core.HighlightPolicy")
assert(policy.certainty(false,false)=="blue")
assert(policy.certainty(false,true)=="blue")
assert(policy.certainty(true,false)=="yellow")
assert(policy.certainty(true,true)=="green")
assert(policy.contribution(true)=="green")
assert(policy.contribution(false)=="blue")
local card={kind="card",status="green",powered=true}
assert(policy.linkedTarget(card) and card.status=="purple" and card.powered)
for _,status in ipairs({"green","blue","purple"}) do
    local unit={kind="unit",status=status,powered=false,activationIndex=2}
    assert(not policy.linkedTarget(unit) and unit.status==status and not unit.powered)
    assert(unit.activationIndex==2)
end
local unit={kind="unit",status="green"}
policy.linkedSource(unit)
assert(unit.status=="purple","A Unit deliberately used as an effect source may be purple")
local status,powered=policy.dynamicUnit(true,true)
assert(status=="green" and not powered)
status,powered=policy.dynamicUnit(true,false)
assert(status=="blue" and not powered)
status,powered=policy.dynamicUnit(false,true)
assert(status=="purple" and powered)
print("Shared highlight policy passed")
