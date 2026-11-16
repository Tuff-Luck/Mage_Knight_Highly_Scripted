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
    "local function showChoiceButtons(card,choices,powered,inventorySpec,inventorySets,resources,repeatLink)",
    "-- One selected icon in the Unit's lower-left artwork margin")

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
    rageCard={resourceKey="rage",cardType="Starting"}
}
local rules={
    swiftness={normal={move=2},powered={ranged=3}},
    rage={normalChoices={{attack=2},{block=2}},powered={attack=4}}
}
local chosen={}
local state={
    gameCards=gameCards,cardResourceDefinitions=rules,skillResourceDefinitions={},
    choiceButtonShown={},choiceExpandedByGUID={},skillTokens={},
    choiceLetters={ranged="R",attack="A",block="B"},
    gStates={},trackerPrivate={singleAutoEnemyGUID="643901"},
    combatConfig={sourceFields={{key="ranged"},{key="attack"},{key="block"}},
        cardInTransit=function() return false end,
        cardChoiceIds=function() return {} end,
        cardButtonIds={}},
    combatCalcOn=true,combatCumbersomeActive=false,combatPsychicActive=false,
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
    resourceObjectUiXmlTable=function(ui) return ui.getXmlTable() end,
    removeChoiceButtons=function(card)
        if card~=nil then card.UI.setXml("") end
    end,
    combatEffectSpec=function() return nil end
}
setmetatable(state,{__index=_G})
assert(load(uiCode,"Object UI writer","t",state))()
local render=assert(load(buttonCode.."\nreturn showChoiceButtons",
    "Fixed combat card controls","t",state))()

local swiftness=makeCard("acdcb2")
render(swiftness,nil,true,nil,nil,{ranged=3},nil)
assert(#displayed==1 and displayed[1].method=="clear",
    "One enemy: Swiftness must clear its empty object UI safely")
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

-- Rage's manually selected basic Attack/Block must remain an actual choice UI.
local rage=makeCard("rageCard")
render(rage,rules.rage.normalChoices,false,nil,nil,{attack=2},nil)
assert(displayed[#displayed].method=="table",
    "Rage's two normal options should still create object UI")
print("Fixed Swiftness target UI and Rage regression passed")
