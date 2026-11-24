package.path="src/?.lua;"..package.path
-- Repositioning powered Noble Manners must not lose its Interaction toggle.
-- Run from repository root: lua5.2 tools/test-noble-manners-ui.lua
local function read(path)
    local f=assert(io.open(path,"r"))
    local text=f:read("*a")
    f:close()
    return text
end
local source=read("src/PlayingGame/PlayerBoard/CardRecognition.lua")
local data=read("src/Data.lua")
assert(data:find('["eaaaa5"]={cardType="Starting", resourceKey="nobleManners"',1,true),
    "Noble Manners card mapping changed")
assert(data:find('nobleManners={normal={influence=2},powered={influence=4}',1,true),
    "Noble Manners powered resource changed")
local first=assert(source:find("combatConfig.cardInTransit=function(card)",1,true))
local last=assert(source:find("-- One selected icon in the Unit",first,true))
local uiSection=source:sub(first,last-1)
assert(source:find("if not combatConfig.cardInTransit(previousObject) then",1,true),
    "Temporary play-zone exits must preserve card-attached controls")
assert(read("src/PlayingGame/PlayerBoard/ResourceTracker/CardControls.lua"):find("and combatConfig.cardChoicesPresent(card) then return end",1,true),
    "All card controls must be checked before reusing a cached UI signature")
assert(source:find("queueSeat(seat,obj.guid)\n    end\nend\n\n-- Register the remaining readying",1,true),
    "Tracked cards dropped outside the thin zone must wait until settled")
local guid="eaaaa5"
local xmlWrites=0
local cardUI={xml={}}
local card={
    guid=guid,type="Card",is_face_down=false,held_by_color=nil,
    moving=false,resting=true,rotation={0,0,0},UI=cardUI,
    getGMNotes=function() return "" end
}
-- Tabletop Simulator object methods are called with dot syntax.
card.isSmoothMoving=function() return card.moving end
card.getRotation=function() return card.rotation end
local selection={interaction=true,interactionPowered=true}
local choicesShown={}
local rules={nobleManners={normal={influence=2},powered={influence=4},
    interactionReward={normal={fame=1},powered={fame=1,rep=1}}}}
