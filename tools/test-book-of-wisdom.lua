-- Regression: Book of Wisdom reuses the Training offer exchange.
-- Run from the repository root: lua5.2 tools/test-book-of-wisdom.lua
local function eq(actual,expected,label)
    assert(actual==expected,(label or "Mismatch")..": expected "..tostring(expected)..", got "..tostring(actual))
end
local function vec(v) return {v[1],v[2],v[3]} end
local function card(guid,pos)
    local obj={guid=guid,type="Card",resting=true,position=vec(pos),
        rotation={0,180,0},scale={1.5,1,1.5},locked=false}
    local xml={}
    obj.UI={
        getXmlTable=function() return xml end,
        setXmlTable=function(nodes,_assets) xml=nodes end,
        setXml=function(_value) xml={} end,
        getCustomAssets=function() return {} end
    }
    obj.getPosition=function() return vec(obj.position) end
    obj.getRotation=function() return vec(obj.rotation) end
    obj.getScale=function() return vec(obj.scale) end
    obj.setPosition=function(p) obj.position=vec(p) end
    obj.setPositionSmooth=function(p,_collide,_fast) obj.position=vec(p) end
    obj.setRotation=function(p) obj.rotation=vec(p) end
    obj.setRotationSmooth=function(p,_collide,_fast) obj.rotation=vec(p) end
    obj.setScale=function(p) obj.scale=vec(p) end
    obj.isSmoothMoving=function() return false end
    obj.lock=function() obj.locked=true end
    obj.unlock=function() obj.locked=false end
    obj.destruct=function() obj.destroyed=true end
    return obj
end
local book=card("085e60",{0,1,0})
local cost=card("111111",{0,1,0})
local redAA=card("222222",{20,1,20})
local redSpell=card("333333",{25,1,20})
local blueSpell=card("444444",{30,1,20})
local redSpell2=card("555555",{35,1,20})
local cards={book,cost,redAA,redSpell,blueSpell,redSpell2}
local objects={}
for _,obj in ipairs(cards) do objects[obj.guid]=obj end
local broken=false
local crystals=0
local gainedCrystal=0
local refills=0
local bag={getQuantity=function() return -1 end}
objects.bag=bag
objects.hand={getPosition=function() return {0,1,-20} end}
objects.discard={getPosition=function() return {10,1,-20} end}
local function inZone(guid,zone)
    local obj=objects[guid]
    if obj==nil or obj.destroyed or obj.position==nil then return false end
    local z=obj.position[3]
    return (zone=="play" and z==0) or (zone=="offer" and z==20)
        or (zone=="hand" and z==-20 and obj.position[1]==0)
        or (zone=="discard" and z==-20 and obj.position[1]==10)
