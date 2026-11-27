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
    ["3d832c"]={cardType="Advanced Action",resourceKey="magicTalent",color={"Blue"}},
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
local paidTalentGUID
magicTalentManaPayments=function(_seat,guid,_sourceGUIDs) paidTalentGUID=guid return payments end
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

dofile("src/PlayingGame/Offers/MagicTalentOffer.lua")
local function singleSession()
    local result
    for _,session in pairs(gStates.magicTalentPreviews or {}) do
        assert(result==nil,"Expected only one session in single-source test")
        result=session
    end
    return result
end
eq(singleSession(),nil,"No free initial preview")
magicTalentHandLeft(redCost.guid,1)
magicTalentSync()
local s=assert(singleSession(),"Coloured discard starts basic borrow")
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
eq(singleSession(),nil,"Basic preview closes")
eq(inZone(red2.guid,"offer"),true,"Turn cleanup returns borrowed Spell")

payments={{guid="m1",color="Blue"}}
magicTalentSync()
eq(singleSession(),nil,"One mana does not open strong browser")
payments={{guid="m1",color="Blue"},{guid="m2",color="Red"}}
magicTalentSync()
s=assert(singleSession(),"Two mana opens strong browser")
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
s=assert(singleSession(),"Blue discard starts Blue preview")
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
eq(singleSession(),nil,
    "Mana already powering Maximal Effect cannot pay Magic Talent again")
