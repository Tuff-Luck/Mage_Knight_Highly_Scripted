-- Magic Talent (3d832c): borrow a physical Spell from the offer or gain it.
-- Basic: overlap a coloured hand card with Magic Talent; the cost is discarded,
-- then a matching offer Spell may be cast by paying its normal mana on that Spell.
-- Strong: place the blue (or legal Day gold) power mana AND another coloured mana
-- on Magic Talent. Only then does the matching claim browser appear.
local function isTalent(guid)
    local data=gameCards[guid]
    return data~=nil and data.resourceKey=="magicTalent"
end
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

local function maximalEntitlement(seat,talentGUID)
    return resourceCardsMaximalEffectLink~=nil
        and resourceCardsMaximalEffectLink(seat,talentGUID) or nil
end

local function talentInPlay(seat,talentGUID)
    local card=talentGUID~=nil and getObjectFromGUID(talentGUID) or nil
    return seat~=nil and card~=nil and isTalent(talentGUID)
        and (trainingOfferReservedCard==nil or not trainingOfferReservedCard(talentGUID,seat))
        and (card.is_face_down~=true or maximalEntitlement(seat,talentGUID)~=nil)
        and cardEffectIsVertical(card)
        and objectGUIDInZone(talentGUID,playerPlayAreas[seat])
end

