-- Magic Talent (3d832c): borrow a physical Spell from the offer or gain it.
-- Basic: overlap a coloured hand card with Magic Talent; the cost is discarded,
-- then a matching offer Spell may be cast by paying its normal mana on that Spell.
-- Strong: place the blue (or legal Day gold) power mana AND another coloured mana
-- on Magic Talent. Only then does the matching claim browser appear.
local MAGIC_TALENT_GUID="3d832c"
local CONTROL_PREFIX="MagicTalentControl_"
local CONTROL_PREFIXES={CONTROL_PREFIX,"ResourceCardChoice_","AttackAssignmentSource_"}
local browseSerial=0
local settleSerial=0
local fromHand={}
local returning={}

local function state()
    return gStates~=nil and gStates.magicTalentPreview or nil
end

local function currentSeat()
    local player=gStates~=nil and turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    return player~=nil and player.seatPos or nil
end

local function talentInPlay(seat)
    local card=getObjectFromGUID(MAGIC_TALENT_GUID)
    return seat~=nil and card~=nil and card.is_face_down~=true
        and cardEffectIsVertical(card)
        and objectGUIDInZone(MAGIC_TALENT_GUID,playerPlayAreas[seat])
end

local function cardColor(guid)
    local data=gameCards[guid]
    if data==nil then return nil end
    local color=data.color
    if type(color)=="string" then return color end
    if type(color)=="table" and #color==1 then return color[1] end
    return nil
end

local function matching(guid,color)
    local data=gameCards[guid]
    if data==nil or data.cardType~="Spell" then return false end
    return color=="Gold" or cardColor(guid)==color
end

