-- Execute the production card control option builder without TTS XML.
package.path="src/?.lua;"..package.path
local combat,psychic,cumbersome=true,false,false
local moveRole="movement"
local hideTarget=false
local selected="move"
local function category(choice)
    return choice.key or next(choice)
end
local function choose(_,_,choices)
    for _,choice in ipairs(choices) do
        if category(choice)==selected then return choice,selected end
    end
    return choices[1],choices[1] and category(choices[1]) or nil
end
local config={sourceFields={{key="attack"},{key="block"},{key="ranged"}}}
config.repeatChoiceFor=choose
config.moveRoleAvailable=function() return combat or moveRole=="combat" end
local options=require("PlayingGame.PlayerBoard.ResourceTracker.Interface.CardControlOptions")({
    choiceLetters={move="M",influence="I",attack="A",block="B",healing="H",ready="R",
        other="?",guide="G",hardened="H",ranged="R"},
    combatConfig=config,
    combatContext=function() return combat,psychic,cumbersome end,
    cardPosture=function(card) return card.posture end,
    choiceHasTargetableCombatResource=function(key)
        return key=="attack" or key=="block" or key=="ranged"
    end,
    combatEffectSpec=function(rule) return rule and rule.enemyEffect end,
    resourceChoiceRank=function(key) return ({move=1,ranged=2,block=3,attack=4})[key] or 10 end,
    currentChoice=choose,inventorySetChoice=choose,choiceCategory=category,
    skillChoiceFamily=function(key) return key end,
    combatReductionChoiceIcon=function(rule,powered,choice,key) return choice.icon or key end,
    resourceCardsMoveRole=function() return moveRole end,
    resourceCardsHideAutomaticEnemyTarget=function(_,key)
        return hideTarget and key=="attack"
    end
})
local function eq(a,b,label)
    assert(a==b,label..": expected "..tostring(b)..", got "..tostring(a))
end
local card={guid="card",posture="upright"}
local function fallback(rule,choices,resources,repeatLink)
    return options.fallbackChoices(card,rule,choices,resources,repeatLink)
end
local function build(choices,rule,expanded,repeated,inventory,sets,powered,skill,data)
    return options.buildRows(card,data,rule,choices,powered,inventory,sets,repeated,
        card.posture,skill,expanded)
end
eq(fallback(nil,nil,{move=3})[1].move,3,"Fixed Move gets a choice")
eq(fallback(nil,nil,{attack=4,block=3})[1].block,3,"Fixed resource chooses priority")
eq(fallback({simultaneousReady=true},nil,{healing=2})[1].healing,2,"Heal plus Ready retains Heal")
eq(fallback({blockSourceBoost=true},nil,nil)[1].key,"guide","Spirit Guides target choice")
eq(fallback({damageMitigation=true},nil,nil)[1].key,"hardened","Battle Hardened choice")
eq(fallback(nil,nil,nil,{count=3})[1].key,"other","Manual repeated effect reminder")
local printed={{move=2},{attack=3},{attack=4}}
local rows,signature,assets=build(printed,nil,true)
eq(#rows[1].entries,3,"Duplicate printed categories collapsed; Move has two roles")
eq(rows[1].entries[1].category,"move","Choice order")
eq(rows[1].expanded,true,"Base row expands")
eq(rows[1].entries[1].targetResource,nil,"Ordinary Move has no enemy target")
cumbersome=true
moveRole="combat"
rows=build(printed,nil,false)
eq(rows[1].selected,"combatMovemove","Selected combat Move alias")
eq(rows[1].visible[1].targetResource,"move","Combat Move target")
eq(rows[1].visible[1].icon,"move","Combat Move icon")
eq(rows[1].visible[1].roleBadge,"C","Combat Move badge")
eq(#printed,3,"Printed choices remain unchanged")
cumbersome=false
moveRole="movement"
selected="influence"
psychic=true
rows=build({{influence=3}})
eq(rows[1].visible[1].stackedIcons[2],"influence","Psychic composite icon")
eq(rows[1].visible[1].targetResource,"influence","Psychic target")
selected="attack"
hideTarget=true
rows=build({{attack=4}})
eq(rows[1].visible[1].targetResource,nil,"Single enemy suppresses redundant attack target")
rows=build({{key="attack",attack=4,splitTargets={"attack","block"}}})
eq(rows[1].visible[1].targetResource,"attack","Split targets are not suppressed")
hideTarget=false
local _,visibleSignature=build({{attack=4}})
hideTarget=true
local _,hiddenSignature=build({{attack=4}})
assert(visibleSignature[1]~=hiddenSignature[1],
    "Target visibility must participate in the row signature")
hideTarget=false
local _,singleSignature=build({{attack=4}})
local _,multipleSignature=build({{attack=4},{block=2}})
assert(singleSignature[1]~=multipleSignature[1],
    "Collapsed option count affects button visibility and clickability")
local _,plainSignature=build({{key="attack",attack=4,icon="attack"}})
local _,overlaySignature=build({{key="attack",attack=4,icon="attack",iconOverlay="F"}})
assert(plainSignature[1]~=overlaySignature[1],
    "Changed icon overlay invalidates unchanged category")
local _,splitSignature=build({{key="attack",attack=4,splitTargets={"attack","block"}}})
assert(singleSignature[1]~=splitSignature[1],
    "Split target changes invalidate row signature")
rows=build({{attack=3}},nil,"rep2",{count=3,options={{{attack=1}},{{attack=2},{block=2}},{{attack=3}}}})
eq(#rows,3,"Repeated effect uses independent rows")
eq(rows[2].index,-2,"Second repetition index")
eq(rows[2].expanded,true,"Only selected repetition expands")
eq(rows[1].expanded,false,"Other repetition stays collapsed")
rows=build({{attack=3}},nil,"set2",nil,{choices={{attack=1},{block=1}}},2,true)
eq(#rows,3,"Powered inventory adds two set rows")
eq(rows[3].expanded,true,"Second inventory set expands")
eq(rows[2].expanded,false,"First inventory set stays collapsed")
-- A Boot of Charging role switch never turns Attack into an alternative.
selected="move"
moveRole="movement"
cumbersome=true
local boot={{key="move",move=2,attack=2,splitMoveAttack=true}}
rows=build(boot)
eq(rows[1].visible[1].targetPart,"attack","Normal Move keeps independent Attack")
moveRole="combat"
rows=build(boot)
eq(rows[1].visible[1].targetPart,"attack","Combat Move keeps independent Attack")
eq(rows[1].visible[1].extraTargetPart,"block","Combat Move uses split Block source")
cumbersome=false
rows=build(boot)
eq(rows[1].selected,"combatMovemove","Combat role remains available")
eq(rows[1].visible[1].extraTargetResource,nil,"Only Cumbersome enables enemy Move targeting")
eq(build({}),nil,"Empty choices require caller to hide controls")
print("Card control fallback, choice ordering, combat variants, repeated and inventory rows passed")