local env={
    gameCards={[guid]={cardType="Starting",resourceKey="nobleManners"}},
    cardResourceDefinitions=rules,skillResourceDefinitions={},skillTokens={},
    gStates={startingCardSelections={[guid]=selection}},
    combatConfig={sourceFields={}},
    combatAssignmentState={targets={}},
    trackerPrivate={singleAutoEnemyGUID=nil,playCardMovements={}},
    selectedResourceByGUID={},choiceExpandedByGUID={},
    choiceButtonShown=choicesShown,choiceLetters={influence="I"},
    combatCalcOn=false,combatPsychicActive=false,combatCumbersomeActive=false,
    resourceCardsDetailsOpen=function() return true end,
    factionRewardForObject=function() return nil end,
    cardPosture=function(obj)
        local tilt=(obj.rotation[2] or 0)%180
        if tilt<25 then return "upright" end
        if tilt<=70 then return "discard" end
        return "sideways"
    end,
    choiceCategory=function(choice)
        if choice.key~=nil then return choice.key end
        for key in pairs(choice) do return key end
    end,
    currentChoice=function(_,_,choices)
        return choices[1],"influence"
    end,
    resourceChoiceRank=function() return 1 end,
    combatReductionChoiceIcon=function(_,_,_,category) return category end,
    resourceCardsHideAutomaticEnemyTarget=function() return false end,
    resourceChoiceColumn=function(category) return category end,
    resourceCardsChoiceIcon=function(category) return {name=category} end,
    resourceCardsChoiceAssetsFor=function() return nil,{} end,
    resourceObjectUiXmlTable=function(ui) return ui.xml end,
    resourceObjectUiSetTable=function(ui,xml)
        xmlWrites=xmlWrites+1
        ui.xml=xml
    end,
    removeChoiceButtons=function(obj)
        local filtered={}
        for _,element in ipairs(obj.UI.xml) do
            local id=element.attributes~=nil and element.attributes.id or ""
            if not id:find("^ResourceCardChoice_") and
                not id:find("^AttackAssignmentSource_") then
                filtered[#filtered+1]=element
            end
        end
        obj.UI.xml=filtered
        choicesShown[obj.guid]=nil
        xmlWrites=xmlWrites+1
    end
}
setmetatable(env,{__index=_G})
local assets=read("src/PlayingGame/UIAssets.lua")
local sameStart=assert(assets:find("function resourceObjectUiSameXML(left,right)",1,true))
local sameEnd=assert(assets:find("-- Legacy shared artwork",sameStart,true))
assert(load(assets:sub(sameStart,sameEnd-1),"Shared UI comparison","t",env))()
local render=assert(load(uiSection.."\nreturn showChoiceButtons",
    "Noble Manners interaction UI","t",env))()
-- Check the shared recovery path for an ordinary Action's resource button and
-- Ambush's separate target button, not just Noble Manners' interaction toggle.
local ordinaryUI={xml={{
    tag="Button",attributes={id="ResourceCardChoice_20cb85_attack"}},
    {tag="Button",attributes={id="AttackAssignmentSource_20cb85_0_ambush"}},
    {tag="Button",attributes={id="ResourceCardChoice_other_card"}}}}
local expected=env.combatConfig.cardChoiceIds("20cb85",ordinaryUI.xml)
assert(#expected==2, "Only this card's own resource and target controls should be tracked")
env.combatConfig.cardButtonIds["20cb85"]=expected
local ordinaryCard={guid="20cb85",UI=ordinaryUI}
assert(env.combatConfig.cardChoicesPresent(ordinaryCard),
    "An unchanged Action or Ambush target UI must be reused")
table.remove(ordinaryUI.xml,2)
assert(not env.combatConfig.cardChoicesPresent(ordinaryCard),
    "A lost Ambush target button must invalidate the cached signature")
table.remove(ordinaryUI.xml,1)
assert(not env.combatConfig.cardChoicesPresent(ordinaryCard),
    "A missing resource choice icon must invalidate the cached signature")
local function hasInteraction()
    for _,element in ipairs(card.UI.xml) do
        if element.attributes~=nil
            and element.attributes.id=="ResourceCardChoice_"..guid.."_interaction" then
            return true,element
        end
    end
    return false
end
local function refresh()
    render(card,nil,true,nil,nil,{influence=4},nil)
end
refresh()
assert(hasInteraction(),"Powered Noble Manners must display its Interaction button")
local writesAtRest=xmlWrites
card.held_by_color="Blue"
card.rotation={0,45,0}
refresh()
assert(xmlWrites==writesAtRest and hasInteraction(),
    "Picking up or temporarily tilting the card must not remove Interaction")
-- A temporary play-zone exit must not tear down the button. The relevant
-- scan cleanup is also checked above, without simulating a second whole scan.
card.held_by_color=nil
card.rotation={0,0,0}
card.moving=true
refresh()
assert(xmlWrites==writesAtRest and hasInteraction(),
    "Smooth movement must leave the card control attached")
card.moving=false
-- A real pickup creates this transaction; the subsequent drop preserves it
-- until X/Z and orientation settle, even when the resting flag is false.
env.trackerPrivate.playCardMovements[guid]={seatPos=1}
card.resting=false
card.rotation={0,45,0}
refresh()
assert(xmlWrites==writesAtRest and hasInteraction(),
    "A dropped but still-tumbling card must retain the Interaction button")
card.resting=true
card.rotation={0,0,0}
env.trackerPrivate.playCardMovements[guid]=nil
refresh()
assert(xmlWrites==writesAtRest and hasInteraction(),
    "Settling with an unchanged signature should not need a redraw")
-- Another object-UI writer can remove buttons without changing the resource
-- signature. Noble Manners must repair its missing Interaction control.
cardUI.xml={}
refresh()
assert(hasInteraction() and xmlWrites==writesAtRest+1,
    "Missing Interaction control must be rebuilt even if signature is unchanged")
assert(selection.interaction==true and selection.interactionPowered==true,
    "Rebuilding the UI must not toggle or unpower the Interaction reward")
-- A genuinely discarded card (resting at 45 degrees) may lose the control.
card.rotation={0,45,0}
refresh()
assert(not hasInteraction(),
    "An actual discarded orientation must remove the old control")
card.rotation={0,0,0}
refresh()
assert(hasInteraction(),"Returning the card upright must restore Interaction")
print("Noble Manners interaction button movement regression passed")
