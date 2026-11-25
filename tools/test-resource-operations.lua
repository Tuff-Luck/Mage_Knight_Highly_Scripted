-- Run from repository root: lua5.2 tools/test-resource-operations.lua
package.path="src/?.lua;"..package.path
local ops=require("PlayingGame.PlayerBoard.ResourceTracker.Core.ResourceOperations")
local function eq(actual,expected,label)
    assert(actual==expected,label..": expected "..tostring(expected)..", got "..tostring(actual))
end

for _,family in ipairs({"attack","ranged","siege","block"}) do
    for _,suffix in ipairs({"","Fire","Ice","ColdFire","Psychic"}) do
        local key=family..suffix
        local f,s=ops.splitKey(key)
        eq(f,family,"family")
        eq(s,suffix,"element")
        eq(ops.changeFamily(key,"attack"),"attack"..suffix,"preserve element")
        eq(ops.changeFamily(key,"move"),"move","Move has no element")
        local expectedFire=({[""]=family.."Fire",Ice=family.."ColdFire"})[suffix]
        local expectedIce=({[""]=family.."Ice",Fire=family.."ColdFire"})[suffix]
        eq(ops.addElement(key,"Fire"),expectedFire,"Fire gem")
        eq(ops.addElement(key,"Ice"),expectedIce,"Ice gem")
        local transformed=family=="block" and key or "siegeColdFire"
        eq(ops.globalAttackKey(key,{siege=true,coldFire=true}),transformed,"global transform")
        eq(ops.globalAttackKey(key,{}),key,"no transform")
    end
end
eq(ops.changeFamily("move","block"),"block","Move to Block")
eq(ops.addElement("move","Fire"),nil,"Move cannot gain Fire")
eq(ops.globalAttackKey("healing",{siege=true}),"healing","Heal is not Attack")
local printed={attackFire=4,rangedFire=1,move=2}
local record={resources=printed,links={"source"},contributes=true}
local totals={attackFire=7,rangedFire=3,move=2}
ops.replace(record,totals,"attackFire","rangedFire")
eq(record.resources.attackFire,nil,"remove original")
eq(record.resources.rangedFire,5,"merge with existing destination")
eq(totals.attackFire,3,"subtract only the source")
eq(totals.rangedFire,7,"add converted amount")
eq(printed.attackFire,4,"printed table unchanged")
eq(printed.rangedFire,1,"printed destination unchanged")
eq(record.resources.move,2,"unrelated resource retained")
eq(record.links[1],"source","links untouched")
eq(record.contributes,true,"contribution state untouched")
ops.add(record,totals,"rangedFire",1)
eq(record.resources.rangedFire,6,"add boost")
eq(totals.rangedFire,8,"boost totals")
ops.replace(record,totals,"rangedFire","attackFire",8)
eq(record.resources.attackFire,8,"Leadership conversion with bonus")
eq(totals.attackFire,11,"existing attack plus converted amount")
eq(totals.rangedFire,2,"unrelated ranged amount retained")
ops.replace(record,totals,"attackFire","attackFire",9)
eq(totals.attackFire,12,"same-field replacement applies delta")
-- Recreate a new scan from the catalog, as the production coordinator does.
local second={resources=printed}
local secondTotals={attackFire=4,rangedFire=1,move=2}
ops.replace(second,secondTotals,"attackFire","rangedFire")
eq(second.resources.rangedFire,5,"new scan does not accumulate")
local batch={resources=printed}
local batchTotals={attackFire=4,rangedFire=1,move=2}
ops.addAmounts(batch,batchTotals,{attackFire=2,rangedFire=2})
eq(batch.resources.attackFire,6,"Batch Attack bonus")
eq(batch.resources.rangedFire,3,"Batch Ranged bonus")
eq(batchTotals.attackFire,6,"Batch Attack totals")
eq(batchTotals.rangedFire,3,"Batch Ranged totals")
eq(printed.attackFire,4,"Batch does not mutate catalog")
print("Resource category and live resource operations passed")
