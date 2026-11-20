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
    card.setPositionSmooth=function(v,collide,fast) card.position=copy(v) end
    card.setRotation=function(v) card.rotation=copy(v) end
    card.setRotationSmooth=function(v,collide,fast) card.rotation=copy(v) end
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

local maximalCopy=nil
resourceCardsMaximalEffectLink=function() return maximalCopy end
local excludedPowerMana={}
resourceCardsMaximalEffectSourceManaGUIDs=function()
    return excludedPowerMana
end
local spellPaymentCounts={}
magicTalentSpellCastingPaymentCount=function(_,guid)
    return spellPaymentCounts[guid] or 0
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

-- Maximal Effect stronger side: two independent coloured mana payments
-- buy exactly two Spells, without paying Magic Talent's Blue power again.
red1.setPosition({10,1,-20})
red2.setPosition({15,1,-20})
talent.is_face_down=true
maximalCopy={powered=true,count=2,sourceGUID="8fac50"}
excludedPowerMana={manaRed1=true}
payments={{guid="manaRed1",color="Red"},{guid="manaRed2",color="Red"}}
magicTalentSync()
eq(gStates.magicTalentPreview,nil,
    "Mana already powering Maximal Effect cannot pay Magic Talent again")
payments[#payments+1]={guid="manaRed3",color="Red"}
magicTalentSync()
s=assert(gStates.magicTalentPreview,"Copied strong Magic Talent starts with two extra mana")
eq(s.mode,"strong","Copied strong mode")
eq(s.limit,2,"Two strong uses")
eq(s.cardGUID,red1.guid,"First strong preview")
magicTalentClicked({color="Blue"},nil,"MagicTalentControl_"..red1.guid.."_claim")
eq(s.used,1,"First of two strong claims committed")
eq(s.mode,"strong","Still entitled to second claim")
eq(s.cardGUID,red2.guid,"Second strong preview after refill")
magicTalentClicked({color="Blue"},nil,"MagicTalentControl_"..red2.guid.."_claim")
eq(s.used,2,"Second strong claim committed")
eq(s.mode,"claimed","Cannot claim a third")
eq(s.cardGUID,nil,"Strong copy cannot borrow after second claim")
magicTalentClose(true)
excludedPowerMana={}

-- Basic Maximal Effect must discard all three additional hand cards
-- even when the player skips one of the permitted Spell casts.
maximalCopy={powered=false,count=3}
payments={}
red1.setPosition({10,1,-20})
red2.setPosition({15,1,-20})
blue.setPosition({20,1,-20})
redCost.setPosition({0.4,1,0.2})
blueCost.setPosition({0.5,1,0.25})
local anotherCost=fakeCard("cc3333",0.6,0.3)
cards[#cards+1]=anotherCost
objects[anotherCost.guid]=anotherCost
gameCards[anotherCost.guid]={cardType="Starting",color={"Red"}}
magicTalentHandLeft(redCost.guid,1)
magicTalentHandLeft(blueCost.guid,1)
magicTalentSync()
eq(gStates.magicTalentPreview,nil,"Cannot start three basic uses with only two discards")
magicTalentHandLeft(anotherCost.guid,1)
magicTalentSync()
s=assert(gStates.magicTalentPreview,"Three discards start basic repetition")
eq(s.limit,3,"Three basic uses")
eq(inZone(redCost.guid,"discard"),true,"First card discarded")
eq(inZone(blueCost.guid,"discard"),true,"Second card discarded")
eq(inZone(anotherCost.guid,"discard"),true,"Third card discarded")
eq(hasButton(red1,"nextUse"),true,"Next use control offered")
eq(hasButton(red1,"sameUse"),true,"Same Spell control offered")
resourceCardScanBySeat[1].cards[red1.guid]={spellCastPaid=true}
magicTalentClicked({color="Blue"},nil,"MagicTalentControl_"..red1.guid.."_nextUse")
eq(s.used,1,"First Spell cast committed")
eq(s.cardGUID,blue.guid,"Blue discard permits Blue Spell second")
eq(inZone(red1.guid,"play"),true,"First cast remains physically in play")
eq(magicTalentReservedCard(red1.guid),true,"First borrowed Spell still reserved")
eq(magicTalentBorrowedTimeBendingPaid(1),true,"Current Time Bending cast remains valid")
resourceCardScanBySeat[1].cards[blue.guid]={spellCastPaid=false}
magicTalentClicked({color="Blue"},nil,"MagicTalentControl_"..blue.guid.."_nextUse")
eq(s.used,2,"Uncast optional second Spell skipped")
eq(inZone(blue.guid,"offer"),true,"Skipped Spell returned")
eq(s.cardGUID,red2.guid,"Third Red cost can borrow a second Red Spell")
resourceCardScanBySeat[1].cards[red2.guid]={spellCastPaid=true}
magicTalentClicked({color="Blue"},nil,"MagicTalentControl_"..red2.guid.."_nextUse")
eq(s.mode,"completed","Third basic use completes the composite")
eq(s.cardGUID,nil,"No fourth preview")
magicTalentClose(true)
eq(inZone(red1.guid,"offer"),true,"First borrowed cast restored at turn cleanup")
eq(inZone(red2.guid,"offer"),true,"Third borrowed cast restored at turn cleanup")

-- Repeating a single physical Spell requires a fresh casting mana each time.
red1.setPosition({10,1,-20})
red2.setPosition({15,1,-20})
redCost.setPosition({0.4,1,0.2})
blueCost.setPosition({0.5,1,0.25})
anotherCost.setPosition({0.6,1,0.3})
gameCards[blueCost.guid].color={"Red"}
magicTalentHandLeft(redCost.guid,1)
magicTalentHandLeft(blueCost.guid,1)
magicTalentHandLeft(anotherCost.guid,1)
magicTalentSync()
s=assert(gStates.magicTalentPreview,"Same-Spell setup")
eq(s.cardGUID,red1.guid,"Same-Spell first offer card")
resourceCardScanBySeat[1].cards[red1.guid]={spellCastPaid=true}
spellPaymentCounts[red1.guid]=1
magicTalentClicked({color="Blue"},nil,"MagicTalentControl_"..red1.guid.."_sameUse")
eq(s.used,0,"One mana cannot be spent twice")
spellPaymentCounts[red1.guid]=2
magicTalentClicked({color="Blue"},nil,"MagicTalentControl_"..red1.guid.."_sameUse")
eq(s.used,2,"Second mana settles the first and second casts")
spellPaymentCounts[red1.guid]=3
magicTalentClicked({color="Blue"},nil,"MagicTalentControl_"..red1.guid.."_sameUse")
eq(s.mode,"completed","Third paid cast finishes repeated Spell")
eq(magicTalentOfferSpellCastCount(1,red1.guid),3,"Same Spell has three paid copies")
spellPaymentCounts[red1.guid]=1
eq(magicTalentOfferSpellCastCount(1,red1.guid),1,
    "Removing two casting mana retracts repeated uses")
magicTalentClose(true)
maximalCopy=nil
talent.is_face_down=false

print("Magic Talent physical offer regression tests passed")
