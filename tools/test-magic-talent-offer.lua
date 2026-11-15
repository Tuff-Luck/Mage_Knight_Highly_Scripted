-- Physical Magic Talent browser regression checks.
-- Run from repository root: lua5.2 tools/test-magic-talent-offer.lua
local function eq(a,b,label)
    assert(a==b,(label or "Mismatch")..": expected "..tostring(b)..", got "..tostring(a))
end
local function copy(p) return {p[1],p[2],p[3]} end
local function fakeCard(guid,x,z)
    local card={guid=guid,type="Card",position={x,1,z},rotation={0,180,0},
        scale={1.5,1,1.5},is_face_down=false,resting=true,held_by_color=nil}
    local xml={}
    card.UI={
        getXmlTable=function() return xml end,
        setXmlTable=function(v) xml=v end,
        setXml=function(v) assert(v=="") xml={} end
    }
    card.getPosition=function() return copy(card.position) end
    card.getRotation=function() return copy(card.rotation) end
    card.getScale=function() return copy(card.scale) end
    card.setPosition=function(v) card.position=copy(v) end
    card.setPositionSmooth=function(v) card.position=copy(v) end
    card.setRotation=function(v) card.rotation=copy(v) end
    card.setRotationSmooth=function(v) card.rotation=copy(v) end
    card.setScale=function(v) card.scale=copy(v) end
    card.isSmoothMoving=function() return false end
    card.unlock=function() end
    card.lock=function() end
    return card
end

local talent=fakeCard("3d832c",0,0)
local red1=fakeCard("aa1111",10,-20)
local red2=fakeCard("aa2222",15,-20)
local blue=fakeCard("2eb8e2",20,-20)
local redCost=fakeCard("cc1111",0.4,0.2)
local blueCost=fakeCard("cc2222",0.4,0.2)
local cards={talent,red1,red2,blue,redCost,blueCost}
local objects={}
for _,card in ipairs(cards) do objects[card.guid]=card end
local zones={
    offer={position={0,1,-20}},
    play={position={0,1,0}},
    discard={position={0,1,-40}},
    hand={position={0,1,-50}}
}
for _,zone in pairs(zones) do
    zone.getPosition=function() return copy(zone.position) end
end
local function inZone(guid,zone)
    local card=objects[guid]
    if card==nil then return false end
    local z=card.position[3]
    if zone=="offer" then return math.abs(z+20)<1 end
    if zone=="play" then return math.abs(z)<7 end
    if zone=="discard" then return math.abs(z+40)<2 end
    if zone=="hand" then return math.abs(z+50)<2 end
    return false
