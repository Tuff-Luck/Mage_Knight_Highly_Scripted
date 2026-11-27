-- Training and Book of Wisdom: physical matching-colour deed exchanges.
-- Both keep the hand cost and real Offer preview inert until Take commits.
-- Training basic gains to discard; its stronger side and both Book sides
-- gain to hand. The broken Book exchanges for a Spell and a crystal.
local function isBook(guid)
    local data=gameCards[guid]
    return data~=nil and data.resourceKey=="artifactBookOfWisdom"
end
local function isTraining(guid)
    local data=gameCards[guid]
    return data~=nil and data.resourceKey=="training"
end
local function isExchange(guid)
    return isTraining(guid) or isBook(guid)
end
local function exchangeName(guid)
    return isBook(guid) and "Book of Wisdom" or "Training"
end
local function exchangeMode(seatPos,guid)
    if isBook(guid) then
        local broken=resourceCardsArtifactBroken(guid,getObjectFromGUID(guid))
        return broken,1,broken and "Spell" or "Advanced Action",true
    end
    local powered,uses=resourceCardsTrainingMode(seatPos,guid)
    return powered,uses,"Advanced Action",powered
end
local browseSerial=0
local trainingMoveSerial=0
-- Transient origin evidence: a Training cost must actually leave this
-- player's hand, not be an already-played Action recycled from the table.
local fromHand={}
local returningPreview={}

local function currentState()
    return gStates~=nil and gStates.trainingOfferPreview or nil
end

function trainingOfferHandLeft(guid,seatPos)
    if guid~=nil and seatPos~=nil then fromHand[guid]=seatPos end
end

local function currentSeat()
    local player=gStates~=nil and turnOrder~=nil
        and turnOrder[gStates.turnNumber] or nil
    return player~=nil and player.seatPos or nil
end

function trainingOfferCardPickedUp(playerColor,obj)
    local seatPos=currentSeat()
    -- Track hand origin even before Training is played, but never warn on a pickup.
    if obj==nil or seatPos==nil or obj.type~="Card"
        or not objectGUIDInZone(obj.guid,handZones[seatPos]) then return end
    if legalPlayerCheck(playerColor,seatPos,"NoDummyException",true)==true then
        fromHand[obj.guid]=seatPos
    end
end

local TRAINING_OFFER_CONTROL_PREFIXES={"TrainingOfferControl_","ResourceCardChoice_","AttackAssignmentSource_"}
local function cleanPreview(card)
    if card~=nil then resourceObjectUiRemovePrefixes(card,TRAINING_OFFER_CONTROL_PREFIXES) end
end

local function showControls(state)
    if currentState()~=state or state.cardGUID==nil then return end
    local card=getObjectFromGUID(state.cardGUID)
    if card==nil then return end
    local xml=resourceObjectUiXmlTable(card.UI)
    for i=#xml,1,-1 do
        local attr=xml[i].attributes
        -- A loan must not retain its ordinary Offer CLAIM button: it
        -- bypasses Training's matching-colour cost and claim destination.
        if attr~=nil and ((type(attr.id)=="string"
            and attr.id:sub(1,21)=="TrainingOfferControl_")
            or attr.onClick=="global/processCardClaim") then
            table.remove(xml,i)
        end
    end
    local images=callOfferAppendBrowseControls(xml,card.guid,
        "TrainingOfferControl_","trainingOfferClicked",true)
    resourceObjectUiSetTable(card.UI,xml,
        resourceCardsExistingImageAssetsFor(card.UI,images))
end

function trainingOfferEnsureControls()
    local state=currentState()
    if state==nil or state.cardGUID==nil then return end
    local card=getObjectFromGUID(state.cardGUID)
    if card==nil then return end
    local prev,nextArrow,take=false,false,false
    for _,node in ipairs(resourceObjectUiXmlTable(card.UI)) do
        local id=node.attributes~=nil and node.attributes.id or nil
        if id=="TrainingOfferControl_"..card.guid.."_previous" then prev=true
        elseif id=="TrainingOfferControl_"..card.guid.."_next" then nextArrow=true
        elseif id=="TrainingOfferControl_"..card.guid.."_claim" then take=true end
    end
    if not prev or not nextArrow or not take then showControls(state) end
