-- Training: physically browse matching Advanced Actions, borrowing each
-- real Offer card and returning unchosen candidates to their original slot.
-- The cost Action remains visible until the player explicitly takes a card.
-- No borrowed Advanced Action contributes to the Resource Tracker.
local TRAINING_GUID="6fdeb0"
local browseSerial=0
local trainingMoveSerial=0
-- Transient origin evidence: a Training cost must actually leave this
-- player's hand, not be an already-played Action recycled from the table.
local fromHand={}
local returningPreview={}

local function currentState()
    return gStates~=nil and gStates.trainingOfferPreview or nil
end

local function coords(pos)
    return {pos.x or pos[1],pos.y or pos[2],pos.z or pos[3]}
end

local function inZone(guid,zoneGUID)
    local zone=zoneGUID~=nil and getObjectFromGUID(zoneGUID) or nil
    if zone==nil then return false end
    for _,obj in ipairs(zone.getObjects()) do
        if obj.guid==guid then return true end
    end
    return false
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
    if obj==nil or seatPos==nil or obj.type~="Card" then return end
    if legalPlayerCheck(playerColor,seatPos,"NoDummyException")==true
        and inZone(obj.guid,handZones[seatPos]) then
        fromHand[obj.guid]=seatPos
    end
end

local function cleanPreview(card)
    if card==nil then return end
    local xml=resourceObjectUiXmlTable(card.UI)
    local changed=false
    for i=#xml,1,-1 do
        local attr=xml[i].attributes
        local id=attr~=nil and attr.id or nil
        if type(id)=="string" and (id:sub(1,21)=="TrainingOfferControl_"
            or id:sub(1,19)=="ResourceCardChoice_"
            or id:sub(1,23)=="AttackAssignmentSource_") then
            table.remove(xml,i)
            changed=true
        end
    end
    if changed then resourceObjectUiSetTable(card.UI,xml) end
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
            if live~=nil and inZone(guid,GUID.zone.offer) then
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
    end
    if resourceCardsSourceChanged~=nil then resourceCardsSourceChanged() end
end

function trainingOfferClose(immediate)
    local state=currentState()
    if state~=nil then
        browseSerial=browseSerial+1
        returnPreview(state,immediate==true)
        gStates.trainingOfferPreview=nil
    end
    if immediate==true and gStates~=nil then
        gStates.trainingOfferClaims=nil
        fromHand={}
        returningPreview={}
    end
end

function trainingOfferReservedCard(guid,seatPos)
    local state=currentState()
    return returningPreview[guid]==true
        or state~=nil and state.seatPos==seatPos
            and (state.sourceGUID==guid or state.cardGUID==guid)
end

local function matchesSource(sourceData,offerData)
    if sourceData==nil or offerData==nil
        or offerData.cardType~="Advanced Action" then return false end
    for _,color in ipairs(sourceData.color or {}) do
        for _,other in ipairs(offerData.color or {}) do
            if color==other then return true end
        end
    end
    return false
end

local function borrow(state,index)
    local guid=state.order[index]
    local card=guid~=nil and getObjectFromGUID(guid) or nil
    local training=getObjectFromGUID(TRAINING_GUID)
    if card==nil or training==nil or not inZone(guid,GUID.zone.offer) then return false end
    state.index=index
    state.cardGUID=guid
    state.home={position=coords(card.getPosition()),
        rotation=coords(card.getRotation()),scale=coords(card.getScale())}
    local position=state.display
    if position==nil then
        local p=coords(training.getPosition())
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
    for _,card in ipairs(mainOfferCardsByType("Advanced Action")) do present[card.guid]=true end
    if state.cardGUID~=nil then present[state.cardGUID]=true end
    local oldIndex,count=state.index or 1,#state.order
    for step=1,count do
        local index=((oldIndex-1+step*delta)%count)+1
        local guid=state.order[index]
        if present[guid] and guid~=state.cardGUID then
            local current=getObjectFromGUID(state.cardGUID)
            if current~=nil then
                state.display=coords(current.getPosition())
                state.rotation=coords(current.getRotation())
            end
            returnPreview(state,false)
            borrow(state,index)
            return
        end
    end
end

local function trainingValid(seatPos)
    local card=getObjectFromGUID(TRAINING_GUID)
    if card==nil or seatPos==nil
        or not inZone(TRAINING_GUID,playerPlayAreas[seatPos]) then return false end
    if card.is_face_down==true then
        local _,repeats=resourceCardsTrainingMode(seatPos)
        if repeats<2 then return false end
    end
    return true
end