payments[#payments+1]={guid="manaRed3",color="Red"}
magicTalentSync()
s=assert(singleSession(),"Copied strong Magic Talent starts with two extra mana")
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
eq(singleSession(),nil,"Cannot start three basic uses with only two discards")
magicTalentHandLeft(anotherCost.guid,1)
magicTalentSync()
s=assert(singleSession(),"Three discards start basic repetition")
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
s=assert(singleSession(),"Same-Spell setup")
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

-- Alternate expansion copy has its own physical entitlement and mana footprint.
local alternate=fakeCard("e1a957",0,0)
cards[#cards+1]=alternate
objects[alternate.guid]=alternate
gameCards[alternate.guid]={cardType="Advanced Action",resourceKey="magicTalent",color={"Blue"}}
talent.setPosition({0,1,-50})
red1.setPosition({10,1,-20})
red2.setPosition({15,1,-20})
payments={{guid="alt1",color="Blue"},{guid="alt2",color="Red"}}
magicTalentSync()
s=assert(singleSession(),"Alternate copy opens strong browser")
eq(s.talentGUID,alternate.guid,"Loan belongs to alternate physical source")
eq(paidTalentGUID,alternate.guid,"Read only alternate source mana")
eq(s.cardGUID,red1.guid,"Alternate copy borrows same normal offer")
magicTalentClose(true)
payments={}
blue.setPosition({20,1,-20})
blueCost.setPosition({0.3,1,0.3})
gameCards[blueCost.guid].color={"Blue"}
magicTalentHandLeft(blueCost.guid,1)
magicTalentSync()
eq(magicTalentBorrowedTimeBendingSource(1),alternate.guid,"Time Bending sets aside actual source copy")
magicTalentClose(true)
print("Alternate Magic Talent copy passed")

-- Tome uses the same physical browser, but an explicit Cast replaces
-- the regular Spell payment. Check both sides and the no-preview rule.
magicTalentClose(true)
maximalCopy=nil
payments={}
talent.setPosition({0,1,-40})
alternate.setPosition({0,1,-40})
local tome=fakeCard("085e68",0,0)
cards[#cards+1]=tome
objects[tome.guid]=tome
gameCards[tome.guid]={cardType="Artifact",resourceKey="artifactUtility"}
local tomeBroken=false
resourceCardsArtifactBroken=function(_guid,_card) return tomeBroken end
red1.setPosition({10,1,-20})
red2.setPosition({15,1,-20})
redCost.setPosition({0.4,1,0.2})
magicTalentHandLeft(redCost.guid,1)
magicTalentSync()
s=assert(singleSession(),"Tome opens shared browser")
eq(s.mode,"tome","Tome awaits explicit Cast")
eq(magicTalentInactivePreview(red1.guid),true,"Tome preview is inert")
eq(magicTalentOfferCastSide(1,red1.guid),nil,"No free cast while browsing")
eq(inZone(redCost.guid,"discard"),true,"Tome discards matching hand card")
magicTalentClicked({color="Blue"},nil,"MagicTalentControl_"..red1.guid.."_next")
eq(s.cardGUID,red2.guid,"Tome can change uncast preview")
magicTalentClicked({color="Blue"},nil,"MagicTalentControl_"..red2.guid.."_claim")
eq(s.mode,"tomeCast","Tome confirms cast")
eq(magicTalentOfferCastSide(1,red2.guid),false,"Free basic side is distinct from nil")
eq(magicTalentOfferCastSide(2,red2.guid),nil,"Other seat cannot borrow free cast")
eq(magicTalentTomeCommitted(tome.guid),true,"Confirmed Tome side is locked")
eq(magicTalentReservedCard(red2.guid),true,"Tome retains physical loan")
local homes=magicTalentOfferLoanHomes()
eq(homes[red2.guid]~=nil,true,"Committed Spell occupies its offer home")
magicTalentOfferWillChange()
eq(inZone(red2.guid,"play"),true,"Reflow does not return committed Spell early")
homes[red2.guid].position={12,1,-20}
magicTalentClose(true)
eq(inZone(red2.guid,"offer"),true,"Basic Tome returns loan")
eq(red2.position[1],12,"Borrowed Spell returns to reflowed home")
tomeBroken=true
redCost.setPosition({0.4,1,0.2})
magicTalentHandLeft(redCost.guid,1)
magicTalentSync()
s=assert(singleSession(),"Broken Tome opens browser")
magicTalentClicked({color="Blue"},nil,"MagicTalentControl_"..s.cardGUID.."_claim")
local borrowed=s.freeGUID
eq(magicTalentOfferCastSide(1,borrowed),true,"Broken Tome grants free strong cast during Day")
magicTalentClose(true)
eq(inZone(borrowed,"offer"),true,"Strong Tome returns loan")
print("Tome of All Spells browser regressions passed")

-- Blood of Ancients: all matching/basic colours are purchase options;
-- red also permits borrowing an arbitrary stronger Advanced Action.
magicTalentClose(true)
tome.setPosition({0,1,-40})
local ancients=fakeCard("93b7d4",0,0)
local redAction=fakeCard("ab1111",10,-20)
local blueAction=fakeCard("ab2222",15,-20)
local dualAction=fakeCard("ab3333",20,-20)
for _,obj in ipairs({ancients,redAction,blueAction,dualAction}) do
    cards[#cards+1]=obj
    objects[obj.guid]=obj
end
gameCards[ancients.guid]={cardType="Advanced Action",resourceKey="bloodOfAncients",color={"Red"}}
gameCards[redAction.guid]={cardType="Advanced Action",color={"Red"}}
gameCards[blueAction.guid]={cardType="Advanced Action",color={"Blue"}}
gameCards[dualAction.guid]={cardType="Advanced Action",color={"White","Blue"}}
local spellOffer=mainOfferCardsByType
mainOfferCardsByType=function(kind)
    if kind=="Spell" then return spellOffer(kind) end
    assert(kind=="Advanced Action")
    local out={}
    for _,obj in ipairs({redAction,blueAction,dualAction}) do
        if inZone(obj.guid,"offer") then out[#out+1]=obj end
    end
    return out
end
local wounds={}
local failWound=false
combatDealCalculatedWounds=function(seat,allocations,onCard,onDone)
    eq(seat,1,"correct Wound seat")
    local entry=allocations[1]
    eq(entry.hand+entry.discard,1,"exactly one Wound")
    if failWound then onDone(false,"bag missing") return end
    local destination=entry.hand==1 and "hand" or "discard"
    wounds[#wounds+1]=destination
    onCard(entry.key,destination,"wound"..#wounds)
    onDone(true)
end
animateDeedCardToHand=function(obj,_seat,_delay) obj.setPosition({0,1,-50}) end
payments={}
magicTalentSync()
eq(singleSession(),nil,"No mana no Ancients browser")
payments={{guid="ancientsBlue",color="Blue"}}
magicTalentSync()
s=assert(singleSession(),"Blue purchases blue Actions")
eq(s.cardGUID,blueAction.guid,"Basic filter excludes red")
eq(hasButton(blueAction,"gainAncients"),true,"Gain available")
eq(hasButton(blueAction,"useAncientsHand"),false,"Blue cannot power strong")
eq(magicTalentInactivePreview(blueAction.guid),true,"Preview is inert")
eq(#wounds,0,"Browsing does not deal Wound")
magicTalentClicked({color="Blue"},nil,"MagicTalentControl_"..blueAction.guid.."_next")
eq(s.cardGUID,dualAction.guid,"Dual-colour match")
magicTalentClicked({color="Blue"},nil,"MagicTalentControl_"..dualAction.guid.."_previous")
eq(s.cardGUID,blueAction.guid,"Reverse navigation uses original offer column")
magicTalentClicked({color="Blue"},nil,"MagicTalentControl_"..blueAction.guid.."_next")
eq(s.cardGUID,dualAction.guid,"Forward navigation returns to dual colour")
failWound=true
magicTalentClicked({color="Blue"},nil,"MagicTalentControl_"..dualAction.guid.."_gainAncients")
eq(s.cardGUID,dualAction.guid,"Missing Wound bag cannot claim")
eq(gStates.ancientsOfferClaims,nil,"Failed cost does not consume entitlement")
failWound=false
magicTalentClicked({color="Blue"},nil,"MagicTalentControl_"..dualAction.guid.."_gainAncients")
eq(inZone(dualAction.guid,"hand"),true,"Basic gain goes to hand")
eq(wounds[1],"hand","Basic Wound goes to hand")
magicTalentClicked({color="Blue"},nil,"MagicTalentControl_"..dualAction.guid.."_gainAncients")
eq(#wounds,1,"Stale callback cannot deal another Wound")
magicTalentClose(true)
magicTalentSync()
eq(singleSession(),nil,"Consumed source cannot reopen during same turn")
gStates.ancientsOfferClaims=nil
payments={{guid="ancientsRed",color="Red"}}
magicTalentSync()
s=assert(singleSession(),"Red permits both effects")
eq(s.cardGUID,redAction.guid,"Red candidate")
eq(hasButton(redAction,"gainAncients"),true,"Red can buy red Action")
eq(hasButton(redAction,"useAncientsDiscard"),true,"Red also powers stronger effect")
magicTalentClicked({color="Blue"},nil,"MagicTalentControl_"..redAction.guid.."_next")
eq(s.cardGUID,blueAction.guid,"Strong can borrow another colour")
eq(hasButton(blueAction,"gainAncients"),false,"Red cannot buy blue Action")
magicTalentClicked({color="Blue"},nil,"MagicTalentControl_"..blueAction.guid.."_useAncientsDiscard")
eq(wounds[2],"discard","Strong Wound may go to discard")
eq(s.mode,"ancientsCast","Strong effect confirmed")
eq(magicTalentOfferCastSide(1,blueAction.guid),true,"Borrowed Action gets stronger effect")
eq(magicTalentInactivePreview(blueAction.guid),false,"Committed Action is active")
eq(magicTalentOfferLoanHomes()[blueAction.guid]~=nil,true,"Borrowed Action retains its offer slot")
magicTalentClose(true)
eq(inZone(blueAction.guid,"offer"),true,"Strong loan returns at cleanup")
gStates.ancientsOfferClaims=nil
payments={{guid="ancientsGreen",color="Green"}}
magicTalentSync()
eq(singleSession(),nil,"Unmatched basic payment does not deal a Wound")
payments={{guid="ancientsRed",color="Red"}}
maximalCopy={powered=true,count=2,sourceGUID="8fac50"}
magicTalentSync()
s=assert(singleSession(),"Repeated strong effect opens without additional power mana")
eq(s.limit,2,"Two stronger applications")
eq(hasButton(redAction,"gainAncients"),false,"Copied strong side cannot purchase")
eq(#wounds,2,"Browsing does not deal Wounds")
magicTalentClicked({color="Blue"},nil,"MagicTalentControl_"..redAction.guid.."_useAncientsHand")
eq(wounds[3],"hand","First stronger Wound to hand")
eq(s.used,1,"One stronger application committed")
eq(s.cardGUID,blueAction.guid,"Second distinct offer Action previewed")
eq(magicTalentOfferCastSide(1,redAction.guid),true,"First loan remains powered")
magicTalentClicked({color="Blue"},nil,"MagicTalentControl_"..blueAction.guid.."_useAncientsDiscard")
eq(wounds[4],"discard","Second stronger Wound to discard")
eq(s.used,2,"Two stronger applications committed")
eq(s.mode,"ancientsCast","Repeated stronger side complete")
eq(magicTalentOfferCastSide(1,redAction.guid),true,"First loan remains active")
eq(magicTalentOfferCastSide(1,blueAction.guid),true,"Second loan active")
eq(magicTalentOfferLoanHomes()[redAction.guid]~=nil,true,"First loan occupies offer slot")
eq(magicTalentOfferLoanHomes()[blueAction.guid]~=nil,true,"Second loan occupies offer slot")
magicTalentClose(true)
eq(inZone(redAction.guid,"offer"),true,"First loan restored")
eq(inZone(blueAction.guid,"offer"),true,"Second loan restored")

-- Basic repetition requires three distinct matching payments upfront.
gStates.ancientsOfferClaims=nil
dualAction.setPosition({20,1,-20})
maximalCopy={powered=false,count=3,sourceGUID="8fac50"}
payments={{guid="r1",color="Red"},{guid="b1",color="Blue"}}
magicTalentSync()
eq(singleSession(),nil,"Two mana cannot pay three basic applications")
payments[3]={guid="b1",color="Blue"}
magicTalentSync()
eq(singleSession(),nil,"Duplicate physical mana cannot be reused")
payments[3]={guid="w1",color="White"}
excludedPowerMana={r1=true}
magicTalentSync()
eq(singleSession(),nil,"Source payment cannot also fund basic gain")
excludedPowerMana={}
magicTalentSync()
s=assert(singleSession(),"Three distinct matching payments open browser")
eq(s.limit,3,"Three basic applications")
eq(hasButton(redAction,"useAncientsHand"),false,"Copied basic side never powers strong")
magicTalentClicked({color="Blue"},nil,"MagicTalentControl_"..redAction.guid.."_gainAncients")
eq(wounds[5],"hand","First basic Wound to hand")
eq(s.spentMana.r1,true,"First payment GUID consumed")
eq(s.used,1,"First basic application")
eq(s.cardGUID,blueAction.guid,"Second matching offer Action")
magicTalentClicked({color="Blue"},nil,"MagicTalentControl_"..blueAction.guid.."_gainAncients")
eq(s.spentMana.b1,true,"Second distinct payment consumed")
eq(s.cardGUID,dualAction.guid,"Third matching offer Action")
magicTalentClicked({color="Blue"},nil,"MagicTalentControl_"..dualAction.guid.."_gainAncients")
eq(s.spentMana.w1,true,"Third distinct payment consumed")
eq(s.used,3,"All three basic applications paid")
eq(#wounds,7,"Every application has one Wound")
eq(s.mode,"claimed","Three gains complete")
magicTalentClose(true)
gStates.ancientsOfferClaims=nil
redAction.setPosition({10,1,-20})
blueAction.setPosition({15,1,-20})
dualAction.setPosition({20,1,-20})
payments={{guid="ancientsRed",color="Red"}}
maximalCopy=nil
magicTalentSync()
s=assert(singleSession(),"Single use opens again")
payments={}
magicTalentClicked({color="Blue"},nil,"MagicTalentControl_"..s.cardGUID.."_gainAncients")
eq(#wounds,7,"Removed payment invalidates stale Gain")
magicTalentSync()
eq(singleSession(),nil,"Missing payment closes preview")
print("Blood of Ancients browser regressions passed")

-- Two physical Magic Talents and Tome can coexist. The fake payment
-- provider deliberately assigns each card its own local payment list.
magicTalentClose(true)
gStates.ancientsOfferClaims=nil
ancients.setPosition({0,1,-40})
talent.setPosition({-10,1,0})
alternate.setPosition({0,1,0})
tome.setPosition({10,1,0})
tomeBroken=false
red1.setPosition({10,1,-20})
red2.setPosition({15,1,-20})
blue.setPosition({20,1,-20})
redCost.setPosition({10.4,1,0.2})
gameCards[redCost.guid].color={"Red"}
magicTalentHandLeft(redCost.guid,1)
local bySource={
    [talent.guid]={{guid="m1",color="Blue"},{guid="m2",color="Blue"}},
    [alternate.guid]={{guid="m3",color="Blue"},{guid="m4",color="Red"}}
}
magicTalentManaPayments=function(_seat,guid,_sourceGUIDs) return bySource[guid] or {} end
magicTalentSync()
local all=gStates.magicTalentPreviews
local tomeSession=assert(all[tome.guid])
local firstSession=assert(all[talent.guid])
local secondSession=assert(all[alternate.guid])
eq(tomeSession.cardGUID,red1.guid,"Tome reserves its own preview")
eq(firstSession.cardGUID,blue.guid,"First Talent has its own Blue preview")
eq(secondSession.cardGUID,red2.guid,"Second Talent cannot reserve Tome's Red")
magicTalentClicked({color="Blue"},nil,"MagicTalentControl_"..red1.guid.."_claim")
eq(tomeSession.mode,"tomeCast","Tome confirmation routed to Tome")
eq(firstSession.mode,"strong","First Talent unaffected")
eq(secondSession.mode,"strong","Second Talent unaffected")
eq(magicTalentOfferCastSide(1,red1.guid),false,"Tome free side survives other previews")
eq(magicTalentOfferLoanHomes()[red1.guid]~=nil,true,"Committed Tome home retained")
magicTalentClicked({color="Blue"},nil,"MagicTalentControl_"..red2.guid.."_claim")
eq(secondSession.mode,"claimed","Second Talent claim routed to its source")
eq(inZone(red2.guid,"discard"),true,"Second Talent gained its own card")
eq(magicTalentReservedCard(red1.guid),true,"Tome loan protected after other claim")
eq(magicTalentReservedCard(blue.guid),true,"First Talent still reserved")
talent.setPosition({-10,1,-40})
magicTalentSync()
eq(all[talent.guid],nil,"Removed source closes only its session")
eq(inZone(blue.guid,"offer"),true,"Removed source restores its preview")
eq(magicTalentOfferCastSide(1,red1.guid),false,"Other loan remains active")
magicTalentClose(true)
eq(gStates.magicTalentPreviews,nil,"Turn cleanup closes all sessions")
eq(inZone(red1.guid,"offer"),true,"Loan restored at cleanup")
eq(inZone(red2.guid,"discard"),true,"Gained card remains owned")
print("Concurrent deed offer browser regressions passed")

-- Same physical Action can be selected twice without creating a second loan.
magicTalentClose(true)
talent.setPosition({0,1,-40})
alternate.setPosition({0,1,-40})
tome.setPosition({0,1,-40})
ancients.setPosition({0,1,0})
redAction.setPosition({10,1,-20})
blueAction.setPosition({15,1,-20})
dualAction.setPosition({20,1,-20})
cardResourceDefinitions={testBorrowedRepeat={powered={attack=6}}}
gameCards[redAction.guid].resourceKey="testBorrowedRepeat"
gStates.ancientsOfferClaims=nil
maximalCopy={powered=true,count=2,sourceGUID="8fac50"}
local beforeWounds=#wounds
magicTalentSync()
s=assert(singleSession(),"Same-Action browser")
eq(s.cardGUID,redAction.guid,"First Action selection")
magicTalentClicked({color="Blue"},nil,"MagicTalentControl_"..redAction.guid.."_useAncientsHand")
eq(hasButton(redAction,"sameAncientsHand"),true,"Same Hand control")
eq(hasButton(redAction,"sameAncientsDiscard"),true,"Same Discard control")
eq(magicTalentOfferActionRepeat(1,redAction.guid),nil,"Only one paid application initially")
local other=s.cardGUID
failWound=true
magicTalentClicked({color="Blue"},nil,"MagicTalentControl_"..redAction.guid.."_sameAncientsDiscard")
eq(s.cardGUID,other,"Failed Wound keeps alternative preview")
eq(s.used,1,"Failed payment does not repeat")
failWound=false
magicTalentClicked({color="Blue"},nil,"MagicTalentControl_"..redAction.guid.."_sameAncientsDiscard")
eq(#wounds,beforeWounds+2,"Exactly two Wounds dealt")
eq(s.used,2,"Same Action paid twice")
eq(s.cardGUID,nil,"Alternative preview returned")
eq(inZone(other,"offer"),true,"Unselected alternative restored")
local repeated=assert(magicTalentOfferActionRepeat(1,redAction.guid))
eq(repeated.count,2,"Shared repeated-effect count")
eq(repeated.powered,true,"Both applications stronger")
eq(repeated.borrowed,true,"Not a throw-away link")
eq(hasButton(redAction,"sameAncientsHand"),false,"Completed repeat control removed")
magicTalentClicked({color="Blue"},nil,"MagicTalentControl_"..redAction.guid.."_sameAncientsDiscard")
eq(#wounds,beforeWounds+2,"Stale repeat callback cannot deal a third Wound")
magicTalentClose(true)
eq(inZone(redAction.guid,"offer"),true,"Repeated borrowed Action returned once")
eq(magicTalentOfferActionRepeat(1,redAction.guid),nil,"No repeat after cleanup")
maximalCopy=nil
print("Repeated borrowed Action browser regressions passed")

-- Verify repeated printed costs in the actual shared Action link resolver.
package.path="src/?.lua;"..package.path
local resolve=require("PlayingGame.PlayerBoard.ResourceTracker.Cards.ActionLinks")({
    overlapArea=function(_a,_b) return 1 end,
    cardPosture=function(obj) return obj.posture or "upright" end,
    linkedColorChoices=function(_rule,_guid,_powered) return nil end,
    canPayDiscard=function(obj) return obj.posture=="discard" end,
    resourceCardsArtifactBroken=function(_guid,_obj) return false end
})
local borrower={guid="borrower",getGMNotes=function() return "" end}
local payment1={guid="payment1",posture="discard",getGMNotes=function() return "" end}
local payment2={guid="payment2",posture="discard",getGMNotes=function() return "" end}
gameCards.borrower={cardType="Advanced Action",resourceKey="borrowedCost"}
gameCards.payment1={cardType="Starting"}
gameCards.payment2={cardType="Starting"}
cardResourceDefinitions.borrowedCost={requiredLink={mode="discard"}}
local footprints={borrower={},payment1={},payment2={}}
local entitlement={borrower={powered=true,count=2,sourceGUID=ancients.guid,borrowed=true}}
local _,_,_,discarded,paid,_,repeats=resolve({borrower,payment1},{},footprints,{borrower=true},{},entitlement)
eq(paid.borrower,false,"One discard cannot pay two borrowed uses")
eq(discarded.borrower,nil,"Borrowed source not thrown away")
eq(repeats.borrower.borrowed,true,"Borrowed repeat preserved")
_,_,_,discarded,paid,_,repeats=resolve({borrower,payment1,payment2},{},footprints,{borrower=true},{},entitlement)
eq(paid.borrower,true,"Two distinct discards pay two uses")
eq(discarded.payment1,"borrower","First cost assigned")
eq(discarded.payment2,"borrower","Second cost assigned")
eq(discarded.borrower,nil,"Paid borrowed source still not thrown away")
print("Borrowed repeat cost regressions passed")