end

local function returnPreview(state,immediate)
    if state==nil or state.cardGUID==nil then return end
    local guid,home=state.cardGUID,state.home
    state.cardGUID,state.home=nil,nil
    returningPreview[guid]=true
    local card=getObjectFromGUID(guid)
    cleanPreview(card)
    if card~=nil and home~=nil then
        if playAreaScaleForgetObject~=nil then playAreaScaleForgetObject(card) end
        card.unlock()
        card.setScale(home.scale)
        if immediate then
            card.setPosition(home.position)
            card.setRotation(home.rotation)
        else
            card.setPositionSmooth(home.position,false,false)
            card.setRotationSmooth(home.rotation,false,false)
        end
        safeWaitCondition("Offers.Training",function()
            local live=getObjectFromGUID(guid)
            if live~=nil and objectGUIDInZone(guid,GUID.zone.offer) then
                live.lock()
                -- Restore the ordinary Offer control after the temporary
                -- Training browser controls have been removed.
                if gStates.tacticShown==false and gStates.tacticRemove==false then
                    live.UI.setXmlTable({createClaimButton(guid,"offer")})
                end
            end
            returningPreview[guid]=nil
        end,function()
            local live=getObjectFromGUID(guid)
            return live==nil or (live.resting and not live.isSmoothMoving())
        end,8)
    else
        returningPreview[guid]=nil
    end
    if resourceCardsSourceChanged~=nil then resourceCardsSourceChanged() end
end

local function closeExchange(state,immediate)
    if currentState()~=state then return end
    browseSerial=browseSerial+1
    gStates.trainingOfferPreview=nil
    returnPreview(state,immediate==true)
end

-- An outstanding exchange preview belongs to its source. Returning a
-- borrowed Training must cancel only that preview, not completed claims.
function trainingOfferSourceReturned(guid,immediate)
    local state=currentState()
    if state~=nil and state.trainingGUID==guid then closeExchange(state,immediate) end
end

-- The preview still occupies its logical offer slot until Take commits.
function trainingOfferLoanHomes()
    local state=currentState()
    if state~=nil and state.cardGUID~=nil and state.home~=nil then
        return {[state.cardGUID]=state.home}
    end
    return {}
end

function trainingOfferClose(immediate)
    local state=currentState()
    if state~=nil then closeExchange(state,immediate) end
    if immediate==true and gStates~=nil then
        gStates.trainingOfferClaims=nil
        fromHand={}
        returningPreview={}
    end
end

function trainingOfferReservedCard(guid,seatPos)
    local state=currentState()
    return returningPreview[guid]==true
        or state~=nil and (seatPos==nil or state.seatPos==seatPos)
            and (state.cardGUID==guid or (seatPos~=nil and state.sourceGUID==guid))
end

local function matchesSource(sourceData,offerData,offerType)
    if sourceData==nil or offerData==nil
        or offerData.cardType~=(offerType or "Advanced Action") then return nil end
    for _,color in ipairs(sourceData.color or {}) do
        for _,other in ipairs(offerData.color or {}) do
            if color==other then return color end
        end
    end
    return nil
end

local function offerAvailable(guid)
    return not returningPreview[guid]
        and (magicTalentReservedCard==nil or not magicTalentReservedCard(guid))
end