local function offerOrder(color,previewGUID)
    local order={}
    for _,card in ipairs(mainOfferCardsByType("Spell")) do
        if matching(card.guid,color) then order[#order+1]=card.guid end
    end
    if previewGUID~=nil and matching(previewGUID,color) then
        local found=false
        for _,guid in ipairs(order) do if guid==previewGUID then found=true break end end
        if not found then order[#order+1]=previewGUID end
    end
    return order
end

-- Two different physical mana objects are required. Gold can power the
-- blue Action only while legal and can select any Spell as the extra payment.
local function strongColor(seat)
    if magicTalentManaPayments==nil then return nil end
    local payments=magicTalentManaPayments(seat)
    local goldLegal=resourceCardsGoldAllowed~=nil and resourceCardsGoldAllowed()
    local power=nil
    for _,payment in ipairs(payments) do
        if payment.color=="Blue" then power=payment break end
    end
    if power==nil and goldLegal then
        for _,payment in ipairs(payments) do
            if payment.color=="Gold" then power=payment break end
        end
    end
    if power==nil then return nil end
    for _,payment in ipairs(payments) do
        if payment.guid~=power.guid and
            (payment.color=="Red" or payment.color=="Blue"
            or payment.color=="White" or payment.color=="Green"
            or (payment.color=="Gold" and goldLegal)) then
            return payment.color
        end
    end
    return nil
end

local function clean(card)
    if card~=nil then resourceObjectUiRemovePrefixes(card,CONTROL_PREFIXES) end
end

local function controls(s)
    if state()~=s or s.cardGUID==nil then return end
    local card=getObjectFromGUID(s.cardGUID)
    if card==nil then return end
    local xml=resourceObjectUiXmlTable(card.UI)
    for i=#xml,1,-1 do
        local attr=xml[i].attributes
        if attr~=nil and ((type(attr.id)=="string"
            and attr.id:sub(1,#CONTROL_PREFIX)==CONTROL_PREFIX)
            or attr.onClick=="global/processCardClaim") then
            table.remove(xml,i)
        end
    end
    local images=callOfferAppendBrowseControls(xml,card.guid,CONTROL_PREFIX,
        "magicTalentClicked",s.mode=="strong")
    resourceObjectUiSetTable(card.UI,xml,
        resourceCardsExistingImageAssetsFor(card.UI,images))
end

function magicTalentEnsureControls(seat)
    local s=state()
    if s==nil or s.cardGUID==nil or (seat~=nil and s.seatPos~=seat) then return end
    local card=getObjectFromGUID(s.cardGUID)
    if card==nil then return end
    local previous,nextArrow,take=false,false,false
    for _,node in ipairs(resourceObjectUiXmlTable(card.UI)) do
        local id=node.attributes~=nil and node.attributes.id or nil
        if id==CONTROL_PREFIX..card.guid.."_previous" then previous=true
        elseif id==CONTROL_PREFIX..card.guid.."_next" then nextArrow=true
        elseif id==CONTROL_PREFIX..card.guid.."_claim" then take=true end
    end
    if not previous or not nextArrow or (s.mode=="strong" and not take) then controls(s) end
end

-- The offer card keeps its GUID and is never cloned. Retire the calculator
-- source BEFORE the card is returned; delayed scans must not recreate targets.
local function returnPreview(s,immediate)
    if s==nil or s.cardGUID==nil then return end
    browseSerial=browseSerial+1
    local guid,home=s.cardGUID,s.home
    s.cardGUID,s.home=nil,nil
    returning[guid]=true
    if guid=="2eb8e8" and callOfferClose~=nil then callOfferClose(immediate) end
    if combatForgetPhysicalSourceTargets~=nil then combatForgetPhysicalSourceTargets(guid) end
    if attackAssignmentsClearForObject~=nil then attackAssignmentsClearForObject(guid) end
    local card=getObjectFromGUID(guid)
    clean(card)
    if card==nil or home==nil then returning[guid]=nil return end
    if playAreaScaleForgetObject~=nil then playAreaScaleForgetObject(card) end
    card.unlock()
    card.setScale(home.scale)
    if immediate then
        card.setRotation(home.rotation)
        card.setPosition(home.position)
    else
        card.setRotationSmooth(home.rotation,false,false)
        card.setPositionSmooth(home.position,false,false)
    end
    safeWaitCondition("Offers.MagicTalent",function()
        local live=getObjectFromGUID(guid)
        if live~=nil and objectGUIDInZone(guid,GUID.zone.offer) then
            live.lock()
            if gStates.tacticShown==false and gStates.tacticRemove==false then
                live.UI.setXmlTable({createClaimButton(guid,"offer")})
            end
        end
        returning[guid]=nil
    end,function()
        local live=getObjectFromGUID(guid)
        return live==nil or (live.resting and not live.isSmoothMoving())
    end,8,function() returning[guid]=nil end)
    if resourceCardsSourceChanged~=nil then resourceCardsSourceChanged() end
end

function magicTalentClose(immediate)
    settleSerial=settleSerial+1
    local s=state()
    if s~=nil then returnPreview(s,immediate==true) end
    if gStates~=nil then gStates.magicTalentPreview=nil end
    fromHand={}
    if immediate==true then returning={} end
end

-- Do not allow the ordinary Offer claim path to consume a temporary preview.
function magicTalentReservedCard(guid)
    local s=state()
    return returning[guid]==true or (s~=nil and s.cardGUID==guid)
end

-- Time Bending borrowed through Magic Talent must set aside Magic Talent,
-- not the Spell owned by the public offer. The normal extra-turn check still
-- validates the real blue + black casting mana on the loaned Spell.
function magicTalentBorrowedTimeBendingPaid(seat)
    local s=state()
    if s==nil or s.mode~="basic" or s.seatPos~=seat
        or s.cardGUID~=GUID.card.timeBending then return false end
    local spell=getObjectFromGUID(s.cardGUID)
    return spell~=nil and resourceCardsTimeBendingPaid(seat,spell)==true
end

local function borrow(s,index)
    local guid=s.order[index]
    local card=guid~=nil and getObjectFromGUID(guid) or nil
    local talent=getObjectFromGUID(MAGIC_TALENT_GUID)
    if card==nil or talent==nil or not objectGUIDInZone(guid,GUID.zone.offer) then return false end
    s.index=index
    s.cardGUID=guid
    s.home={position=ttsVectorArray(card.getPosition()),
        rotation=ttsVectorArray(card.getRotation()),scale=ttsVectorArray(card.getScale())}
    local pos=ttsVectorArray(talent.getPosition())
    local display=s.display or {position={pos[1]+3.0,math.max(1.8,pos[2]+0.35),pos[3]},
        rotation={0,180,0}}
    browseSerial=browseSerial+1
    local serial=browseSerial
    card.unlock()
    card.setScale({1.5,1,1.5})
    card.setPositionSmooth(display.position,false,false)
    card.setRotationSmooth(display.rotation,false,false)
    controls(s)
    local function settled()
        if state()~=s or s.cardGUID~=guid or serial~=browseSerial then return end
        magicTalentEnsureControls(s.seatPos)
        if resourceCardsSourceChanged~=nil then resourceCardsSourceChanged() end
    end
    safeWaitCondition("Offers.MagicTalent",settled,function()
        local live=getObjectFromGUID(guid)
        return live==nil or (live.resting and not live.isSmoothMoving())
    end,8,settled)
    if resourceCardsSourceChanged~=nil then resourceCardsSourceChanged() end
    return true
end

local function remember(s)
    local card=s.cardGUID~=nil and getObjectFromGUID(s.cardGUID) or nil
    if card~=nil then
        s.display={position=ttsVectorArray(card.getPosition()),
            rotation=ttsVectorArray(card.getRotation())}
    end
end

local function paymentStillOnSpell(s)
    -- Browser selection is not casting. The usual paid Spell record is the
    -- sole authority; this works for normal, powered and utility Spells.
    local scan=resourceCardScanBySeat~=nil and resourceCardScanBySeat[s.seatPos] or nil
    local record=scan~=nil and scan.cards~=nil and scan.cards[s.cardGUID] or nil
    return (record~=nil and record.spellCastPaid==true)
        or (magicTalentSpellCastingPaid~=nil
            and magicTalentSpellCastingPaid(s.seatPos,s.cardGUID)==true)
end

local function cycle(s,delta)
    if s.mode=="basic" and paymentStillOnSpell(s) then
        safeBroadcastToColor("Magic Talent: remove the casting mana before changing Spells.",
            positionToColor(gStates.turnNumber),warningColor)
        return
    end
    local count=#s.order
    for step=1,count do
        local index=((s.index-1+step*delta)%count)+1
        local guid=s.order[index]
        if guid~=s.cardGUID and (objectGUIDInZone(guid,GUID.zone.offer)
            or returning[guid]==true) then
            -- A returning card must settle back in its offer slot first.
            if returning[guid] then return end
            remember(s)
            returnPreview(s,false)
            borrow(s,index)
            return
        end
    end
end

local function claim(s)
    if state()~=s or s.mode~="strong" or not talentInPlay(s.seatPos)
        or strongColor(s.seatPos)~=s.color then return end
    local gained=s.cardGUID~=nil and getObjectFromGUID(s.cardGUID) or nil
    local destination=getObjectFromGUID(deedDeckDiscardZones[s.seatPos])
    if gained==nil or destination==nil or not matching(gained.guid,s.color) then return end
    browseSerial=browseSerial+1
    local gainedGUID=gained.guid
    s.cardGUID,s.home=nil,nil
    s.mode="claimed"  -- A paid claim cannot restart on the next mana refresh.
    clean(gained)
    gained.UI.setXml("")
    for _,player in ipairs(turnOrder) do
        if player.seatPos==s.seatPos then
            local inventory=player.deadDeckInventory or {}
            for i=#inventory,1,-1 do
                if inventory[i]==gainedGUID then table.remove(inventory,i) end
            end
            inventory[#inventory+1]=gainedGUID
            player.deadDeckInventory=inventory
            break
        end
    end
    gained.unlock()
    if playAreaScaleForgetObject~=nil then playAreaScaleForgetObject(gained) end
    local p=ttsVectorArray(destination.getPosition())
    gained.setScale({1.5,1,1.5})
    gained.setPositionSmooth({p[1],math.max(1.8,p[2]+0.5),p[3]},false,false)
    gained.setRotationSmooth({0,180,0},false,false)
    safeWaitCondition("Offers.MagicTalent",function()
        if not objectGUIDInZone(gainedGUID,GUID.zone.offer) then
            compactAndRefillDeedOffer()
            scheduleDeedPileDescriptionRefresh(s.seatPos,"discard")
        end
    end,function()
        return not objectGUIDInZone(gainedGUID,GUID.zone.offer)
    end,8)
    if resourceCardsSourceChanged~=nil then resourceCardsSourceChanged() end
end

publishPublicUICallbacks({
    magicTalentClicked=function(player,value,id)
        local s=state()
        if s==nil or s.cardGUID==nil or type(id)~="string"
            or legalPlayerCheck(player.color,s.seatPos,"NoDummyException")~=true then return end
        local guid,action=id:match("^MagicTalentControl_([0-9a-f]+)_(previous)$")
        if guid==nil then guid,action=id:match("^MagicTalentControl_([0-9a-f]+)_(next)$") end
        if guid==nil then guid,action=id:match("^MagicTalentControl_([0-9a-f]+)_(claim)$") end
        if guid~=s.cardGUID then return end
        if action=="claim" then claim(s)
        else cycle(s,action=="previous" and -1 or 1) end
    end
})

function magicTalentHandLeft(guid,seat)
    if guid~=nil and seat~=nil then fromHand[guid]=seat end
end

function magicTalentCardPickedUp(playerColor,obj)
    local seat=currentSeat()
    if obj==nil or seat==nil or obj.type~="Card"
        or not objectGUIDInZone(obj.guid,handZones[seat]) then return end
    if legalPlayerCheck(playerColor,seat,"NoDummyException",true)==true then
        fromHand[obj.guid]=seat
    end
end

local function candidateCost(seat)
    local talent=getObjectFromGUID(MAGIC_TALENT_GUID)
    local zone=getObjectFromGUID(playerPlayAreas[seat])
    if talent==nil or zone==nil then return nil,nil end
    local t=ttsVectorArray(talent.getPosition())
    for _,card in ipairs(zone.getObjects()) do
        local color=cardColor(card.guid)
        local data=gameCards[card.guid]
        if card.type=="Card" and card.guid~=MAGIC_TALENT_GUID
            and fromHand[card.guid]==seat and color~=nil
            and data~=nil and data.cardType~="Artifact"
            and data.cardType~="Wound" and card.resting==true then
            local p=ttsVectorArray(card.getPosition())
            if math.abs(t[1]-p[1])<1.4 and math.abs(t[3]-p[3])<1.8 then
                return card,color
            end
        end
    end
    return nil,nil
end

local function discardCost(seat,card)
    local zone=getObjectFromGUID(deedDeckDiscardZones[seat])
    if zone==nil then return false end
    fromHand[card.guid]=nil
    card.unlock()
    if playAreaScaleForgetObject~=nil then playAreaScaleForgetObject(card) end
    local p=ttsVectorArray(zone.getPosition())
    card.setPositionSmooth({p[1],math.max(1.8,p[2]+0.5),p[3]},false,false)
    card.setRotationSmooth({0,180,0},false,false)
    safeWaitFrames("Offers.MagicTalent",function()
        scheduleDeedPileDescriptionRefresh(seat,"discard")
    end,6)
    return true
end

local function start(seat,mode,color,source)
    local order=offerOrder(color)
    local s={seatPos=seat,mode=mode,color=color,order=order,index=1,
        sourceGUID=source~=nil and source.guid or nil}
    if source~=nil and not discardCost(seat,source) then return end
    gStates.magicTalentPreview=s
    if #order>0 then borrow(s,1) end
    if #order==0 then
        safeBroadcastToColor("Magic Talent: no matching Spell is in the offer.",
            positionToColor(gStates.turnNumber),warningColor)
    end
end

function magicTalentSync()
    if gStates==nil or gStates.firstStarted~=true then return end
    local s=state()
    local seat=currentSeat()
    if seat==nil or not talentInPlay(seat) or (s~=nil and s.seatPos~=seat) then
        if s~=nil then magicTalentClose(true) end
        return
    end
    if s==nil then
        local cost,color=candidateCost(seat)
        -- A coloured hand card on Magic Talent selects the basic effect;
        -- without it two distinct mana payments select the strong effect.
        if cost~=nil then start(seat,"basic",color,cost)
        else
            local paid=strongColor(seat)
            if paid~=nil then start(seat,"strong",paid,nil) end
        end
        return
    end
    if s.mode=="basic" then
        if s.cardGUID==nil then
            s.order=offerOrder(s.color)
            s.index=1
            if #s.order>0 then borrow(s,1) end
        end
        return
    end
    if s.mode~="strong" then return end
    local paid=strongColor(seat)
    if paid==nil then
        if s.cardGUID~=nil then returnPreview(s,false) end
        return
    end
    if paid~=s.color then
        if s.cardGUID~=nil then returnPreview(s,false) end
        s.color=paid
        s.order=offerOrder(paid)
        s.index=1
    end
    if s.cardGUID==nil then
        s.order=offerOrder(s.color)
        s.index=1
        if #s.order>0 then borrow(s,1) end
    end
end

-- Return the real Spell before the offer's grid counts/moves its cards.
-- The saved basic/strong entitlement survives this temporary reflow.
function magicTalentOfferWillChange()
    local s=state()
    if s~=nil and s.cardGUID~=nil then returnPreview(s,true) end
end

function magicTalentScheduleCheck(movedGUID)
    settleSerial=settleSerial+1
    local serial=settleSerial
    safeWaitFrames("Offers.MagicTalent",function()
        if serial~=settleSerial then return end
        safeWaitCondition("Offers.MagicTalent",function()
            if serial==settleSerial then magicTalentSync() end
        end,function()
            if serial~=settleSerial then return true end
            local card=getObjectFromGUID(MAGIC_TALENT_GUID)
            local moved=movedGUID~=nil and getObjectFromGUID(movedGUID) or nil
            local ready=card==nil or (card.held_by_color==nil
                and card.resting and not card.isSmoothMoving())
            return ready and (moved==nil or (moved.held_by_color==nil
                and moved.resting and not moved.isSmoothMoving()))
        end,8)
    end,2)
end

function magicTalentObjectDropped(playerColor,obj)
    if obj==nil then return end
    local s=state()
    if s~=nil and obj.guid==s.cardGUID then
        local card=getObjectFromGUID(obj.guid)
        if card~=nil then
            remember(s)
            if s.mode=="strong" and objectGUIDInZone(obj.guid,deedDeckDiscardZones[s.seatPos]) then
                claim(s)
                return
            end
        end
    end
    -- Ignore unrelated table drops; the live Magic Talent/loan is all that matters.
    if s~=nil or talentInPlay(currentSeat()) then magicTalentScheduleCheck(obj.guid) end
end

function magicTalentRestoreOnLoad()
    local s=state()
    if s==nil then return end
    if not talentInPlay(s.seatPos) then magicTalentClose(true) return end
    if s.cardGUID~=nil then
        local card=getObjectFromGUID(s.cardGUID)
        if card==nil then magicTalentClose(true) return end
        browseSerial=browseSerial+1
        controls(s)
    end
    magicTalentScheduleCheck()
end