end
objects.play={getObjects=function()
    local out={}
    for _,obj in ipairs(cards) do if inZone(obj.guid,"play") then out[#out+1]=obj end end
    return out
end}
local env=setmetatable({
    gameCards={
        [book.guid]={cardType="Artifact",resourceKey="artifactBookOfWisdom"},
        [cost.guid]={cardType="Starting",color={"Red"}},
        [redAA.guid]={cardType="Advanced Action",color={"Red"}},
        [redSpell.guid]={cardType="Spell",color={"Red"}},
        [blueSpell.guid]={cardType="Spell",color={"Blue"}},
        [redSpell2.guid]={cardType="Spell",color={"Red"}}
    },
    gStates={firstStarted=true,turnNumber=1,tacticShown=false,tacticRemove=false},
    turnOrder={{seatPos=1,deadDeckInventory={cost.guid}}},
    handZones={"hand"},playerPlayAreas={"play"},deedDeckDiscardZones={"discard"},
    GUID={zone={offer="offer"},bag={mana={red="bag"}}},
    mineCrystalBagKey={Red="red"},
    getObjectFromGUID=function(guid) return objects[guid] end,
    objectGUIDInZone=inZone,
    ttsVectorArray=vec,
    cardEffectIsVertical=function(obj)
        return obj~=nil and not obj.is_face_down and obj.rotation[2]%180==0
    end,
    resourceCardsArtifactBroken=function(_guid,_obj) return broken end,
    resourceCardsTrainingMode=function() error("Book must not read Training mana") end,
    mineCrystalCount=function(_index,_color) return crystals end,
    mineInventoryPosition=function(_index,_color) return {1,2,3} end,
    takeManaCrystal=function(actualBag,params)
        eq(actualBag,bag,"correct crystal colour")
        eq(params.position[3],3,"inventory position")
        gainedCrystal=gainedCrystal+1
    end,
    mainOfferCardsByType=function(kind)
        local out={}
        for _,obj in ipairs(cards) do
            if inZone(obj.guid,"offer") and ((kind=="Spell" and (obj==redSpell or obj==redSpell2 or obj==blueSpell))
                or (kind=="Advanced Action" and obj==redAA)) then out[#out+1]=obj end
        end
        return out
    end,
    legalPlayerCheck=function(_color,_seat,_rule,_quiet) return true end,
    positionToColor=function(_index) return "Red" end,
    safeBroadcastToColor=function(_message,_color,_tint) end,
    safeWaitCondition=function(_owner,callback,condition,_timeout,_fallback)
        if condition() then callback() end
    end,
    safeWaitFrames=function(_owner,callback,_frames) callback() end,
    resourceObjectUiXmlTable=function(ui) return ui.getXmlTable() end,
    resourceObjectUiSetTable=function(ui,nodes,assets) ui.setXmlTable(nodes,assets) end,
    resourceObjectUiRemovePrefixes=function(obj,_prefixes) obj.UI.setXml("") end,
    resourceCardsExistingImageAssetsFor=function(_ui,_images) return {} end,
    createClaimButton=function(guid,_source) return {tag="Button",attributes={id=guid.."offer"}} end,
    callOfferAppendBrowseControls=function(xml,guid,prefix,callback,_claim)
        for _,suffix in ipairs({"previous","next","claim"}) do
            xml[#xml+1]={tag="Button",attributes={id=prefix..guid.."_"..suffix,onClick=callback}}
        end
        return {}
    end,
    animateDeedCardToHand=function(obj,_seat,_delay) obj.setPosition({0,1,-20}) end,
    compactAndRefillDeedOffer=function() refills=refills+1 end,
    mainUIUpdate=function(_reason) end
},{__index=_G})
env.publishPublicUICallbacks=function(callbacks) for name,fn in pairs(callbacks) do env[name]=fn end end
assert(loadfile("src/PlayingGame/Offers/TrainingOffer.lua","t",env))()
local function dropCost()
    env.trainingOfferHandLeft(cost.guid,1)
    env.trainingOfferObjectDropped("Red",cost)
end
local function take(obj) env.trainingOfferClicked({color="Red"},"","TrainingOfferControl_"..obj.guid.."_claim") end
local function preview() return env.gStates.trainingOfferPreview end
-- No hand origin, no exchange.
env.trainingOfferObjectDropped("Red",cost)
eq(preview(),nil,"already-played Action cannot become a free cost")
dropCost()
eq(preview().cardGUID,redAA.guid,"basic Book borrows a matching Advanced Action")
eq(cost.destroyed,nil,"preview does not throw away cost")
eq(env.trainingOfferReservedCard(cost.guid,1),true,"cost is inert")
eq(env.trainingOfferReservedCard(redAA.guid),true,"loan cannot be claimed normally")
take(redAA)
eq(cost.destroyed,true,"confirmed exchange throws away cost")
eq(inZone(redAA.guid,"hand"),true,"basic Book gains to hand")
eq(gainedCrystal,0,"basic Book grants no crystal")
eq(refills,1,"confirmed exchange refills offer")
eq(env.turnOrder[1].deadDeckInventory[1],redAA.guid,"inventory ownership transferred")
cost.destroyed=false
dropCost()
eq(preview(),nil,"same Book cannot exchange twice")
-- Strong side: matching Spell only; changing sides invalidates old selection.
env.trainingOfferClose(true)
cost.position={0,1,0}
cost.destroyed=false
redAA.position={20,1,20}
env.turnOrder[1].deadDeckInventory={cost.guid}
dropCost()
eq(preview().cardGUID,redAA.guid,"basic preview before Throw")
broken=true
env.trainingOfferScheduleCardCheck()
eq(inZone(redAA.guid,"offer"),true,"Throw returns prior AA preview")
eq(preview().cardGUID,redSpell.guid,"Throw switches to Spell offer")
env.trainingOfferClicked({color="Red"},"","TrainingOfferControl_"..redSpell.guid.."_next")
eq(preview().cardGUID,redSpell2.guid,"browse skips non-matching blue Spell")
eq(inZone(redSpell.guid,"offer"),true,"unchosen Spell restored")
take(redSpell2)
eq(inZone(redSpell2.guid,"hand"),true,"strong Book gains Spell to hand")
eq(gainedCrystal,1,"strong Book grants matching crystal once")
eq(env.gStates.trainingOfferClaims[book.guid],1,"claim stored by physical Book")
take(redSpell2)
eq(gainedCrystal,1,"stale Take cannot duplicate crystal")
-- Inventory cap must not prevent the card exchange or add a fourth crystal.
env.trainingOfferClose(true)
cost.destroyed=false
cost.position={0,1,0}
crystals=3
dropCost()
take(redSpell)
eq(inZone(redSpell.guid,"hand"),true,"full inventory still permits Spell gain")
eq(gainedCrystal,1,"full inventory gains no fourth crystal")
-- Cancelled preview keeps cost and returns actual offer card.
env.trainingOfferClose(true)
cost.destroyed=false
cost.position={0,1,0}
redSpell.position={25,1,20}
dropCost()
eq(preview().cardGUID,redSpell.guid,"new turn can browse")
book.rotation={0,90,0}
env.trainingOfferScheduleCardCheck()
eq(preview(),nil,"sideways Book cancels exchange")
eq(cost.destroyed,false,"cancel does not destroy cost")
eq(inZone(redSpell.guid,"offer"),true,"cancel restores offer Spell")
print("Book of Wisdom exchange regressions passed")

-- Borrowed Training still throws only the owned matching hand Action.
env.trainingOfferClose(true)
book.rotation={0,90,0}
cost.destroyed=false
cost.position={0,1,0}
redAA.position={20,1,20}
local borrowedTraining=card("666666",{0,1,0})
cards[#cards+1]=borrowedTraining
objects[borrowedTraining.guid]=borrowedTraining
env.gameCards[borrowedTraining.guid]={cardType="Advanced Action",resourceKey="training",color={"Green"}}
local confirmed=false
env.magicTalentReservedCard=function(guid) return guid==borrowedTraining.guid end
env.magicTalentInactivePreview=function(guid) return guid==borrowedTraining.guid and not confirmed end
env.magicTalentOfferCastSide=function(_seat,guid)
    if guid==borrowedTraining.guid and confirmed then return true end
end
env.resourceCardsTrainingMode=function(_seat,guid)
    return env.magicTalentOfferCastSide(1,guid)==true,1
end
dropCost()
eq(preview(),nil,"Unconfirmed borrowed Training is inert")
confirmed=true
dropCost()
eq(preview().trainingGUID,borrowedTraining.guid,"Confirmed loan is an eligible source")
eq(preview().cardGUID,redAA.guid,"Training borrows matching Action")
local homes=env.trainingOfferLoanHomes()
eq(homes[redAA.guid]~=nil,true,"Pending exchange occupies its logical slot")
homes[redAA.guid].position={25,1,20}
env.trainingOfferSourceReturned(borrowedTraining.guid,true)
eq(preview(),nil,"Returning parent cancels child preview")
eq(cost.destroyed,false,"Cancelled exchange preserves cost")
eq(redAA.position[1],25,"Preview returns to reflowed home")
dropCost()
take(redAA)
eq(cost.destroyed,true,"Confirmed Training throws owned cost")
eq(borrowedTraining.destroyed,nil,"Borrowed Training not destroyed")
eq(inZone(redAA.guid,"hand"),true,"Borrowed stronger side gains to hand")
eq(env.gStates.trainingOfferClaims[borrowedTraining.guid],1,"Completed claim recorded")
env.trainingOfferSourceReturned(borrowedTraining.guid,true)
eq(env.gStates.trainingOfferClaims[borrowedTraining.guid],1,"Parent return does not reset claim")
print("Borrowed Training exchange regressions passed")

-- The existing Training claim counter accepts a second confirmed parent
-- use without returning or consuming the borrowed Training itself.
env.trainingOfferClose(true)
cost.destroyed=false
cost.position={0,1,0}
redAA.position={20,1,20}
local secondCost=card("777777",{0,1,0})
local secondAA=card("888888",{25,1,20})
cards[#cards+1]=secondCost
cards[#cards+1]=secondAA
objects[secondCost.guid]=secondCost
objects[secondAA.guid]=secondAA
env.gameCards[secondCost.guid]={cardType="Starting",color={"Red"}}
env.gameCards[secondAA.guid]={cardType="Advanced Action",color={"Red"}}
env.mainOfferCardsByType=function(kind)
    local out={}
    if kind=="Advanced Action" then
        for _,obj in ipairs({redAA,secondAA}) do
            if inZone(obj.guid,"offer") then out[#out+1]=obj end
        end
    end
    return out
end
local uses=1
env.resourceCardsTrainingMode=function(_seat,_guid) return true,uses end
dropCost()
take(redAA)
eq(env.gStates.trainingOfferClaims[borrowedTraining.guid],1,"First Training application")
env.trainingOfferHandLeft(secondCost.guid,1)
env.trainingOfferObjectDropped("Red",secondCost)
eq(preview(),nil,"Second cost cannot activate before second Wound")
uses=2
env.trainingOfferObjectDropped("Red",secondCost)
eq(preview().cardGUID,secondAA.guid,"Second confirmed use opens exchange")
take(secondAA)
eq(secondCost.destroyed,true,"Second exchange throws a different owned Action")
eq(borrowedTraining.destroyed,nil,"Borrowed Training is not consumed")
eq(env.gStates.trainingOfferClaims[borrowedTraining.guid],2,"Two independent exchanges")
eq(inZone(secondAA.guid,"hand"),true,"Second gained Action enters hand")
print("Repeated borrowed Training exchange regressions passed")