local function borrow(state,index)
    local guid=state.order[index]
    local card=guid~=nil and getObjectFromGUID(guid) or nil
    local training=getObjectFromGUID(state.trainingGUID)
    if card==nil or training==nil or not offerAvailable(guid)
        or not objectGUIDInZone(guid,GUID.zone.offer) then return false end
    state.index=index
    state.cardGUID=guid
    state.home={position=ttsVectorArray(card.getPosition()),
        rotation=ttsVectorArray(card.getRotation()),scale=ttsVectorArray(card.getScale())}
    local position=state.display
    if position==nil then
        local p=ttsVectorArray(training.getPosition())
        position={p[1]+3.9,math.max(1.8,p[2]+0.35),p[3]}
    end
    browseSerial=browseSerial+1
    local serial=browseSerial
    card.unlock()
    card.setScale({1.5,1,1.5})
    card.setPositionSmooth(position,false,false)
    card.setRotationSmooth(state.rotation or {0,180,0},false,false)
    showControls(state)
    local function refresh()
        if currentState()~=state or state.cardGUID~=guid
            or browseSerial~=serial then return end
        trainingOfferEnsureControls()
        if resourceCardsSourceChanged~=nil then resourceCardsSourceChanged() end
    end
    safeWaitCondition("Offers.Training",refresh,function()
        local live=getObjectFromGUID(guid)
        return live==nil or (live.resting and not live.isSmoothMoving())
    end,8,refresh)
    if resourceCardsSourceChanged~=nil then resourceCardsSourceChanged() end
    return true
end

