package.path="src/?.lua;"..package.path
-- Regression: a fixed powered Attack with one automatic enemy target must
-- never submit an empty XML table to Tabletop Simulator. The original failure
-- was Swiftness + White mana when Orc War Beasts entered the combat zone.
-- Run from repository root: lua5.2 tools/test-fixed-combat-card-ui.lua
local function read(path)
    local f=assert(io.open(path,"r"))
    local contents=f:read("*a")
    f:close()
    return contents
end
local function extract(text,first,last)
    local a=assert(text:find(first,1,true),"Missing "..first)
    local b=assert(text:find(last,a+#first,true),"Missing "..last)
    return text:sub(a,b-1)
end

local reader=read("src/PlayingGame/PlayerBoard/CardRecognition.lua")
local assets=read("src/PlayingGame/UIAssets.lua")
local data=read("src/Data.lua")
assert(data:find('swiftness={normal={move=2},powered={ranged=3}}',1,true),
    "Swiftness's printed effects must remain unchanged")
local uiCode=extract(assets,"function resourceObjectUiSetTable(ui,xml,assets)",
    "-- Legacy shared artwork")
local buttonCode=extract(reader,
    'trackerPrivate.cardControlOptions=require("PlayingGame.PlayerBoard.ResourceTracker.Interface.CardControlOptions")',
    "-- One selected icon in the Unit's lower-left artwork margin")
local letterCode=extract(reader,"local choiceLetters=",
    "-- The choice UI and initial-guess tie-breaks")
local reductionCode=extract(reader,
    "local function combatReductionChoiceIcon(rule,powered,choice,category)",
    "-- Keep card-attached controls intact")
assert(data:find('swiftReflexes={normalChoices={{move=2},{ranged=1},{key="reduce",icon="other"}}',1,true),
    "Swift Reflexes must retain its enemy Attack-reduction choice")
assert(data:find('["e88483"]={choices={{key="split",icon="ranged",iconOverlay="I/F"',1,true),
    "Malek's split Fire/Ice Ranged choice must use an icon")

local singleEnemy=true
local displayed={}
local function makeCard(guid)
    local xml={}
    local ui={
        getXmlTable=function() return xml end,
        setXml=function(value)
            assert(value=="","Empty object UI must be cleared with setXml")
            xml={}
            displayed[#displayed+1]={guid=guid,method="clear",count=0}
        end,
        setXmlTable=function(value,images)
            assert(#value>0,"TTS rejects setXmlTable with an empty XML table")
            xml=value
            displayed[#displayed+1]={guid=guid,method="table",count=#value,xml=value}
        end
    }
    return {guid=guid,is_face_down=false,UI=ui,
        getGMNotes=function() return "" end}
end

local gameCards={
    acdcb2={resourceKey="swiftness",cardType="Starting"},
    rageCard={resourceKey="rage",cardType="Starting"},
    reflexCard={resourceKey="swiftReflexes",cardType="Advanced Action"}
}
local rules={
    swiftness={normal={move=2},powered={ranged=3}},
    rage={normalChoices={{attack=2},{block=2}},powered={attack=4}},
    swiftReflexes={normalChoices={{move=2},{ranged=1},{key="reduce",icon="other"}},
        enemyEffect={normal={choice="reduce",attackReduce=1},
            powered={choice="reduce",attackReduce=2}}}
}
local chosen={}
local state={
    gameCards=gameCards,cardResourceDefinitions=rules,
    skillResourceDefinitions={["e88483"]={choices={
        {key="split",icon="ranged",iconOverlay="I/F",iconOverlaySize=42,
            iconOverlayColor="#FFFFFF",rangedIce=1,rangedFire=1},{ranged=2}}}},
    choiceButtonShown={},choiceExpandedByGUID={},skillTokens={["e88483"]=true},
    choiceLetters={ranged="R",attack="A",block="B"},
    gStates={},trackerPrivate={singleAutoEnemyGUID="643901"},
    combatConfig={sourceFields={{key="ranged"},{key="attack"},{key="block"}},
        cardInTransit=function() return false end,
        cardButtonIds={}},
    combatCalcOn=true,combatCumbersomeActive=false,combatPsychicActive=false,
    resourceCardsMoveRole=function() return "movement" end,
    combatAssignmentState={targets={}},
    resourceCardsDetailsOpen=function() return true end,
    cardPosture=function() return "upright" end,
    factionRewardForObject=function() return nil end,
    choiceHasTargetableCombatResource=function(category)
        return category=="ranged" or category=="attack" or category=="block"
    end,
    resourceChoiceRank=function(category)
        return ({ranged=3,block=4,attack=5})[category] or 99
    end,
    choiceCategory=function(choice)
        if choice.key~=nil then return choice.key end
        for key in pairs(choice) do return key end
    end,
    currentChoice=function(guid,powered,choices)
        local category=chosen[guid]
        for _,choice in ipairs(choices) do
            local key=choice.key
            if key==nil then for field in pairs(choice) do key=field break end end
            if key==category then return choice,category end
        end
        local first=choices[1]
        local key=first.key
        if key==nil then for field in pairs(first) do key=field break end end
        return first,key
    end,
    combatReductionChoiceIcon=function(rule,powered,choice,category) return category end,
    resourceCardsHideAutomaticEnemyTarget=function() return singleEnemy end,
    resourceCardsChoiceAssetsFor=function() return nil,{} end,
    resourceCardsChoiceIcon=function(category) return {name="test_"..category} end,
    resourceChoiceColumn=function(category) return category end,
    skillChoiceFamily=function(category) return category end,
    skillChoicePositions=function(entries)
        local positions={}
        for i,entry in ipairs(entries) do
            positions[entry.category]={x=(i-1)*44,y=0}
        end
        return positions
    end,
    resourceObjectUiXmlTable=function(ui) return ui.getXmlTable() end,
    removeChoiceButtons=function(card)
        if card~=nil then card.UI.setXml("") end
    end,
    combatEffectSpec=function(rule,powered,category)
        local sides=rule~=nil and rule.enemyEffect or nil
        local effect=sides~=nil and sides[powered and "powered" or "normal"] or nil
        return effect~=nil and effect.choice==category and effect or nil
    end
}
setmetatable(state,{__index=_G})
-- The runtime detects missing options by their actual object XML IDs; an
-- intact signature alone cannot prove the buttons survived a TTS UI update.
state.combatConfig.cardChoiceIds=function(guid,xml)
    local result={}
    for _,node in ipairs(xml or {}) do
        local id=node.attributes and node.attributes.id or nil
        if node.tag=="Button" and type(id)=="string"
            and (id:find("^ResourceCardChoice_"..guid.."_")
                or id:find("^AttackAssignmentSource_"..guid.."_")) then
            result[#result+1]=id
        end
    end
    return result
end
state.combatConfig.cardChoicesPresent=function(card)
    local expected=state.combatConfig.cardButtonIds[card.guid]
    if expected==nil then return false end
    local found={}
    for _,node in ipairs(card.UI.getXmlTable()) do
        local id=node.attributes and node.attributes.id or nil
        if id~=nil then found[id]=true end
    end
    for _,id in ipairs(expected) do
        if not found[id] then return false end
    end
    return true
end
state.choiceLetters=assert(load(letterCode.."\nreturn choiceLetters",
    "Choice keys","t",state))()
state.combatReductionChoiceIcon=assert(load(reductionCode.."\nreturn combatReductionChoiceIcon",
    "Effect choice icons","t",state))()
assert(load(uiCode,"Object UI writer","t",state))()
local render=assert(load(buttonCode.."\nreturn showChoiceButtons",
    "Fixed combat card controls","t",state))()

local swiftness=makeCard("acdcb2")
render(swiftness,nil,true,nil,nil,{ranged=3},nil)
assert(#displayed==0,
    "One enemy: an already-empty object UI must not receive an unnecessary clear")
assert(state.choiceButtonShown.acdcb2~=nil,
    "Cleared object UI should still have an up-to-date signature")

-- A second enemy means manual target selection is useful again.
singleEnemy=false
state.trackerPrivate.singleAutoEnemyGUID=nil
render(swiftness,nil,true,nil,nil,{ranged=3},nil)
assert(displayed[#displayed].method=="table",
    "Two enemies: Swiftness must restore its target button")
local foundTarget=false
for _,element in ipairs(displayed[#displayed].xml) do
    if element.attributes.id=="AttackAssignmentSource_acdcb2_0_ranged" then
        foundTarget=true
    end
end
assert(foundTarget,"Swiftness's ranged target control was missing")

-- Removing the second enemy must clear the stale button without causing
-- an Object reference error on the now-empty XML.
singleEnemy=true
state.trackerPrivate.singleAutoEnemyGUID="643901"
render(swiftness,nil,true,nil,nil,{ranged=3},nil)
assert(displayed[#displayed].method=="clear",
    "Returning to one enemy must safely remove Swiftness's target UI")

-- The sole enemy can remain the same while a pending retarget or changed
-- eligibility requires manual targeting. Do not reuse the hidden signature.
local sameEnemy=state.trackerPrivate.singleAutoEnemyGUID
singleEnemy=false
render(swiftness,nil,true,nil,nil,{ranged=3},nil)
assert(state.trackerPrivate.singleAutoEnemyGUID==sameEnemy,
    "The sole enemy GUID did not change")
assert(displayed[#displayed].method=="table"
    and displayed[#displayed].xml[1].attributes.id=="AttackAssignmentSource_acdcb2_0_ranged",
    "Same-enemy eligibility change must restore manual targeting")
singleEnemy=true
render(swiftness,nil,true,nil,nil,{ranged=3},nil)
assert(displayed[#displayed].method=="clear",
    "Ending a same-enemy retarget must remove the redundant control")

-- Rage's manually selected basic Attack/Block must remain an actual choice UI.
local rage=makeCard("rageCard")
render(rage,rules.rage.normalChoices,false,nil,nil,{attack=2},nil)
assert(displayed[#displayed].method=="table",
    "Rage's two normal options should still create object UI")
-- Regression: a special choice must be eligible for rendering AND use the
-- correct icon, not silently disappear because the category was unregistered.
local function choiceButton(guid,key)
    local last=displayed[#displayed]
    for _,node in ipairs(last.xml or {}) do
        if node.attributes~=nil and node.attributes.id==
            "ResourceCardChoice_"..guid.."_"..key then return node end
    end
    return nil
end
local reflex=makeCard("reflexCard")
chosen.reflexCard="reduce"
render(reflex,rules.swiftReflexes.normalChoices,false,nil,nil,{},nil)
local reduceButton=choiceButton("reflexCard","reduce")
assert(reduceButton~=nil and reduceButton.children~=nil
    and reduceButton.children[1].attributes.image=="test_attackReduction",
    "Swift Reflexes must show its Attack-reduction option with the reduction icon")

-- Malek's separate Ice 1 + Fire 1 attacks stay one choice and are clearly
-- distinguished from the physical Ranged 2 alternative.
local splitSkill=makeCard("e88483")
chosen.e88483="split"
render(splitSkill,state.skillResourceDefinitions.e88483.choices,false,nil,nil,
    {rangedIce=1,rangedFire=1},nil)
local splitButton=choiceButton("e88483","split")
assert(splitButton~=nil and splitButton.children~=nil
    and splitButton.children[1].attributes.image=="test_ranged"
    and splitButton.children[2].attributes.text=="I/F",
    "Split Ranged Skill must show its Fire/Ice overlay on a Ranged icon")

-- Defensive variants are contextual choices, not perpetual alternatives.
-- Full-size stacks must behave like Tempered Steel (two 82x82 images).
local march=makeCard("march")
state.gameCards.march={resourceKey="march",cardType="Starting"}
state.cardResourceDefinitions.march={normalChoices={{move=2}}}
chosen.march="move"
local moveRole="combat"
state.resourceCardsMoveRole=function() return moveRole end
state.combatCalcOn=true
state.combatCumbersomeActive=false
state.combatPsychicActive=false
render(march,state.cardResourceDefinitions.march.normalChoices,false,nil,nil,{move=2},nil)
assert(choiceButton("march","combatMovemove")==nil,
    "No Cumbersome enemy: March must not show Combat Move")
state.combatCumbersomeActive=true
render(march,state.cardResourceDefinitions.march.normalChoices,false,nil,nil,{move=2},nil)
local combatMove=choiceButton("march","combatMovemove")
assert(combatMove~=nil and #combatMove.children==2
    and combatMove.children[1].attributes.image=="test_block"
    and combatMove.children[2].attributes.image=="test_move"
    and combatMove.children[1].attributes.width==82
    and combatMove.children[2].attributes.width==82,
    "Combat Move must layer full-size shield and Move icons like Tempered Steel")
state.combatCumbersomeActive=false
render(march,state.cardResourceDefinitions.march.normalChoices,false,nil,nil,{move=2},nil)
assert(choiceButton("march","combatMovemove")==nil,
    "Removing last Cumbersome enemy must hide combat Move even when it was selected")

local psychic=makeCard("psychic")
state.gameCards.psychic={resourceKey="psychic",cardType="Starting"}
state.cardResourceDefinitions.psychic={normalChoices={{influence=2},{attack=2}}}
chosen.psychic="influence"
render(psychic,state.cardResourceDefinitions.psychic.normalChoices,false,
    nil,nil,{influence=2},nil)
local plainInfluence=choiceButton("psychic","influence")
assert(plainInfluence~=nil and #plainInfluence.children==1
    and plainInfluence.children[1].attributes.image=="test_influence",
    "Without Psychic attacks, Influence must not display a Block overlay")
state.combatPsychicActive=true
render(psychic,state.cardResourceDefinitions.psychic.normalChoices,false,
    nil,nil,{influence=2},nil)
local psychicBlock=choiceButton("psychic","influence")
assert(psychicBlock~=nil and #psychicBlock.children==2
    and psychicBlock.children[1].attributes.image=="test_block"
    and psychicBlock.children[2].attributes.image=="test_influence"
    and psychicBlock.children[1].attributes.width==82
    and psychicBlock.children[2].attributes.width==82,
    "Psychic Block must layer two full-size icons")
state.combatPsychicActive=false
render(psychic,state.cardResourceDefinitions.psychic.normalChoices,false,
    nil,nil,{influence=2},nil)
plainInfluence=choiceButton("psychic","influence")
assert(plainInfluence~=nil and #plainInfluence.children==1
    and plainInfluence.children[1].attributes.image=="test_influence",
    "Removing last Psychic attack must restore plain Influence without stale shield")


-- A card that is merely moved should not have its whole UI torn down. Even
-- if target context changes but the resulting buttons are identical, avoid
-- TTS setXmlTable: it causes the visible off/on flash on drop.
local beforeMoveWrites=#displayed
render(rage,rules.rage.normalChoices,false,nil,nil,{attack=2},nil)
assert(#displayed==beforeMoveWrites,
    "Re-rendering an unchanged card must keep its option button intact")
state.trackerPrivate.singleAutoEnemyGUID="otherEnemy"
render(rage,rules.rage.normalChoices,false,nil,nil,{attack=2},nil)
assert(#displayed==beforeMoveWrites,
    "A changed signature with identical XML must not flash the buttons")

-- If another TTS object-UI owner truly clears the buttons after dropping,
-- an identical later scan must detect their absence and restore them.
rage.UI.setXml("")
local clearedWrites=#displayed
render(rage,rules.rage.normalChoices,false,nil,nil,{attack=2},nil)
assert(#displayed==clearedWrites+1
    and displayed[#displayed].method=="table",
    "Missing option UI must be restored even when the signature is unchanged")
local foundRestored=false
for _,node in ipairs(rage.UI.getXmlTable()) do
    if node.attributes~=nil and node.attributes.id=="ResourceCardChoice_rageCard_attack" then
        foundRestored=true
    end
end
assert(foundRestored,"Repair must restore the original selected Rage option")

-- Replacing UI caches and the assignment context must not leave the
-- extracted renderer writing to a stale table after a reset.
local oldShown=state.choiceButtonShown
state.choiceButtonShown={}
state.choiceExpandedByGUID={}
state.combatAssignmentState={targets={}}
render(rage,rules.rage.normalChoices,false,nil,nil,{attack=2},nil)
assert(state.choiceButtonShown.rageCard~=nil and state.choiceButtonShown~=oldShown,
    "Card renderer uses the replacement cache after reset")
print("Fixed combat/choice icon regressions passed")
