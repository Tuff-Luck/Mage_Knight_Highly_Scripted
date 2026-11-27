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

-- A repeated Block card keeps its equal printed effects, with all one-effect
-- bonuses on its first Block rather than losing an indivisible remainder.
local shield={resources={block=8},repeatBlocks=2}
local shieldTotals={block=8}
ops.addSingleBlockBonus(shield,shieldTotals,"block",1)
ops.addSingleBlockBonus(shield,shieldTotals,"block",2)
eq(shield.resources.block,11,"Two single-Block modifiers are additive")
eq(shield.ambushFirstBlockBonus,3,"First printed Block owns both bonuses")
eq(shieldTotals.block,11,"Block totals match split resources")
eq(ops.uniqueField({ranged=3,rangedFire=2,attack=4},{ranged=true,attack=true}),nil,
    "Mixed elemental attacks cannot pick an arbitrary single source")
eq(ops.uniqueField({attackFire=3,move=2},{attack=true}),"attackFire",
    "One eligible elemental Attack")
eq(ops.uniqueField({attackFoo=2},{attack=true}),nil,"Only exact resource families")
local linked={resources={ranged=3}}
ops.linkAttackBonus(linked,"ranged",{early={ranged=2,siege=1},late=3,physicalOnly=true})
ops.linkAttackBonus(linked,"ranged",{early={ranged=1,siege=1},late=2})
local function effective(record,transform)
    local resources={}
    for key,value in pairs(record.resources) do
        local field=ops.globalAttackKey(key,transform)
        resources[field]=(resources[field] or 0)+value
    end
    return {resources=resources,phaseAttackBoosts=ops.effectivePhaseAttackBoosts(record,transform)}
end
local source=effective(linked)
eq(ops.phaseAttackBonus(source,"ranged","range"),3,"Two linked ranged modifiers")
eq(ops.phaseAttackBonus(source,"ranged","attack"),5,"Same modifiers use melee values later")
eq(ops.phaseAttackBonus(source,"ranged","range","siege"),2,"Bow conversion uses Siege bonus")
source=effective(linked,{siege=true})
eq(ops.phaseAttackBonus(source,"siege","range"),2,"Global Siege conversion")
eq(ops.phaseAttackBonus(source,"siege","attack"),5,"Unused Siege gets melee bonus")
source=effective(linked,{coldFire=true})
eq(ops.phaseAttackBonus(source,"rangedColdFire","range"),1,"Elemental conversion loses only toxin")
local linkedTotals={ranged=3}
ops.replace(linked,linkedTotals,"ranged","rangedFire")
source=effective(linked)
eq(ops.phaseAttackBonus(source,"rangedFire","attack"),2,"Linked modifiers follow local conversion")
source.resources.rangedFire=0
eq(ops.phaseAttackBonus(source,"rangedFire","attack"),0,"Ineligible base cannot create standalone bonus")
print("Linked phase bonuses and repeated Block regressions passed")

local preview=ops.previewAttackBonuses({linked=linked},{siege=true,coldFire=true})
eq(preview.siegeColdFire,1,"Tracker uses effective early phase, without Toxin")
eq(ops.previewAttackBonuses({linked=linked},{}).rangedFire,1,"Tracker reflects local converted field")
eq(linked.resources.rangedFire,3,"Preview never mutates the combat base")
eq(ops.fixedShapeshiftAmount({resources={blockIce=8},variableEnemyBlockBonus=3},"blockIce"),5,
    "Cold Toughness transfers only printed Ice Block 5")
eq(ops.fixedShapeshiftAmount({resources={blockFire=4}},"blockFire"),4,
    "Terrain-derived One with the Land retains its fixed current value")
-- Actual calculator must consume linked bonuses before resistance or Sword.
local cfg={resourceOperations=ops,attackTypes={
    {key="P",attack="attack",ranged="ranged",siege="siege"},
    {key="F",attack="attackFire",ranged="rangedFire",siege="siegeFire"}
},artifactCombat={},bowSourceModes={}}
local total=dofile("src/PlayingGame/PlayerBoard/ResourceTracker/Combat/EnemyProperties.lua").defences(cfg).attackTotal
local physical={key="a",resources={ranged=3}}
ops.linkAttackBonus(physical,"ranged",{early={ranged=2,siege=1},late=3,physicalOnly=true})
ops.linkAttackBonus(physical,"ranged",{early={ranged=1,siege=1},late=2})
local group={{sources={physical},category="ranged"}}
eq(total(group,{},{},"range"),6,"Actual ranged result includes both linked boosts")
eq(total(group,{},{},"attack"),8,"Actual melee fallback uses later values")
eq(total(group,{pResist=true},{},"attack"),4,"Resistance applies to entire modified Attack")
cfg.artifactCombat.sword=true
eq(total(group,{},{},"attack"),16,"Sword applies to complete linked physical value")
cfg.artifactCombat.sword=false
cfg.artifactCombat.bow=true
eq(total(group,{},{},"range"),12,"Bow doubles complete Ranged source")
cfg.bowSourceModes["a#ranged"]="siege"
eq(total(group,{},{},"range"),0,"Converted Ranged no longer spent in Ranged category")
eq(total({{sources={physical},category="siege"}},{},{},"range"),5,
    "Bow Siege choice uses Siege-specific linked values")
print("Production Attack totals and tracker preview regressions passed")