local function startTraining(seatPos,source)
    if currentState()~=nil or not trainingValid(seatPos) then return end
    local details=gameCards[source.guid]
    if details==nil or (details.cardType~="Starting"
        and details.cardType~="Advanced Action")
        or source.guid==TRAINING_GUID
        or fromHand[source.guid]~=seatPos
        or not inZone(source.guid,playerPlayAreas[seatPos]) then return end
    local training=getObjectFromGUID(TRAINING_GUID)
    local from=coords(source.getPosition())
    local at=coords(training.getPosition())
    if math.abs(at[1]-from[1])>1.4 or math.abs(at[3]-from[3])>1.8 then return end
    local _,repeatCount=resourceCardsTrainingMode(seatPos)
    gStates.trainingOfferClaims=gStates.trainingOfferClaims or {}
    if (gStates.trainingOfferClaims[TRAINING_GUID] or 0)>=repeatCount then return end
    local order={}
    for _,offer in ipairs(mainOfferCardsByType("Advanced Action")) do
        if matchesSource(details,gameCards[offer.guid]) then
            order[#order+1]=offer.guid
        end
    end
    if #order==0 then
        safeBroadcastToColor("Training: no matching Advanced Action is in the offer.",
            positionToColor(gStates.turnNumber),warningColor)
        return
    end
    fromHand[source.guid]=nil
    local state={seatPos=seatPos,sourceGUID=source.guid,
        order=order,index=1,trainingGUID=TRAINING_GUID}
    gStates.trainingOfferPreview=state
    if not borrow(state,1) then gStates.trainingOfferPreview=nil end
end

local function claim(state)
    if currentState()~=state or not trainingValid(state.seatPos) then return end
    local gained=getObjectFromGUID(state.cardGUID)
    local source=getObjectFromGUID(state.sourceGUID)
    if gained==nil or source==nil or not inZone(source.guid,playerPlayAreas[state.seatPos])
        or not matchesSource(gameCards[source.guid],gameCards[gained.guid]) then return end
    local powered,repeatCount=resourceCardsTrainingMode(state.seatPos)
    local destination=getObjectFromGUID(powered
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
    claims[TRAINING_GUID]=(claims[TRAINING_GUID] or 0)+1
    gStates.trainingOfferClaims=claims
    cleanPreview(gained)
    gained.UI.setXmlTable({{}})
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
    source.destruct() -- Training's cost is thrown away, not discarded.
    gained.unlock()
    if playAreaScaleForgetObject~=nil then playAreaScaleForgetObject(gained) end
    if powered then
        animateDeedCardToHand(gained,state.seatPos,0)
    else
        local p=coords(destination.getPosition())
        gained.setScale({1.5,1,1.5})
        gained.setPositionSmooth({p[1],math.max(1.8,p[2]+0.5),p[3]},false,false)
        gained.setRotationSmooth({0,180,0},false,false)
        safeWaitFrames("Offers.Training",function()
            scheduleDeedPileDescriptionRefresh(state.seatPos,"discard")
        end,5)
    end
    -- Offer compaction must happen *after* the claimed card has crossed
    -- the offer boundary; otherwise it still occupies its old slot.
    local function refill()
        if not inZone(gainedGUID,GUID.zone.offer) then compactAndRefillDeedOffer() end
    end
    safeWaitCondition("Offers.Training",refill,function()
        return not inZone(gainedGUID,GUID.zone.offer)
    end,8,refill)
    if resourceCardsSourceChanged~=nil then resourceCardsSourceChanged() end
    mainUIUpdate("Training Advanced Action Claimed")
    if claims[TRAINING_GUID]<repeatCount then
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
    if obj.guid==TRAINING_GUID then
        trainingOfferScheduleCardCheck()
        return
    end
    if active~=nil and obj.guid==active.cardGUID then
        local guid=obj.guid
        safeWaitCondition("Offers.Training",function()
            local state=currentState()
            if state==nil or state.cardGUID~=guid then return end
            local held=getObjectFromGUID(guid)
            if held==nil then return end
            state.display=coords(held.getPosition())
            state.rotation=coords(held.getRotation())
            local powered=resourceCardsTrainingMode(state.seatPos)
            if inZone(guid,powered and handZones[state.seatPos]
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
        if not inZone(obj.guid,playerPlayAreas[active.seatPos]) then
            trainingOfferClose(false)
        end
        return
    end
    if active~=nil or gameCards[obj.guid]==nil then return end
    local cardData=gameCards[obj.guid]
    if cardData.cardType~="Starting" and cardData.cardType~="Advanced Action" then return end
    if legalPlayerCheck(playerColor,seatPos,"NoDummyException")~=true then return end
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
            if state~=nil and not trainingValid(state.seatPos) then
                trainingOfferClose(false)
            end
            if currentSeat()==nil or not trainingValid(currentSeat()) then
                gStates.trainingOfferClaims=nil
            end
        end,function()
            if serial~=trainingMoveSerial then return true end
            local card=getObjectFromGUID(TRAINING_GUID)
            return card==nil or (card.held_by_color==nil and card.resting
                and not card.isSmoothMoving())
        end,8)
    end,2)
end

function trainingOfferRestoreOnLoad()
    local state=currentState()
    if state==nil then return end
    if not trainingValid(state.seatPos)
        or getObjectFromGUID(state.sourceGUID)==nil
        or getObjectFromGUID(state.cardGUID)==nil then
        trainingOfferClose(true)
        return
    end
    browseSerial=browseSerial+1
    showControls(state)
    if resourceCardsSourceChanged~=nil then resourceCardsSourceChanged() end
end