local function talentsInPlay(seat)
    local result={}
    local zone=seat~=nil and getObjectFromGUID(playerPlayAreas[seat]) or nil
    for _,card in ipairs(zone~=nil and zone.getObjects() or {}) do
        if isTalent(card.guid) and talentInPlay(seat,card.guid) then result[#result+1]=card.guid end
    end
    table.sort(result)
    return result
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
        if matching(card.guid,color)
            and (trainingOfferReservedCard==nil or not trainingOfferReservedCard(card.guid)) then
            order[#order+1]=card.guid
        end
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
local function strongColor(seat,useIndex,copy,talentGUID)
    if magicTalentManaPayments==nil then return nil end
    local payments=magicTalentManaPayments(seat,talentGUID)
    if copy~=nil and copy.powered==true then
        -- Maximal Effect provides Magic Talent's strong side for free.
        -- Its two *additional* mana payments must still be distinct.
        local choices,seen={},{}
        local goldLegal=resourceCardsGoldAllowed~=nil and resourceCardsGoldAllowed()
        local sourcePayments=resourceCardsMaximalEffectSourceManaGUIDs~=nil
            and resourceCardsMaximalEffectSourceManaGUIDs(seat,copy.sourceGUID) or {}
        for _,payment in ipairs(payments) do
            if seen[payment.guid]~=true and sourcePayments[payment.guid]~=true
                and (payment.color=="Red" or payment.color=="Blue"
                    or payment.color=="Green" or payment.color=="White"
                    or (payment.color=="Gold" and goldLegal)) then
                seen[payment.guid]=true
                choices[#choices+1]=payment.color
            end
        end
        if #choices<(copy.count or 1) then return nil end
        return choices[useIndex or 1]
    end
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
    if s.mode=="basic" and (s.limit or 1)>1 then
        for _,entry in ipairs({
            {suffix="nextUse",text="Next",x="-115"},
            {suffix="sameUse",text="Same",x="115"}
        }) do
            xml[#xml+1]={tag="Button",attributes={
                id=CONTROL_PREFIX..card.guid.."_"..entry.suffix,
                onClick="global/magicTalentClicked",
                position=entry.x.." -140 -35",rotation="0 0 0",
                width=140,height=70,scale="0.30 0.30",fontSize=38,
                text=entry.text,color="rgba(0.25,0.23,0.18,0.94)",
                textColor="rgba(1,1,1,1)"}}
        end
    end
    resourceObjectUiSetTable(card.UI,xml,
        resourceCardsExistingImageAssetsFor(card.UI,images))
end

function magicTalentEnsureControls(seat)
    local s=state()
    if s==nil or s.cardGUID==nil or (seat~=nil and s.seatPos~=seat) then return end
    local card=getObjectFromGUID(s.cardGUID)
    if card==nil then return end
    local previous,nextArrow,take,nextUse,sameUse=false,false,false,false,false
    for _,node in ipairs(resourceObjectUiXmlTable(card.UI)) do
        local id=node.attributes~=nil and node.attributes.id or nil
        if id==CONTROL_PREFIX..card.guid.."_previous" then previous=true
        elseif id==CONTROL_PREFIX..card.guid.."_next" then nextArrow=true
        elseif id==CONTROL_PREFIX..card.guid.."_claim" then take=true
        elseif id==CONTROL_PREFIX..card.guid.."_nextUse" then nextUse=true
        elseif id==CONTROL_PREFIX..card.guid.."_sameUse" then sameUse=true end
    end
    if not previous or not nextArrow or (s.mode=="strong" and not take)
        or (s.mode=="basic" and (s.limit or 1)>1
            and (not nextUse or not sameUse)) then controls(s) end
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
    if s~=nil then
        returnPreview(s,immediate==true)
        -- Each confirmed basic use keeps its borrowed Spell in play until
        -- end-of-turn cleanup. All loans return to their own offer slots.
        for guid,home in pairs(s.loans or {}) do
            returnPreview({cardGUID=guid,home=home},immediate==true)
        end
    end
    if gStates~=nil then gStates.magicTalentPreview=nil end
    fromHand={}
    if immediate==true then returning={} end
end

-- Do not allow the ordinary Offer claim path to consume a temporary preview.
function magicTalentReservedCard(guid)
    local s=state()
    return returning[guid]==true
        or (s~=nil and (s.cardGUID==guid or (s.loans or {})[guid]~=nil))
end

function magicTalentOfferSpellCastCount(seat,guid)
    local s=state()
    if s==nil or s.seatPos~=seat or s.mode=="strong" or s.mode=="claimed" then return 1 end
    local copies=math.max(1,tonumber((s.repeatCasts or {})[guid]) or 1)
    if copies>1 and magicTalentSpellCastingPaymentCount~=nil then
        -- Removing a mana payment retracts its copied cast immediately.
        copies=math.max(1,math.min(copies,
            magicTalentSpellCastingPaymentCount(seat,guid)))
    end
    return copies
end

-- Time Bending borrowed through Magic Talent must set aside Magic Talent,
-- not the Spell owned by the public offer. The normal extra-turn check still
-- validates the real blue + black casting mana on the loaned Spell.
function magicTalentBorrowedTimeBendingPaid(seat)
    local s=state()
    if s==nil or (s.mode~="basic" and s.mode~="completed") or s.seatPos~=seat
        or (s.cardGUID~=GUID.card.timeBending
            and (s.loans or {})[GUID.card.timeBending]==nil) then return false end
    local spell=getObjectFromGUID(GUID.card.timeBending)
    return spell~=nil and resourceCardsTimeBendingPaid(seat,spell)==true
end

function magicTalentBorrowedTimeBendingSource(seat)
    if magicTalentBorrowedTimeBendingPaid(seat) then return state().talentGUID end
    return nil
end

local function borrow(s,index)
    local guid=s.order[index]
    local card=guid~=nil and getObjectFromGUID(guid) or nil
    local talent=getObjectFromGUID(s.talentGUID)
    if card==nil or talent==nil or (s.loans or {})[guid]~=nil
        or not objectGUIDInZone(guid,GUID.zone.offer) then return false end
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
    if state()~=s or s.mode~="strong" or not talentInPlay(s.seatPos,s.talentGUID)
        or strongColor(s.seatPos,(s.used or 0)+1,s.copy,s.talentGUID)~=s.color then return end
    local gained=s.cardGUID~=nil and getObjectFromGUID(s.cardGUID) or nil
    local destination=getObjectFromGUID(deedDeckDiscardZones[s.seatPos])
    if gained==nil or destination==nil or not matching(gained.guid,s.color) then return end
    browseSerial=browseSerial+1
    local gainedGUID=gained.guid
    s.cardGUID,s.home=nil,nil
    s.used=(s.used or 0)+1
    s.mode=s.used>=(s.limit or 1) and "claimed" or "strong"
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
            if s.mode=="strong" then magicTalentSync() end
        end
    end,function()
        return not objectGUIDInZone(gainedGUID,GUID.zone.offer)
    end,8)
    if resourceCardsSourceChanged~=nil then resourceCardsSourceChanged() end
end

-- A copied basic Magic Talent is one composite effect with independent
-- colored discard costs. "Next" keeps a paid Spell in play as a committed loan
-- (or returns an uncast preview). "Same" needs one NEW casting mana on the
-- same physical Spell, so no mana object can pay for two repetitions.
local function advanceBasic(s,sameSpell)
    if state()~=s or s.mode~="basic" or s.copy==nil
        or s.copy.powered==true or s.cardGUID==nil
        or (s.used or 0)>=(s.limit or 1) then return end
    local guid=s.cardGUID
    local paid=paymentStillOnSpell(s)
    local firstRepeat=s.repeatCasts[guid]==nil
    local nextIndex=(s.used or 0)+(firstRepeat and 2 or 1)
    local nextColor=s.costColors~=nil and s.costColors[nextIndex] or nil
    if sameSpell then
        if not paid or nextColor==nil or not matching(guid,nextColor) then return end
        local previous=s.repeatCasts[guid] or 1
        if magicTalentSpellCastingPaymentCount==nil
            or magicTalentSpellCastingPaymentCount(s.seatPos,guid)<previous+1 then return end
        s.repeatCasts[guid]=previous+1
        -- The first Same press settles both the original cast and the second
        -- paid casting; subsequent presses settle one more application.
        s.used=s.used+(firstRepeat and 2 or 1)
        if s.used>=s.limit then
            s.loans[guid]=s.home
            clean(getObjectFromGUID(guid))
            s.cardGUID,s.home=nil,nil
            s.mode="completed"
        else
            s.color=nextColor
            controls(s)
        end
    else
        if paid then
            s.loans[guid]=s.home
            clean(getObjectFromGUID(guid))
            s.cardGUID,s.home=nil,nil
        else
            returnPreview(s,false)
        end
        s.used=s.used+1
        if s.used>=s.limit then
            s.mode="completed"
        else
            s.color=s.costColors[s.used+1]
            s.order=offerOrder(s.color)
            s.index=1
            if #s.order>0 then borrow(s,1) end
        end
    end
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
        if guid==nil then guid,action=id:match("^MagicTalentControl_([0-9a-f]+)_(nextUse)$") end
        if guid==nil then guid,action=id:match("^MagicTalentControl_([0-9a-f]+)_(sameUse)$") end
        if guid~=s.cardGUID then return end
        if action=="claim" then claim(s)
        elseif action=="nextUse" or action=="sameUse" then
            advanceBasic(s,action=="sameUse")
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

local function candidateCost(seat,talentGUID)
    local talent=getObjectFromGUID(talentGUID)
    local zone=getObjectFromGUID(playerPlayAreas[seat])
    if talent==nil or zone==nil then return nil,nil end
    local t=ttsVectorArray(talent.getPosition())
    for _,card in ipairs(zone.getObjects()) do
        local color=cardColor(card.guid)
        local data=gameCards[card.guid]
        if card.type=="Card" and card.guid~=talentGUID
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

-- The basic copied effect discards all three hand cards, whether or not the
-- player subsequently casts every Spell. Their colors determine each use.
local function candidateCosts(seat,need,talentGUID)
    local talent=getObjectFromGUID(talentGUID)
    local zone=getObjectFromGUID(playerPlayAreas[seat])
    if talent==nil or zone==nil then return nil end
    local t=ttsVectorArray(talent.getPosition())
    local choices={}
    for _,card in ipairs(zone.getObjects()) do
        local color=cardColor(card.guid)
        local data=gameCards[card.guid]
        if card.type=="Card" and card.guid~=talentGUID
            and fromHand[card.guid]==seat and color~=nil
            and data~=nil and data.cardType~="Artifact"
            and data.cardType~="Wound" and card.resting==true then
            local p=ttsVectorArray(card.getPosition())
            if math.abs(t[1]-p[1])<1.4 and math.abs(t[3]-p[3])<1.8 then
                choices[#choices+1]={card=card,color=color}
            end
        end
    end
    table.sort(choices,function(a,b) return a.card.guid<b.card.guid end)
    if #choices<need then return nil end
    local paid={}
    for i=1,need do paid[i]=choices[i] end
    return paid
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

local function start(seat,mode,color,source,copy,costs,talentGUID)
    local count=copy~=nil and copy.count or 1
    local s={seatPos=seat,talentGUID=talentGUID,mode=mode,color=color,order=offerOrder(color),index=1,
        sourceGUID=source~=nil and source.guid or nil,
        copy=copy~=nil and {count=count,powered=copy.powered==true,
            sourceGUID=copy.sourceGUID} or nil,
        limit=count,used=0,loans={},repeatCasts={}}
    if costs~=nil then
        s.costColors={}
        for index,entry in ipairs(costs) do
            if not discardCost(seat,entry.card) then return end
            s.costColors[index]=entry.color
        end
        s.color=s.costColors[1]
    elseif source~=nil and not discardCost(seat,source) then return end
    gStates.magicTalentPreview=s
    if #s.order>0 then borrow(s,1) end
    if #s.order==0 then
        safeBroadcastToColor("Magic Talent: no matching Spell is in the offer.",
            positionToColor(gStates.turnNumber),warningColor)
    end
end

function magicTalentSync()
    if gStates==nil or gStates.firstStarted~=true then return end
    local s=state()
    local seat=currentSeat()
    if seat==nil or (s~=nil and (s.seatPos~=seat or not talentInPlay(seat,s.talentGUID))) then
        if s~=nil then magicTalentClose(true) end
        return
    end
    local copy=s~=nil and maximalEntitlement(seat,s.talentGUID) or nil
    if s~=nil and s.copy~=nil
        and (copy==nil or s.copy.count~=copy.count
            or s.copy.powered~=(copy.powered==true)
            or s.copy.sourceGUID~=copy.sourceGUID) then
        -- If Maximal Effect's physical link is undone, every temporary
        -- Spell returns to the offer and its cast stops contributing.
        magicTalentClose(true)
        s=nil
    end
    if s==nil then
        -- Each physical source has its own mana and discard footprint.
        -- Keep the existing single browser/loan session; never transfer its
        -- entitlement to another copy merely because both are in play.
        for _,talentGUID in ipairs(talentsInPlay(seat)) do
            local entitlement=maximalEntitlement(seat,talentGUID)
            if entitlement~=nil and entitlement.powered==true then
                local paid=strongColor(seat,1,entitlement,talentGUID)
                if paid~=nil then start(seat,"strong",paid,nil,entitlement,nil,talentGUID) return end
            elseif entitlement~=nil then
                local costs=candidateCosts(seat,entitlement.count,talentGUID)
                if costs~=nil then
                    start(seat,"basic",costs[1].color,nil,entitlement,costs,talentGUID)
                    return
                end
            else
                local cost,color=candidateCost(seat,talentGUID)
                if cost~=nil then start(seat,"basic",color,cost,nil,nil,talentGUID) return end
                local paid=strongColor(seat,nil,nil,talentGUID)
                if paid~=nil then start(seat,"strong",paid,nil,nil,nil,talentGUID) return end
            end
        end
        return
    end
    if s.mode=="basic" then
        if s.cardGUID==nil and (s.used or 0)<(s.limit or 1) then
            s.order=offerOrder(s.color)
            s.index=1
            if #s.order>0 then borrow(s,1) end
        end
        return
    end
    if s.mode~="strong" then return end
    local paid=strongColor(seat,(s.used or 0)+1,s.copy,s.talentGUID)
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
            local moved=movedGUID~=nil and getObjectFromGUID(movedGUID) or nil
            local seat=currentSeat()
            local zone=seat~=nil and getObjectFromGUID(playerPlayAreas[seat]) or nil
            for _,card in ipairs(zone~=nil and zone.getObjects() or {}) do
                if isTalent(card.guid) and (card.held_by_color~=nil
                    or not card.resting or card.isSmoothMoving()) then return false end
            end
            return moved==nil or (moved.held_by_color==nil
                and moved.resting and not moved.isSmoothMoving())
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
    if s~=nil or #talentsInPlay(currentSeat())>0 then magicTalentScheduleCheck(obj.guid) end
end

function magicTalentRestoreOnLoad()
    local s=state()
    if s==nil then return end
    if not talentInPlay(s.seatPos,s.talentGUID) then magicTalentClose(true) return end
    if s.cardGUID~=nil then
        local card=getObjectFromGUID(s.cardGUID)
        if card==nil then magicTalentClose(true) return end
        browseSerial=browseSerial+1
        controls(s)
    end
    magicTalentScheduleCheck()
end