end
for name,zone in pairs(zones) do
    local zoneName=name
    zone.getObjects=function()
        local result={}
        for _,card in ipairs(cards) do
            if inZone(card.guid,zoneName) then result[#result+1]=card end
        end
        return result
    end
end
getObjectFromGUID=function(guid) return objects[guid] or zones[guid] end
objectGUIDInZone=inZone
mainOfferCardsByType=function(kind)
    assert(kind=="Spell")
    local order={}
    for _,card in ipairs({red1,red2,blue}) do
        if inZone(card.guid,"offer") then order[#order+1]=card end
    end
    return order
end
gameCards={
    ["3d832c"]={cardType="Advanced Action",color={"Blue"}},
    ["aa1111"]={cardType="Spell",color={"Red"}},
    ["aa2222"]={cardType="Spell",color={"Red"}},
    ["2eb8e2"]={cardType="Spell",color={"Blue"}},
    ["cc1111"]={cardType="Starting",color={"Red"}},
    ["cc2222"]={cardType="Starting",color={"Blue"}}
}
GUID={card={timeBending="2eb8e2"},zone={offer="offer"}}
playerPlayAreas={[1]="play"}
handZones={[1]="hand"}
deedDeckDiscardZones={[1]="discard"}
turnOrder={{seatPos=1,deadDeckInventory={}}}
gStates={firstStarted=true,turnNumber=1,tacticShown=false,tacticRemove=false}
cardEffectIsVertical=function() return true end
ttsVectorArray=copy
local payments={}
magicTalentManaPayments=function(_seat) return payments end
resourceCardsGoldAllowed=function() return true end
resourceCardsTimeBendingPaid=function() return true end
resourceCardScanBySeat={[1]={cards={}}}
resourceCardsSourceChanged=function() end
playAreaScaleForgetObject=function() end
combatForgetPhysicalSourceTargets=function(_guid) end
attackAssignmentsClearForObject=function() end
scheduleDeedPileDescriptionRefresh=function() end
warningColor={1,0.8,0.2}
positionToColor=function() return "Blue" end
safeBroadcastToColor=function() end
safeWaitFrames=function(_,callback) callback() end
safeWaitCondition=function(_,callback,condition)
    if condition()==true then callback() end
end
legalPlayerCheck=function() return true end
resourceObjectUiXmlTable=function(ui) return ui.getXmlTable() end
resourceObjectUiRemovePrefixes=function(card,prefixes)
    local kept={}
    for _,node in ipairs(card.UI.getXmlTable()) do
        local id=node.attributes and node.attributes.id or ""
        local remove=false
        for _,prefix in ipairs(prefixes) do
            if id:sub(1,#prefix)==prefix then remove=true end
        end
        if not remove then kept[#kept+1]=node end
    end
    card.UI.setXmlTable(kept)
end
resourceObjectUiSetTable=function(ui,xml) ui.setXmlTable(xml) end
resourceCardsExistingImageAssetsFor=function() return {} end
callOfferAppendBrowseControls=function(xml,guid,prefix,callback,withClaim)
    xml[#xml+1]={tag="Button",attributes={id=prefix..guid.."_previous"}}
    xml[#xml+1]={tag="Button",attributes={id=prefix..guid.."_next"}}
    if withClaim then xml[#xml+1]={tag="Button",attributes={id=prefix..guid.."_claim"}} end
    return {}
end
createClaimButton=function(guid) return {tag="Button",attributes={id=guid.."offer"}} end
publishPublicUICallbacks=function(callbacks)
    for key,func in pairs(callbacks) do _G[key]=func end
end
local fills=0
compactAndRefillDeedOffer=function() fills=fills+1 end

local function hasButton(card,action)
    for _,node in ipairs(card.UI.getXmlTable()) do
        if node.attributes and node.attributes.id=="MagicTalentControl_"..card.guid.."_"..action then
            return true
        end
    end
    return false
end

dofile("src/PlayingGame/MagicTalentOffer.lua")
eq(gStates.magicTalentPreview,nil,"No free initial preview")
magicTalentHandLeft(redCost.guid,1)
magicTalentSync()
local s=assert(gStates.magicTalentPreview,"Coloured discard starts basic borrow")
eq(s.mode,"basic","Basic branch")
eq(s.color,"Red","Discard colour")
eq(s.cardGUID,red1.guid,"First matching Spell")
eq(inZone(redCost.guid,"discard"),true,"Hand cost automatically discarded")
eq(hasButton(red1,"previous"),true,"Browse controls")
eq(hasButton(red1,"claim"),false,"Basic Spell cannot be claimed")
eq(magicTalentReservedCard(red1.guid),true,"Temporary offer claim protected")
eq(red1.position[3],0,"Borrowed Spell is in the play area")

resourceCardScanBySeat[1].cards[red1.guid]={spellCastPaid=true}
magicTalentClicked({color="Blue"},nil,"MagicTalentControl_"..red1.guid.."_next")
eq(s.cardGUID,red1.guid,"Paid Spell cannot be browsed away")
resourceCardScanBySeat[1].cards[red1.guid]={spellCastPaid=false}
magicTalentClicked({color="Blue"},nil,"MagicTalentControl_"..red1.guid.."_next")
eq(s.cardGUID,red2.guid,"Unpaid Spell may be changed")
eq(inZone(red1.guid,"offer"),true,"Prior offer Spell restored")
magicTalentClose(true)
eq(gStates.magicTalentPreview,nil,"Basic preview closes")
eq(inZone(red2.guid,"offer"),true,"Turn cleanup returns borrowed Spell")

payments={{guid="m1",color="Blue"}}
magicTalentSync()
eq(gStates.magicTalentPreview,nil,"One mana does not open strong browser")
payments={{guid="m1",color="Blue"},{guid="m2",color="Red"}}
magicTalentSync()
s=assert(gStates.magicTalentPreview,"Two mana opens strong browser")
eq(s.mode,"strong","Strong branch")
eq(s.cardGUID,red1.guid,"Strong filter uses extra mana colour")
eq(hasButton(red1,"claim"),true,"Strong Take button")
magicTalentClicked({color="Blue"},nil,"MagicTalentControl_"..red1.guid.."_claim")
eq(s.mode,"claimed","Single claim latched")
eq(inZone(red1.guid,"discard"),true,"Claimed Spell physically discarded")
eq(turnOrder[1].deadDeckInventory[1],red1.guid,"Claim is owned by player")
eq(fills,1,"Claim triggers offer refill")
magicTalentSync()
eq(s.cardGUID,nil,"No duplicate claim on rescan")
magicTalentClose(true)
payments={}

-- Special rule: a borrowed Time Bending would set aside Magic Talent.
magicTalentHandLeft(blueCost.guid,1)
magicTalentSync()
s=assert(gStates.magicTalentPreview,"Blue discard starts Blue preview")
eq(s.cardGUID,blue.guid,"Borrowed Time Bending")
eq(magicTalentBorrowedTimeBendingPaid(1),true,"Borrowed Time Bending identified")
magicTalentClose(true)
print("Magic Talent physical offer regression tests passed")