local function cycle(state,delta)
    local present={}
    local sourceData=gameCards[state.sourceGUID]
    local positions={}
    local order={}
    for _,card in ipairs(mainOfferCardsByType(state.offerType or "Advanced Action")) do
        if card.guid~=state.cardGUID and offerAvailable(card.guid)
            and matchesSource(sourceData,gameCards[card.guid],state.offerType) then
            present[card.guid]=true
            positions[card.guid]=ttsVectorArray(card.getPosition())[1]
            order[#order+1]=card.guid
        end
    end
    if state.cardGUID~=nil and state.home~=nil then
        present[state.cardGUID]=true
        positions[state.cardGUID]=state.home.position[1]
        order[#order+1]=state.cardGUID
    else return end
    table.sort(order,function(a,b)
        if positions[a]==positions[b] then return a<b end
        return positions[a]<positions[b]
    end)
    state.order=order
    local oldIndex=1
    for i,guid in ipairs(order) do if guid==state.cardGUID then oldIndex=i break end end
    local count=#order
    for step=1,count do
        local index=((oldIndex-1+step*delta)%count)+1
        local guid=state.order[index]
        if present[guid] and guid~=state.cardGUID then
            local current=getObjectFromGUID(state.cardGUID)
            if current~=nil then
                state.display=ttsVectorArray(current.getPosition())
                state.rotation=ttsVectorArray(current.getRotation())
            end
            returnPreview(state,false)
            borrow(state,index)
            return
        end
    end
end

local function trainingValid(seatPos,trainingGUID)
    local card=trainingGUID~=nil and getObjectFromGUID(trainingGUID) or nil
    if card==nil or not isExchange(trainingGUID) or seatPos==nil
        or (magicTalentInactivePreview~=nil and magicTalentInactivePreview(trainingGUID))
        or not objectGUIDInZone(trainingGUID,playerPlayAreas[seatPos]) then return false end
    if magicTalentReservedCard~=nil and magicTalentReservedCard(trainingGUID) then
        -- Only the confirmed borrowed stronger Training is an exchange
        -- source. A pending or returning Action must never destroy a cost.
        return isTraining(trainingGUID) and magicTalentOfferCastSide~=nil
            and magicTalentOfferCastSide(seatPos,trainingGUID)==true
            and card.is_face_down~=true and cardEffectIsVertical(card)
    end
    if isBook(trainingGUID) then return cardEffectIsVertical(card) end
    -- A sideways Training is only the generic +1 Action, not its printed
    -- replacement effect. A face-down copy is valid only when Maximal Effect
    -- is explicitly repeating that card.
    if card.is_face_down==true or not cardEffectIsVertical(card) then
        local _,repeats=resourceCardsTrainingMode(seatPos,trainingGUID)
        if repeats<2 then return false end
    end
    return true
end

local function trainingCandidates(seatPos)
    local candidates={}
    local zone=seatPos~=nil and getObjectFromGUID(playerPlayAreas[seatPos]) or nil
    for _,card in ipairs(zone~=nil and zone.getObjects() or {}) do
        if isExchange(card.guid) then candidates[#candidates+1]=card end
    end
    return candidates
end

local function startTraining(seatPos,source)
    if currentState()~=nil or currentSeat()~=seatPos then return end
    local details=gameCards[source.guid]
    if details==nil or (details.cardType~="Starting"
        and details.cardType~="Advanced Action")
        or fromHand[source.guid]~=seatPos
        or (magicTalentReservedCard~=nil and magicTalentReservedCard(source.guid))
        or not objectGUIDInZone(source.guid,playerPlayAreas[seatPos]) then return end
    local from=ttsVectorArray(source.getPosition())
    gStates.trainingOfferClaims=gStates.trainingOfferClaims or {}
    local training,nearest
    for _,candidate in ipairs(trainingCandidates(seatPos)) do
        if candidate.guid~=source.guid and trainingValid(seatPos,candidate.guid) then
            local _,uses=exchangeMode(seatPos,candidate.guid)
            local at=ttsVectorArray(candidate.getPosition())
            local dx,dz=math.abs(at[1]-from[1]),math.abs(at[3]-from[3])
            local distance=dx*dx+dz*dz
            if dx<=1.4 and dz<=1.8 and (gStates.trainingOfferClaims[candidate.guid] or 0)<uses
                and (nearest==nil or distance<nearest
                    or (distance==nearest and candidate.guid<training.guid)) then
                training,nearest=candidate,distance
            end
        end
    end
    if training==nil then return end
    local trainingGUID=training.guid
    local _,_,offerType=exchangeMode(seatPos,trainingGUID)
    local order={}
    for _,offer in ipairs(mainOfferCardsByType(offerType)) do
        if offerAvailable(offer.guid) and matchesSource(details,gameCards[offer.guid],offerType) then
            order[#order+1]=offer.guid
        end
    end
    if #order==0 then
        safeBroadcastToColor(exchangeName(trainingGUID)..": no matching "..offerType.." is in the offer.",
            positionToColor(gStates.turnNumber),warningColor)
        return
    end
    fromHand[source.guid]=nil
    local state={seatPos=seatPos,sourceGUID=source.guid,
        order=order,index=1,trainingGUID=trainingGUID,offerType=offerType}
    gStates.trainingOfferPreview=state
    if not borrow(state,1) then
        fromHand[source.guid]=seatPos
        gStates.trainingOfferPreview=nil
    end
end

-- A Book's bonus is the acquired Spell's colour. Reuse the same inventory
-- count, placement and crystal draw helpers as the existing mine reward.
local function bookCrystal(seatPos,color)
    local index=gStates.turnNumber
    local player=turnOrder[index]
    if player==nil or player.seatPos~=seatPos or mineCrystalCount(index,color)>=3 then return end
    local key=mineCrystalBagKey[color]
    local bag=key~=nil and getObjectFromGUID(GUID.bag.mana[key]) or nil
    if bag==nil or bag.getQuantity()==0 then
        safeBroadcastToColor("Book of Wisdom: collect the "..color.." crystal manually.",
            positionToColor(index),warningColor)
        return
    end
    takeManaCrystal(bag,{position=mineInventoryPosition(index,color),smooth=false})
end

local function claim(state)
    if currentState()~=state or currentSeat()~=state.seatPos
        or not trainingValid(state.seatPos,state.trainingGUID) then return end
    local gained=getObjectFromGUID(state.cardGUID)
    local source=getObjectFromGUID(state.sourceGUID)
    if source~=nil and magicTalentReservedCard~=nil and magicTalentReservedCard(source.guid) then return end
    local powered,repeatCount,offerType,toHand=exchangeMode(state.seatPos,state.trainingGUID)
    if offerType~=(state.offerType or "Advanced Action") then return end
    local color=source~=nil and gained~=nil
        and matchesSource(gameCards[source.guid],gameCards[gained.guid],offerType) or nil
    if color==nil or not objectGUIDInZone(source.guid,playerPlayAreas[state.seatPos]) then return end
    if ((gStates.trainingOfferClaims or {})[state.trainingGUID] or 0)>=repeatCount then return end
    local destination=getObjectFromGUID(toHand
        and handZones[state.seatPos] or deedDeckDiscardZones[state.seatPos])
    if destination==nil then return end
    browseSerial=browseSerial+1
    local gainedGUID=gained.guid
    -- Retire the loan before the real offer is compacted, so there is no
    -- second copy to restore and no opportunity for a duplicate claim.
    state.cardGUID=nil
    state.home=nil
    gStates.trainingOfferPreview=nil
    local claims=gStates.trainingOfferClaims or {}
    claims[state.trainingGUID]=(claims[state.trainingGUID] or 0)+1
    gStates.trainingOfferClaims=claims
    cleanPreview(gained)
    gained.UI.setXml("")
    -- Replace the original hand card in the owning deed inventory. The new
    -- Advanced Action belongs to this player even on the basic discard side.
    for _,player in ipairs(turnOrder) do
        if player.seatPos==state.seatPos then
            local owned=player.deadDeckInventory or {}
            for i=#owned,1,-1 do
                if owned[i]==source.guid or owned[i]==gainedGUID then
                    table.remove(owned,i)
                end
            end
            owned[#owned+1]=gainedGUID
            player.deadDeckInventory=owned
            break
        end
    end
    source.destruct() -- Both exchanges throw away the hand Action.
    gained.unlock()
    if playAreaScaleForgetObject~=nil then playAreaScaleForgetObject(gained) end
    if toHand then
        animateDeedCardToHand(gained,state.seatPos,0)
    else
        local p=ttsVectorArray(destination.getPosition())
        gained.setScale({1.5,1,1.5})
        gained.setPositionSmooth({p[1],math.max(1.8,p[2]+0.5),p[3]},false,false)
        gained.setRotationSmooth({0,180,0},false,false)
        safeWaitFrames("Offers.Training",function()
            scheduleDeedPileDescriptionRefresh(state.seatPos,"discard")
        end,5)
    end
    if isBook(state.trainingGUID) and powered then bookCrystal(state.seatPos,color) end
    -- Offer compaction must happen *after* the claimed card has crossed
    -- the offer boundary; otherwise it still occupies its old slot.
    local function refill()
        if not objectGUIDInZone(gainedGUID,GUID.zone.offer) then compactAndRefillDeedOffer() end
    end
    safeWaitCondition("Offers.Training",refill,function()
        return not objectGUIDInZone(gainedGUID,GUID.zone.offer)
    end,8,refill)
    if resourceCardsSourceChanged~=nil then resourceCardsSourceChanged() end
    mainUIUpdate(exchangeName(state.trainingGUID).." "..offerType.." Claimed")
    if claims[state.trainingGUID]<repeatCount then
        safeBroadcastToColor("Training: choose another Action from your hand for the next use.",
            positionToColor(gStates.turnNumber),warningColor)
    end
end

publishPublicUICallbacks({
    trainingOfferClicked=function(player,value,id)
        local state=currentState()
        if state==nil or type(id)~="string"
            or legalPlayerCheck(player.color,state.seatPos,"NoDummyException")~=true then return end
        local guid,action=id:match("^TrainingOfferControl_([0-9a-f]+)_(previous)$")
        if guid==nil then guid,action=id:match("^TrainingOfferControl_([0-9a-f]+)_(next)$") end
        if guid==nil then guid,action=id:match("^TrainingOfferControl_([0-9a-f]+)_(claim)$") end
        if guid~=state.cardGUID then return end
        if action=="claim" then claim(state)
        else cycle(state,action=="previous" and -1 or 1) end
    end
})

function trainingOfferObjectDropped(playerColor,obj)
    if obj==nil or gStates==nil or gStates.firstStarted~=true then return end
    local seatPos=currentSeat()
    if seatPos==nil then return end
    local active=currentState()
    if isExchange(obj.guid) then
        trainingOfferScheduleCardCheck()
        -- A different Training copy can itself be a legitimate hand cost.
    end
    if active~=nil and obj.guid==active.cardGUID then
        local guid=obj.guid
        safeWaitCondition("Offers.Training",function()
            local state=currentState()
            if state~=active or state.cardGUID~=guid then return end
            local held=getObjectFromGUID(guid)
            if held==nil then return end
            state.display=ttsVectorArray(held.getPosition())
            state.rotation=ttsVectorArray(held.getRotation())
            local _,_,_,toHand=exchangeMode(state.seatPos,state.trainingGUID)
            if objectGUIDInZone(guid,toHand and handZones[state.seatPos]
                or deedDeckDiscardZones[state.seatPos]) then
                claim(state)
            else trainingOfferEnsureControls() end
        end,function()
            local live=getObjectFromGUID(guid)
            return live==nil or (live.resting and not live.isSmoothMoving())
        end,8)
        return
    end
    if active~=nil and obj.guid==active.sourceGUID then
        if not objectGUIDInZone(obj.guid,playerPlayAreas[active.seatPos]) then
            trainingOfferClose(false)
        end
        return
    end
    if active~=nil or gameCards[obj.guid]==nil then return end
    local cardData=gameCards[obj.guid]
    if cardData.cardType~="Starting" and cardData.cardType~="Advanced Action" then return end
    -- Other players may plan cards during a Proxy/Dummy turn; no Training action
    -- exists unless the card is actually in the current seat's play area.
    if #trainingCandidates(seatPos)==0 then return end
    if legalPlayerCheck(playerColor,seatPos,"NoDummyException",true)~=true then return end
    local guid=obj.guid
    safeWaitCondition("Offers.Training",function()
        local live=getObjectFromGUID(guid)
        if live~=nil then startTraining(seatPos,live) end
    end,function()
        local live=getObjectFromGUID(guid)
        return live==nil or (live.resting and not live.isSmoothMoving())
    end,8)
end

function trainingOfferScheduleCardCheck()
    trainingMoveSerial=trainingMoveSerial+1
    local serial=trainingMoveSerial
    safeWaitFrames("Offers.Training",function()
        if serial~=trainingMoveSerial then return end
        safeWaitCondition("Offers.Training",function()
            if serial~=trainingMoveSerial then return end
            local state=currentState()
            if state~=nil then
                if not trainingValid(state.seatPos,state.trainingGUID) then
                    trainingOfferClose(false)
                else
                    local _,_,offerType=exchangeMode(state.seatPos,state.trainingGUID)
                    if offerType~=(state.offerType or "Advanced Action") then
                        -- Changing the Book's Throw/Recover side changes the
                        -- eligible offer, not the cost. Reopen for that side.
                        local source=getObjectFromGUID(state.sourceGUID)
                        trainingOfferClose(false)
                        if source~=nil then
                            fromHand[source.guid]=state.seatPos
                            startTraining(state.seatPos,source)
                        end
                    end
                end
            end
            -- Claims belong to each physical copy until turn cleanup;
            -- lifting or turning one card must not reset the other's uses.
        end,function()
            if serial~=trainingMoveSerial then return true end
            for _,card in ipairs(trainingCandidates(currentSeat())) do
                if card.held_by_color~=nil or not card.resting or card.isSmoothMoving() then return false end
            end
            return true
        end,8)
    end,2)
end

function trainingOfferRestoreOnLoad()
    local state=currentState()
    if state==nil then return end
    if not trainingValid(state.seatPos,state.trainingGUID)
        or getObjectFromGUID(state.sourceGUID)==nil
        or getObjectFromGUID(state.cardGUID)==nil then
        -- An invalid preview must not reset completed claims on other cards.
        trainingOfferClose(false)
        return
    end
    local _,_,offerType=exchangeMode(state.seatPos,state.trainingGUID)
    if offerType~=(state.offerType or "Advanced Action") then
        trainingOfferClose(false)
        return
    end
    browseSerial=browseSerial+1
    showControls(state)
    if resourceCardsSourceChanged~=nil then resourceCardsSourceChanged() end
end
