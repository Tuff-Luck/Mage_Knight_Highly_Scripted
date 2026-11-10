-- Physical Call to Arms / Call to Glory offer browser regression tests.
-- Run from repository root: lua5.2 tools/test-call-offer.lua
local function eq(actual,expected,label)
    if actual~=expected then
        error((label or "Mismatch")..": "..tostring(actual).." ~= "..tostring(expected),2)
    end
end
local function copy(v) return {v[1],v[2],v[3]} end
local function fakeCard(guid,x,z)
    local card={guid=guid,position={x,1,z},rotation={0,180,0},scale={1.5,1,1.5},
        resting=true,held_by_color=nil,locked=true,is_face_down=false}
    local xml,assets={},{}
    local writes=0
    card.UI={
        getXmlTable=function() return xml end,
        getCustomAssets=function() return assets end,
        getWrites=function() return writes end,
        setXmlTable=function(nextXml,newAssets)
            assert(type(nextXml)=="table" and #nextXml>0,
                "TTS UI.setXmlTable rejects an empty/null XML table")
            -- TTS accepts {{}} by itself for clearing, but cannot combine
            -- that empty placeholder with real Button/Text nodes.
            for _,node in ipairs(nextXml) do
                assert(type(node)=="table"
                    and (type(node.tag)=="string"
                        or (#nextXml==1 and next(node)==nil)),
                    "invalid/mixed empty object XML node")
            end
            writes=writes+1
            xml=nextXml
            if newAssets~=nil then assets=newAssets end
        end
    }
    card.getPosition=function() return copy(card.position) end
    card.getRotation=function() return copy(card.rotation) end
    card.getScale=function() return copy(card.scale) end
    card.setPositionSmooth=function(v) card.position=copy(v) end
    card.setRotationSmooth=function(v) card.rotation=copy(v) end
    card.setPosition=function(v) card.position=copy(v) end
    card.setRotation=function(v) card.rotation=copy(v) end
    card.setScale=function(v) card.scale=copy(v) end
    card.unlock=function() card.locked=false end
    card.lock=function() card.locked=true end
    card.isSmoothMoving=function() return false end
    return card
end
local spell=fakeCard("2eb8e8",-60,-43)
local first=fakeCard("111111",36,-4.2)
local second=fakeCard("222222",31.2,-4.2)
local third=fakeCard("333333",26.4,-4.2)
local all={["2eb8e8"]=spell,["111111"]=first,["222222"]=second,["333333"]=third}
local spellInPlay=true
local function inOffer(card)
    return math.abs(card.position[3]+4.2)<0.8
end
local zones={
    offer={getObjects=function()
        local cards={}
        for _,unit in ipairs({first,second,third}) do
            if inOffer(unit) then cards[#cards+1]=unit end
        end
        return cards
    end},
    play={getObjects=function() return spellInPlay and {spell} or {} end},
    army={getObjects=function()
        local cards={}
        for _,unit in ipairs({first,second,third}) do
            if math.abs(unit.position[3]+34.74)<0.8 then cards[#cards+1]=unit end
        end
        return cards
    end}
}
GUID={zone={unitOffer="offer"}}
playerPlayAreas={"play"}
playerUnitAreas={"army"}
gStates={}
getObjectFromGUID=function(guid) return zones[guid] or all[guid] end
callOfferAvailableUnits=function()
    local units=zones.offer.getObjects()
    table.sort(units,function(a,b) return a.position[1]>b.position[1] end)
    return units
end
local pendingChecks={}
safeWaitFrames=function(_,callback) callback() end
safeWaitCondition=function(_,callback,condition)
    if condition() then callback()
    else pendingChecks[#pendingChecks+1]={callback=callback,condition=condition} end
end
local function settlePending()
    local pending=pendingChecks
    pendingChecks={}
    for _,check in ipairs(pending) do
        if check.condition() then check.callback()
        else pendingChecks[#pendingChecks+1]=check end
    end
end
legalPlayerCheck=function() return true end
local stopped=0
resourceUnitsBorrowedUnitEnded=function(guid)
    -- The preview is no longer an eligible calculator source during cleanup.
    assert(gStates.callOfferPreview==nil
        or gStates.callOfferPreview.unitGUID~=guid,
        "Combat targets cleared before the borrowed Unit was retired")
    stopped=stopped+1
end
resourceCardsSourceChanged=function() end
publishPublicUICallbacks=function(callbacks)
    for name,callback in pairs(callbacks) do _G[name]=callback end
end
dofile("src/PlayingGame/UIAssets.lua")
dofile("src/PlayingGame/CallOffer.lua")
local function hasArrow(card,direction)
    for _,node in ipairs(card.UI.getXmlTable()) do
        local id=node.attributes and node.attributes.id
        if id=="CallOfferControl_"..card.guid.."_"..direction then return true end
    end
    return false
end
callOfferSpellEntered(spell.guid,1)
eq(gStates.callOfferPreview.unitGUID,first.guid,"initial offered Unit")
eq(first.position[3],spell.position[3],"borrowed Unit alongside Spell")
eq(first.scale[1],1.5,"full-sized Unit")
eq(hasArrow(first,"previous"),true,"left arrow present")
eq(hasArrow(first,"next"),true,"right arrow present")
-- Each button has a reusable registered image, rather than XML-unsafe text.
local arrowImages={previous="Overkill Down",next="Overkill Up"}
for _,node in ipairs(first.UI.getXmlTable()) do
    local id=node.attributes and node.attributes.id or ""
    local direction=id:match("^CallOfferControl_111111_(previous)$")
        or id:match("^CallOfferControl_111111_(next)$")
    if direction~=nil then
        eq(node.value,nil,"no text or XML delimiters on arrow")
        eq(node.children[1].tag,"Image","arrow is a real image")
        eq(node.children[1].attributes.image,arrowImages[direction],"correct scale artwork")
        eq(node.attributes.rotation,"0 0 0","current Offer arrow orientation")
        eq(node.children[1].attributes.rotation,nil,"image needs no independent rotation")
    end
end
local registered={}
for _,asset in ipairs(first.UI.getCustomAssets()) do registered[asset.name]=asset.url end
for _,name in pairs(arrowImages) do
    assert(type(registered[name])=="string" and registered[name]:find("steamusercontent",1,true),
        "Unit UI is missing image asset "..name)
end
eq(callOfferBorrowedUnitForSeat(1),first,"one temporary selected Unit")
-- Moving the Spell out of the zone while held is just rearrangement.
local selected=gStates.callOfferPreview
spell.held_by_color="Red"
spell.resting=false
spellInPlay=false
callOfferSpellPickedUp()
callOfferSpellLeft(spell.guid,1)
eq(gStates.callOfferPreview,selected,"dragged Spell keeps borrowed Unit")
callOfferSpellChanged()
eq(gStates.callOfferPreview,selected,"in-flight Spell is not discarded")
spell.setPosition({-57,1,-42})
spellInPlay=true
spell.held_by_color=nil
spell.resting=true
callOfferScheduleSpellCheck()
settlePending()
eq(gStates.callOfferPreview,selected,"repositioned Spell keeps preview")
eq(first.position[1],-56.1,"repositioned Spell does not drag Unit")
-- Repositioning the actual Unit is also safe and defines the next browse slot.
first.setPosition({-53,1,-40})
first.setRotation({0,165,0})
-- Simulate another zone/UI handler replacing the Unit's object UI in flight.
local trackerChoice={tag="Button",attributes={id="ResourceCardChoice_111111_unit1"}}
first.UI.setXmlTable({trackerChoice})
eq(hasArrow(first,"next"),false,"zone refresh removed browser controls")
callOfferObjectDropped(first)
eq(gStates.callOfferPreview,selected,"repositioned Unit stays borrowed")
eq(first.position[1],-53,"manually placed Unit stays put")
eq(hasArrow(first,"previous"),true,"left browser arrow restored after drop")
eq(hasArrow(first,"next"),true,"right browser arrow restored after drop")
local preserved=false
for _,node in ipairs(first.UI.getXmlTable()) do
    if node.attributes~=nil and node.attributes.id=="ResourceCardChoice_111111_unit1" then
        preserved=true
    end
end
eq(preserved,true,"resource buttons are preserved while restoring arrows")
local writes=first.UI.getWrites()
callOfferEnsureControls(1)
eq(first.UI.getWrites(),writes,"healthy browser UI is not rebuilt on every tracker scan")
-- Simulate an asynchronous tracker refresh that removes just one arrow.
local xml=first.UI.getXmlTable()
for i=#xml,1,-1 do
    local id=xml[i].attributes~=nil and xml[i].attributes.id or nil
    if id=="CallOfferControl_111111_previous" then table.remove(xml,i) end
end
first.UI.setXmlTable(xml)
callOfferEnsureControls(1)
eq(hasArrow(first,"previous"),true,"late tracker UI refresh repairs missing arrow")
eq(hasArrow(first,"next"),true,"existing arrow remains available")
callOfferCycleClicked({color="Red"},nil,"CallOfferControl_111111_next")
eq(first.position[1],36,"first Unit returned to its original slot")
eq(first.locked,true,"returned Unit locked")
eq(hasArrow(first,"next"),false,"returned Unit has no arrows")
eq(gStates.callOfferPreview.unitGUID,second.guid,"next original card selected")
eq(second.position[1],-53,"next Unit occupies manually chosen position")
eq(second.rotation[2],165,"next Unit uses chosen orientation")
callOfferCycleClicked({color="Red"},nil,"CallOfferControl_222222_previous")
eq(second.position[1],31.2,"second Unit restored on reverse")
eq(gStates.callOfferPreview.unitGUID,first.guid,"previous card selected")
eq(first.position[1],-53,"browsing back preserves selected display position")
-- Loading an active game restores object-attached arrows without moving cards.
first.UI.setXmlTable({{}})
callOfferRestoreOnLoad()
eq(hasArrow(first,"next"),true,"saved offer browser controls restored")
-- Simulate the first paid Call to Arms scan (and the next powered scan):
-- Unit ability buttons must be appended to real nodes, never to {{}}.
first.UI.setXmlTable({{}})
local poweredXml=resourceObjectUiXmlTable(first.UI)
eq(#poweredXml,0,"empty XML placeholder is removed before payment UI")
poweredXml[#poweredXml+1]={tag="Button",attributes={
    id="ResourceCardChoice_111111_unit1"}}
first.UI.setXmlTable(poweredXml)
callOfferEnsureControls(1)
eq(hasArrow(first,"next"),true,"browser survives paid spell button render")
local paidChoicePresent=false
for _,node in ipairs(first.UI.getXmlTable()) do
    if node.attributes~=nil
        and node.attributes.id=="ResourceCardChoice_111111_unit1" then
        paidChoicePresent=true
    end
end
eq(paidChoicePresent,true,"paid Unit choice survives restored offer arrows")
for _,node in ipairs(first.UI.getXmlTable()) do
    assert(type(node.tag)=="string","no empty placeholder mixed with paid Unit controls")
end
-- A Spell genuinely dropped outside the play area still returns the Unit.
spellInPlay=false
callOfferScheduleSpellCheck()
settlePending()
eq(gStates.callOfferPreview,nil,"spell exit closes the browser")
eq(first.position[1],36,"spell exit restored offer position")
eq(inOffer(first),true,"spell exit returns offer membership")
-- The player can manually recruit the same card with Call to Glory.
spellInPlay=true
callOfferSpellEntered(spell.guid,1)
first.setPosition({-60,1,-34.74})
callOfferObjectDropped(first)
eq(gStates.callOfferPreview,nil,"recruited Unit stops being loaned")
eq(gStates.callOfferGloryClaimed,true,"Call to Glory completion is saved")
eq(first.position[3],-34.74,"recruited Unit remains in army")
eq(hasArrow(first,"next"),false,"recruited Unit loses browser arrows")
-- Repositioning the Spell must not produce a second Unit.
spell.held_by_color="Red"
spell.resting=false
spellInPlay=false
callOfferSpellPickedUp()
callOfferSpellLeft(spell.guid,1)
eq(gStates.callOfferGloryClaimed,true,"temporary Spell exit retains use")
spell.setPosition({-55,1,-41})
spellInPlay=true
spell.held_by_color=nil
spell.resting=true
callOfferScheduleSpellCheck()
settlePending()
callOfferSpellEntered(spell.guid,1)
eq(gStates.callOfferPreview,nil,"repositioned Spell does not borrow another Unit")
eq(second.position[1],31.2,"second offered Unit stays in the offer")
-- Refreshing the offer and saving/loading also must not reset the one-use flag.
callOfferClose(true)
callOfferRestoreOnLoad()
eq(gStates.callOfferGloryClaimed,true,"offer maintenance and save restore keep recruitment")
spell.is_face_down=true
callOfferSpellChanged()
eq(gStates.callOfferGloryClaimed,true,"face-down flip does not refund recruitment")
spell.is_face_down=false
callOfferSpellChanged()
eq(gStates.callOfferPreview,nil,"flipping back up does not recruit twice")
-- A genuine settled Spell exit ends this play and allows a future play.
spellInPlay=false
callOfferSpellLeft(spell.guid,1)
settlePending()
eq(gStates.callOfferGloryClaimed,nil,"leaving play clears recruitment latch")
spellInPlay=true
callOfferSpellEntered(spell.guid,1)
eq(gStates.callOfferPreview.unitGUID,second.guid,"a genuinely new play opens the offer browser")
callOfferClose(true)
eq(second.position[1],31.2,"forced offer maintenance restores original slot")
eq(second.locked,true,"forced restore relocks Unit")
eq(gStates.callOfferPreview,nil,"cleanup clears saved loan")
-- A face-down spell does not borrow any Unit, including after a manual flip.
spell.is_face_down=true
callOfferSpellEntered(spell.guid,1)
eq(gStates.callOfferPreview,nil,"face-down spell does nothing")
eq(second.position[1],31.2,"face-down spell keeps offer intact")
spell.is_face_down=false
callOfferSpellChanged()
eq(gStates.callOfferPreview.unitGUID,second.guid,"flipped face-up opens browser")
spell.is_face_down=true
eq(callOfferBorrowedUnitForSeat(1),nil,"face-down spell grants no Unit source")
callOfferSpellChanged()
eq(gStates.callOfferPreview,nil,"flipped face-down closes browser")
eq(second.position[1],31.2,"face-down flip restores Unit to offer")
assert(stopped>0,"borrowed Unit activation was released")
print("Call Offer browser regressions passed")
