-- Magic Talent (3d832c): borrow a physical Spell from the offer or gain it.
-- Basic: overlap a coloured hand card with Magic Talent; the cost is discarded,
-- then a matching offer Spell may be cast by paying its normal mana on that Spell.
-- Strong: place the blue (or legal Day gold) power mana AND another coloured mana
-- on Magic Talent. Only then does the matching claim browser appear.
-- Tome of All Spells uses the same matching-colour discard and real
-- Spell browser, but a confirmed Cast grants the printed side for free.
local function isTome(guid)
    return guid=="085e68" and gameCards[guid]~=nil
end

local function isAncients(guid)
    local data=gameCards[guid]
    return data~=nil and data.resourceKey=="bloodOfAncients"
end

local function isTalent(guid)
    local data=gameCards[guid]
    return data~=nil and (data.resourceKey=="magicTalent" or isTome(guid) or isAncients(guid))
end
local CONTROL_PREFIX="MagicTalentControl_"
local CONTROL_PREFIXES={CONTROL_PREFIX,"ResourceCardChoice_","AttackAssignmentSource_"}
local settleSerial=0
local fromHand={}
local returning={}
local browseSerials={}

-- Each physical source owns its own saved browser and committed loans.
local function sessions()
    return gStates~=nil and gStates.magicTalentPreviews or {}
end

local function state(sourceGUID)
    return sessions()[sourceGUID]
end

local function sessionList()
    local result={}
    for _,s in pairs(sessions()) do result[#result+1]=s end
    table.sort(result,function(a,b) return a.talentGUID<b.talentGUID end)
    return result
end

local function cardSession(guid)
    if guid==nil then return nil end
    for _,s in pairs(sessions()) do
        if s.cardGUID==guid or (s.loans or {})[guid]~=nil then return s end
    end
end

local function liveSession(s)
    return state(s.talentGUID)==s
end

local function bumpBrowse(s)
    local guid=s.talentGUID
    browseSerials[guid]=(browseSerials[guid] or 0)+1
    return browseSerials[guid]
end

local function currentSeat()
    local player=gStates~=nil and turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    return player~=nil and player.seatPos or nil
end

local function maximalEntitlement(seat,talentGUID)
    return not isTome(talentGUID) and resourceCardsMaximalEffectLink~=nil
        and resourceCardsMaximalEffectLink(seat,talentGUID) or nil
end

local function talentInPlay(seat,talentGUID)
    local card=talentGUID~=nil and getObjectFromGUID(talentGUID) or nil
    return seat~=nil and card~=nil and isTalent(talentGUID)
        and cardSession(talentGUID)==nil
        and not returning[talentGUID]
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

local function matching(guid,color,kind)
    local data=gameCards[guid]
    if data==nil or data.cardType~=(kind or "Spell") then return false end
    if color=="Gold" then return true end
    if type(data.color)=="string" then return data.color==color end
    for _,value in ipairs(data.color or {}) do if value==color then return true end end
    return false
end

local function offerOrder(color,previewGUID,kind,eligible)
    local order={}
    local function allowed(guid)
        return matching(guid,color,kind) and (eligible==nil or eligible(guid))
            and not returning[guid]
            and (guid==previewGUID or cardSession(guid)==nil)
            and (trainingOfferReservedCard==nil or not trainingOfferReservedCard(guid))
    end
    for _,card in ipairs(mainOfferCardsByType(kind or "Spell")) do
        if allowed(card.guid) then order[#order+1]=card.guid end
    end
    if previewGUID~=nil and allowed(previewGUID) then
        local found=false
        for _,guid in ipairs(order) do if guid==previewGUID then found=true break end end
        if not found then order[#order+1]=previewGUID end
    end
    -- Put the current preview back into its logical offer-column order,
    -- not at the end of the navigation list every time we rebuild it.
    if previewGUID~=nil then
        local owner=cardSession(previewGUID)
        local home=owner~=nil and owner.home or nil
        if home~=nil then
            local positions={}
            for _,guid in ipairs(order) do
                local card=getObjectFromGUID(guid)
                positions[guid]=guid==previewGUID and home.position[1]
                    or (card~=nil and ttsVectorArray(card.getPosition())[1] or 0)
            end
            table.sort(order,function(a,b)
                if positions[a]==positions[b] then return a<b end
                return positions[a]<positions[b]
            end)
        end
    end
    return order
end

-- Both mana-consuming browser types accept the four basic colours and
-- legal Gold. Use the existing physical ranking when their footprints overlap.
local function browserManaPayments(seat,guid)
    local sources={}
    for _,source in ipairs(talentsInPlay(seat)) do
        if not isTome(source) then sources[#sources+1]=source end
    end
    return magicTalentManaPayments(seat,guid,sources)
end

-- Blood of Ancients needs an extra payment on its basic side. Red
-- (or legal Gold) can instead power its stronger side; the player chooses.
local function ancientsPayments(seat,guid,copy,spent)
    local result,seen={},{}
    local sourcePayments=copy~=nil and resourceCardsMaximalEffectSourceManaGUIDs~=nil
        and resourceCardsMaximalEffectSourceManaGUIDs(seat,copy.sourceGUID) or {}
    for _,payment in ipairs(magicTalentManaPayments~=nil and browserManaPayments(seat,guid) or {}) do
        local color=payment.color
        if not seen[payment.guid] and not sourcePayments[payment.guid]
            and not (spent or {})[payment.guid]
            and (color=="Red" or color=="Green" or color=="Blue" or color=="White"
                or (color=="Gold" and resourceCardsGoldAllowed())) then
            seen[payment.guid]=true
            result[#result+1]=payment
        end
    end
    table.sort(result,function(a,b) return a.guid<b.guid end)
    return result
end

-- Find a distinct payment/card pairing for every remaining basic use.
-- A proposed next choice is legal only when the remaining uses are
-- payable with the other mana and currently available offer cards.
local function ancientsPairing(payments,order,need,firstGUID,firstPayment)
    if need<=0 then return true end
    local usedCards,usedMana={},{}
    if firstGUID~=nil then
        usedCards[firstGUID]=true
        usedMana[firstPayment.guid]=true
        need=need-1
    end
    local function search(left)
        if left==0 then return true end
        for _,guid in ipairs(order) do
            if not usedCards[guid] then
                usedCards[guid]=true
                for _,payment in ipairs(payments) do
                    if not usedMana[payment.guid] and matching(guid,payment.color,"Advanced Action") then
                        usedMana[payment.guid]=true
                        if search(left-1) then return true end
                        usedMana[payment.guid]=nil
                    end
                end
                usedCards[guid]=nil
            end
        end
        return false
    end
    return search(need)
end

local function ancientsBasicPayment(seat,guid,copy,s,selected,order)
    local payments=ancientsPayments(seat,guid,copy,s~=nil and s.spentMana or nil)
    local need=copy.count-(s~=nil and s.used or 0)
    if #payments<need then return nil end
    for _,payment in ipairs(payments) do
        if matching(selected,payment.color,"Advanced Action")
            and ancientsPairing(payments,order,need,selected,payment) then return payment end
    end
    return nil
end

local function ancientsPermissions(seat,guid)
    local colors,strong={},false
    local s=state(guid)
    local copy=s~=nil and s.copy or maximalEntitlement(seat,guid)
    if copy~=nil and copy.powered then return colors,true end
    local payments=ancientsPayments(seat,guid,copy,s~=nil and s.spentMana or nil)
    for _,payment in ipairs(payments) do
        colors[payment.color]=true
        if copy==nil and (payment.color=="Red" or payment.color=="Gold") then strong=true end
    end
    if copy~=nil then return colors,false end
    local scan=resourceCardScanBySeat~=nil and resourceCardScanBySeat[seat] or nil
    local record=scan~=nil and scan.cards~=nil and scan.cards[guid] or nil
    -- Concentration/Will Focus can grant the stronger side without a red
    -- payment. Do not turn an unrelated basic colour into a power payment.
    if record~=nil and resourceCardsPanelOpen~=nil and resourceCardsPanelOpen()
        and record.compositeAction and record.repeatLink==nil
        and record.powered then strong=true end
    return colors,strong
end

local function ancientsCanGain(guid,colors)
    for color in pairs(colors) do
        if matching(guid,color,"Advanced Action") then return true end
    end
    return false
end

local function ancientsOrder(seat,source,preview)
    local colors,strong=ancientsPermissions(seat,source)
    local s=state(source)
    local copy=s~=nil and s.copy or maximalEntitlement(seat,source)
    local order=offerOrder("Gold",preview,"Advanced Action")
    local result={}
    for _,guid in ipairs(order) do
        if strong or (copy==nil and ancientsCanGain(guid,colors))
            or (copy~=nil and not copy.powered
                and ancientsBasicPayment(seat,source,copy,s,guid,order)~=nil) then
            result[#result+1]=guid
        end
    end
    return result
end

local function ancientsGainAvailable(s,guid,colors)
    if s.copy==nil then return ancientsCanGain(guid,colors) end
    if s.copy.powered then return false end
    local order=offerOrder("Gold",guid,"Advanced Action")
    return ancientsBasicPayment(s.seatPos,s.talentGUID,s.copy,s,guid,order)~=nil
end

-- Two different physical mana objects are required. Gold can power the
-- blue Action only while legal and can select any Spell as the extra payment.
local function strongColor(seat,useIndex,copy,talentGUID)
    if magicTalentManaPayments==nil then return nil end
    local payments=browserManaPayments(seat,talentGUID)
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
    if not liveSession(s) or s.cardGUID==nil then return end
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
        "magicTalentClicked",s.mode=="strong" or s.mode=="tome")
    if s.mode=="ancients" then
        local colors,strong=ancientsPermissions(s.seatPos,s.talentGUID)
        local function action(suffix,label,x,y)
            xml[#xml+1]={tag="Button",attributes={
                id=CONTROL_PREFIX..card.guid.."_"..suffix,
                onClick="global/magicTalentClicked",
                position=x.." "..y.." -35",rotation="0 0 0",
                width=170,height=70,scale="0.30 0.30",fontSize=32,
                text=label,color="rgba(0.12,0.32,0.16,0.92)",textColor="rgba(1,1,1,1)"}}
        end
        if ancientsGainAvailable(s,card.guid,colors) then action("gainAncients","Gain", "0","0") end
        if strong then
            action("useAncientsHand","Use / Hand","-100","-140")
            action("useAncientsDiscard","Use / Discard","100","-140")
        end
    elseif s.mode=="tome" then
        for _,node in ipairs(xml) do
            if node.attributes~=nil and node.attributes.id==CONTROL_PREFIX..card.guid.."_claim" then
                node.attributes.text="Cast"
            end
        end
    end
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

local function ensureControls(s)
    if not liveSession(s) or s.cardGUID==nil then return end
    local card=getObjectFromGUID(s.cardGUID)
    if card==nil then return end
    local previous,nextArrow,take,nextUse,sameUse=false,false,false,false,false
    local gainAncients,useHand,useDiscard=false,false,false
    for _,node in ipairs(resourceObjectUiXmlTable(card.UI)) do
        local id=node.attributes~=nil and node.attributes.id or nil
        if id==CONTROL_PREFIX..card.guid.."_previous" then previous=true
        elseif id==CONTROL_PREFIX..card.guid.."_next" then nextArrow=true
        elseif id==CONTROL_PREFIX..card.guid.."_claim" then take=true
        elseif id==CONTROL_PREFIX..card.guid.."_nextUse" then nextUse=true
        elseif id==CONTROL_PREFIX..card.guid.."_sameUse" then sameUse=true
        elseif id==CONTROL_PREFIX..card.guid.."_gainAncients" then gainAncients=true
        elseif id==CONTROL_PREFIX..card.guid.."_useAncientsHand" then useHand=true
        elseif id==CONTROL_PREFIX..card.guid.."_useAncientsDiscard" then useDiscard=true end
    end
    if s.mode=="ancients" then
        local colors,strong=ancientsPermissions(s.seatPos,s.talentGUID)
        if gainAncients~=ancientsGainAvailable(s,card.guid,colors) or useHand~=strong or useDiscard~=strong then
            controls(s)
            return
        end
    end
    if not previous or not nextArrow or ((s.mode=="strong" or s.mode=="tome") and not take)
        or (s.mode=="basic" and (s.limit or 1)>1
            and (not nextUse or not sameUse)) then controls(s) end
end

function magicTalentEnsureControls(seat)
    for _,s in ipairs(sessionList()) do
        if seat==nil or s.seatPos==seat then ensureControls(s) end
    end
end

-- The offer card keeps its GUID and is never cloned. Retire the calculator
-- source BEFORE the card is returned; delayed scans must not recreate targets.
local function returnPreview(s,immediate)
    if s==nil or s.cardGUID==nil then return end
    local guid,home=s.cardGUID,s.home
    local token={}
    s.cardGUID,s.home=nil,nil
    returning[guid]=token
    if s.talentGUID~=nil then bumpBrowse(s) end
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
        if returning[guid]~=token then return end
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
    end,8,function() if returning[guid]==token then returning[guid]=nil end end)
    if resourceCardsSourceChanged~=nil then resourceCardsSourceChanged() end
end

local function closeSession(s,immediate)
    if not liveSession(s) then return end
    sessions()[s.talentGUID]=nil
    local preview=s.cardGUID
    returnPreview(s,immediate)
    -- A repeated basic cast can also be the current preview. Restore it once.
    for guid,home in pairs(s.loans or {}) do
        if guid~=preview then
            returnPreview({cardGUID=guid,home=home},immediate)
        end
    end
end

function magicTalentClose(immediate)
    settleSerial=settleSerial+1
    for _,s in ipairs(sessionList()) do closeSession(s,immediate==true) end
    if gStates~=nil then gStates.magicTalentPreviews=nil end
    fromHand={}
end

-- Do not allow the ordinary Offer claim path to consume a temporary preview.
function magicTalentReservedCard(guid)
    return returning[guid]~=nil or cardSession(guid)~=nil
end

-- Gaining a card is not casting it. Tome likewise needs an explicit Cast
-- before its mana-free effect exists. Returning cards are always inert.
function magicTalentInactivePreview(guid)
    local s=cardSession(guid)
    return returning[guid]~=nil or (s~=nil and (
        (s.cardGUID==guid and (s.mode=="strong" or s.mode=="tome" or s.mode=="ancients"))
        or ((s.freeGUID==guid or (s.ancientsLoans or {})[guid])
            and magicTalentOfferCastSide(s.seatPos,guid)==nil)))
end

-- nil = ordinary payment rules; false = free basic; true = free stronger.
-- Never use an 'and ... or nil' expression here: false is meaningful.
function magicTalentOfferCastSide(seat,guid)
    local s=cardSession(guid)
    if s==nil or s.seatPos~=seat or not talentInPlay(seat,s.talentGUID) then return nil end
    local ancientsLoan=(s.ancientsLoans or {})[guid]==true
    if not ancientsLoan and (s.mode~="tomeCast" or s.freeGUID~=guid) then return nil end
    local spell=getObjectFromGUID(guid)
    if spell==nil or not cardEffectIsVertical(spell)
        or not objectGUIDInZone(guid,playerPlayAreas[seat]) then return nil end
    if ancientsLoan then return true end
    return s.freeStrong==true
end

function magicTalentTomeCommitted(guid)
    local s=state(guid)
    return s~=nil and s.mode=="tomeCast" and s.talentGUID==guid
end

function magicTalentOfferSpellCastCount(seat,guid)
    local s=cardSession(guid)
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
    local s=cardSession(GUID.card.timeBending)
    if s~=nil and s.mode=="tomeCast" then
        return magicTalentOfferCastSide(seat,GUID.card.timeBending)==true
    end
    if s==nil or (s.mode~="basic" and s.mode~="completed") or s.seatPos~=seat
        or (s.cardGUID~=GUID.card.timeBending
            and (s.loans or {})[GUID.card.timeBending]==nil) then return false end
    local spell=getObjectFromGUID(GUID.card.timeBending)
    return spell~=nil and resourceCardsTimeBendingPaid(seat,spell)==true
end

function magicTalentBorrowedTimeBendingSource(seat)
    if magicTalentBorrowedTimeBendingPaid(seat) then
        local s=cardSession(GUID.card.timeBending)
        return s~=nil and s.talentGUID or nil
    end
    return nil
end

local function borrow(s,index)
    local guid=s.order[index]
    local card=guid~=nil and getObjectFromGUID(guid) or nil
    local talent=getObjectFromGUID(s.talentGUID)
    if not liveSession(s) or s.cardGUID~=nil or card==nil or talent==nil
        or cardSession(guid)~=nil or returning[guid]
        or (trainingOfferReservedCard~=nil and trainingOfferReservedCard(guid))
        or not objectGUIDInZone(guid,GUID.zone.offer) then return false end
    s.index=index
    s.cardGUID=guid
    s.home={position=ttsVectorArray(card.getPosition()),
        rotation=ttsVectorArray(card.getRotation()),scale=ttsVectorArray(card.getScale())}
    local pos=ttsVectorArray(talent.getPosition())
    local offset=s.mode=="ancients" and 3.0*(1+s.used) or 3.0
    local display=s.display or {position={pos[1]+offset,math.max(1.8,pos[2]+0.35),pos[3]},
        rotation={0,180,0}}
    local serial=bumpBrowse(s)
    card.unlock()
    card.setScale({1.5,1,1.5})
    card.setPositionSmooth(display.position,false,false)
    card.setRotationSmooth(display.rotation,false,false)
    controls(s)
    local function settled()
        if not liveSession(s) or s.cardGUID~=guid or serial~=browseSerials[s.talentGUID] then return end
        ensureControls(s)
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
    -- Other sessions can gain/return cards between clicks. Rebuild the
    -- live candidates and retain the current preview as the anchor.
    local order=s.mode=="ancients" and ancientsOrder(s.seatPos,s.talentGUID,s.cardGUID)
        or offerOrder(s.color,s.cardGUID)
    local index
    for i,guid in ipairs(order) do if guid==s.cardGUID then index=i break end end
    if index==nil then return end
    s.order,s.index=order,index
    local count=#order
    for step=1,count do
        local index=((s.index-1+step*delta)%count)+1
        local guid=s.order[index]
        if guid~=s.cardGUID and not magicTalentReservedCard(guid)
            and (trainingOfferReservedCard==nil or not trainingOfferReservedCard(guid))
            and objectGUIDInZone(guid,GUID.zone.offer) then
            remember(s)
            returnPreview(s,false)
            borrow(s,index)
            return
        end
    end
end

-- Transfer the actual offer card once, independently of the effect that
-- granted it. Magic Talent claims to discard; Blood of Ancients to hand.
local function commitGain(s,gained,destination,toHand)
    bumpBrowse(s)
    local gainedGUID=gained.guid
    s.cardGUID,s.home=nil,nil
    s.used=(s.used or 0)+1
    s.mode=s.used>=(s.limit or 1) and "claimed" or (toHand and "ancients" or "strong")
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
    if toHand then
        animateDeedCardToHand(gained,s.seatPos,0)
    else
        local p=ttsVectorArray(destination.getPosition())
        gained.setScale({1.5,1,1.5})
        gained.setPositionSmooth({p[1],math.max(1.8,p[2]+0.5),p[3]},false,false)
        gained.setRotationSmooth({0,180,0},false,false)
    end
    safeWaitCondition("Offers.MagicTalent",function()
        if not objectGUIDInZone(gainedGUID,GUID.zone.offer) then
            compactAndRefillDeedOffer()
            if not toHand then scheduleDeedPileDescriptionRefresh(s.seatPos,"discard") end
            if liveSession(s) and (s.mode=="strong" or s.mode=="ancients") then magicTalentSync() end
        end
    end,function()
        return not objectGUIDInZone(gainedGUID,GUID.zone.offer)
    end,8)
    if resourceCardsSourceChanged~=nil then resourceCardsSourceChanged() end
end

local function claim(s)
    if not liveSession(s) or s.mode~="strong" or not talentInPlay(s.seatPos,s.talentGUID)
        or strongColor(s.seatPos,(s.used or 0)+1,s.copy,s.talentGUID)~=s.color then return end
    local gained=s.cardGUID~=nil and getObjectFromGUID(s.cardGUID) or nil
    local destination=getObjectFromGUID(deedDeckDiscardZones[s.seatPos])
    if gained==nil or destination==nil or not matching(gained.guid,s.color) then return end
    commitGain(s,gained,destination,false)
end

local function confirmAncients(s,action)
    if not liveSession(s) or s.mode~="ancients" or s.woundPending
        or currentSeat()~=s.seatPos or not talentInPlay(s.seatPos,s.talentGUID)
        or s.used>=s.limit then return end
    local copy=maximalEntitlement(s.seatPos,s.talentGUID)
    if (copy~=nil)~=(s.copy~=nil) or (copy~=nil and
        (copy.count~=s.copy.count or copy.powered~=s.copy.powered
            or copy.sourceGUID~=s.copy.sourceGUID)) then return end
    local guid=s.cardGUID
    local card=guid~=nil and getObjectFromGUID(guid) or nil
    if card==nil or not cardEffectIsVertical(card)
        or not objectGUIDInZone(guid,playerPlayAreas[s.seatPos]) then return end
    local colors,strong=ancientsPermissions(s.seatPos,s.talentGUID)
    local gain=action=="gainAncients"
    if (gain and not ancientsGainAvailable(s,guid,colors)) or (not gain and not strong) then return end
    local payment
    if gain and copy~=nil then
        payment=ancientsBasicPayment(s.seatPos,s.talentGUID,copy,s,guid,
            offerOrder("Gold",guid,"Advanced Action"))
        if payment==nil then return end
    end
    local destination=getObjectFromGUID(handZones[s.seatPos])
    if gain and destination==nil then return end
    local discard=action=="useAncientsDiscard"
    if discard and getObjectFromGUID(deedDeckDiscardZones[s.seatPos])==nil then return end
    s.woundPending=true
    combatDealCalculatedWounds(s.seatPos,{{key=s.talentGUID,hand=discard and 0 or 1,discard=discard and 1 or 0}},
        function(_key,_to,_woundGUID)
            -- The existing wound service acknowledges a real card immediately.
            -- Commit only after the physical cost was actually produced.
            gStates.ancientsOfferClaims=gStates.ancientsOfferClaims or {}
            -- Remember committed use even if the source is later removed.
            -- Closing a partial combination must not allow the costs to be reused.
            gStates.ancientsOfferClaims[s.talentGUID]=true
            s.woundPending=nil
            if gain then
                if payment~=nil then
                    s.spentMana=s.spentMana or {}
                    s.spentMana[payment.guid]=true
                end
                commitGain(s,card,destination,true)
            else
                s.ancientsLoans=s.ancientsLoans or {}
                s.ancientsLoans[guid]=true
                s.loans[guid]=s.home
                s.cardGUID,s.home=nil,nil
                s.used=s.used+1
                s.mode=s.used>=s.limit and "ancientsCast" or "ancients"
                -- Give each distinct loan its own physical display position.
                s.display=nil
                bumpBrowse(s)
                clean(card)
                if resourceCardsSourceChanged~=nil then resourceCardsSourceChanged() end
                if s.mode=="ancients" then magicTalentScheduleCheck() end
            end
        end,function(ok,reason)
            s.woundPending=nil
            if not ok then
                safeBroadcastToColor("Blood of Ancients: "..tostring(reason),
                    positionToColor(gStates.turnNumber),warningColor)
            end
        end)
end

local function castTome(s)
    if not liveSession(s) or s.mode~="tome" or currentSeat()~=s.seatPos
        or not talentInPlay(s.seatPos,s.talentGUID) then return end
    local guid=s.cardGUID
    local spell=guid~=nil and getObjectFromGUID(guid) or nil
    if spell==nil or not cardEffectIsVertical(spell) or not matching(guid,s.color)
        or not objectGUIDInZone(guid,playerPlayAreas[s.seatPos]) then return end
    s.freeStrong=resourceCardsArtifactBroken(s.talentGUID,getObjectFromGUID(s.talentGUID))==true
    s.freeGUID=guid
    s.mode="tomeCast"
    s.loans[guid]=s.home
    s.cardGUID,s.home=nil,nil
    s.used=1
    bumpBrowse(s)
    clean(spell)
    if resourceCardsSourceChanged~=nil then resourceCardsSourceChanged() end
    -- Call to Arms has an independent physical Unit browser.
    if guid=="2eb8e8" and callOfferSpellEntered~=nil then
        callOfferSpellEntered(guid,s.seatPos)
    end
end

-- A copied basic Magic Talent is one composite effect with independent
-- colored discard costs. "Next" keeps a paid Spell in play as a committed loan
-- (or returns an uncast preview). "Same" needs one NEW casting mana on the
-- same physical Spell, so no mana object can pay for two repetitions.
local function advanceBasic(s,sameSpell)
    if not liveSession(s) or s.mode~="basic" or s.copy==nil
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
        if type(id)~="string" then return end
        local guid,action=id:match("^MagicTalentControl_([0-9a-f]+)_(previous)$")
        if guid==nil then guid,action=id:match("^MagicTalentControl_([0-9a-f]+)_(next)$") end
        if guid==nil then guid,action=id:match("^MagicTalentControl_([0-9a-f]+)_(claim)$") end
        if guid==nil then guid,action=id:match("^MagicTalentControl_([0-9a-f]+)_(nextUse)$") end
        if guid==nil then guid,action=id:match("^MagicTalentControl_([0-9a-f]+)_(sameUse)$") end
        if guid==nil then guid,action=id:match("^MagicTalentControl_([0-9a-f]+)_(gainAncients)$") end
        if guid==nil then guid,action=id:match("^MagicTalentControl_([0-9a-f]+)_(useAncientsHand)$") end
        if guid==nil then guid,action=id:match("^MagicTalentControl_([0-9a-f]+)_(useAncientsDiscard)$") end
        local s=cardSession(guid)
        if s==nil or guid~=s.cardGUID or s.woundPending
            or currentSeat()~=s.seatPos
            or legalPlayerCheck(player.color,s.seatPos,"NoDummyException")~=true then return end
        if action=="gainAncients" or action=="useAncientsHand" or action=="useAncientsDiscard" then
            confirmAncients(s,action)
        elseif action=="claim" then
            if s.mode=="tome" then castTome(s) else claim(s) end
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
            and state(card.guid)==nil and not magicTalentReservedCard(card.guid)
            and (trainingOfferReservedCard==nil or not trainingOfferReservedCard(card.guid,seat))
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
            and state(card.guid)==nil and not magicTalentReservedCard(card.guid)
            and (trainingOfferReservedCard==nil or not trainingOfferReservedCard(card.guid,seat))
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
    local order=mode=="ancients" and ancientsOrder(seat,talentGUID) or offerOrder(color)
    local s={seatPos=seat,talentGUID=talentGUID,mode=mode,color=color,order=order,index=1,
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
    gStates.magicTalentPreviews=gStates.magicTalentPreviews or {}
    gStates.magicTalentPreviews[talentGUID]=s
    if #s.order>0 then borrow(s,1) end
    if #s.order==0 then
        safeBroadcastToColor(mode=="ancients" and "Blood of Ancients: no eligible Action in the offer."
            or "Magic Talent: no matching Spell is in the offer.",
            positionToColor(gStates.turnNumber),warningColor)
    end
end

local function startSource(seat,talentGUID)
    if state(talentGUID)~=nil or not talentInPlay(seat,talentGUID) then return end
    local entitlement=maximalEntitlement(seat,talentGUID)
    if isAncients(talentGUID) then
        if not (gStates.ancientsOfferClaims or {})[talentGUID]
            and #ancientsOrder(seat,talentGUID)>0 then
            start(seat,"ancients","Gold",nil,entitlement,nil,talentGUID)
        end
    elseif isTome(talentGUID) then
        local cost,color=candidateCost(seat,talentGUID)
        if cost~=nil and #offerOrder(color)>0 then
            start(seat,"tome",color,cost,nil,nil,talentGUID)
        end
    elseif entitlement~=nil and entitlement.powered==true then
        local paid=strongColor(seat,1,entitlement,talentGUID)
        if paid~=nil then start(seat,"strong",paid,nil,entitlement,nil,talentGUID) end
    elseif entitlement~=nil then
        local costs=candidateCosts(seat,entitlement.count,talentGUID)
        if costs~=nil then start(seat,"basic",costs[1].color,nil,entitlement,costs,talentGUID) end
    else
        local cost,color=candidateCost(seat,talentGUID)
        if cost~=nil then start(seat,"basic",color,cost,nil,nil,talentGUID) return end
        local paid=strongColor(seat,nil,nil,talentGUID)
        if paid~=nil then start(seat,"strong",paid,nil,nil,nil,talentGUID) end
    end
end

local function syncSession(s,seat)
    if not liveSession(s) then return end
    if seat==nil or s.seatPos~=seat or not talentInPlay(seat,s.talentGUID) then
        closeSession(s,true)
        return
    end
    local copy=maximalEntitlement(seat,s.talentGUID)
    if (s.copy~=nil and (copy==nil or s.copy.count~=copy.count
        or s.copy.powered~=(copy.powered==true) or s.copy.sourceGUID~=copy.sourceGUID))
        or (s.mode=="ancients" and s.copy==nil and copy~=nil) then
        closeSession(s,true)
        return
    end
    if s.mode=="ancients" then
        if s.woundPending then return end
        local order=ancientsOrder(seat,s.talentGUID,s.cardGUID)
        local index=nil
        for i,guid in ipairs(order) do if guid==s.cardGUID then index=i break end end
        if index==nil and s.cardGUID~=nil then returnPreview(s,false) end
        s.order=order
        s.index=index or 1
        if #order==0 then
            -- A committed partial combination may wait for an offer refill
            -- or remaining payment, but must retain already-paid loans.
            if s.used==0 then closeSession(s,true) end
        elseif s.cardGUID==nil then
            borrow(s,1)
        else
            ensureControls(s)
        end
        return
    end
    if s.mode=="basic" or s.mode=="tome" then
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

function magicTalentSync()
    if gStates==nil or gStates.firstStarted~=true then return end
    local seat=currentSeat()
    -- Reconcile existing loans first, then offer unreserved cards to sources
    -- in stable GUID order. Closing one source cannot close another.
    for _,s in ipairs(sessionList()) do syncSession(s,seat) end
    if seat==nil then return end
    for _,guid in ipairs(talentsInPlay(seat)) do startSource(seat,guid) end
end

-- Committed physical loans occupy their original offer slot until returned.
-- Reflow may update the saved home, never move the active Spell itself.
function magicTalentOfferLoanHomes()
    local homes={}
    for _,s in ipairs(sessionList()) do
        for guid,home in pairs(s.loans or {}) do homes[guid]=home end
        if s.mode=="basic" and s.cardGUID~=nil and s.home~=nil
            and paymentStillOnSpell(s) then homes[s.cardGUID]=s.home end
    end
    return homes
end

-- Return uncommitted previews before the offer's grid counts/moves cards.
function magicTalentOfferWillChange()
    for _,s in ipairs(sessionList()) do
        if s.cardGUID~=nil and not (s.mode=="basic" and paymentStillOnSpell(s)) then
            returnPreview(s,true)
        end
    end
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
    local s=cardSession(obj.guid)
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
    if next(sessions())~=nil or #talentsInPlay(currentSeat())>0 then magicTalentScheduleCheck(obj.guid) end
end

function magicTalentRestoreOnLoad()
    if next(sessions())==nil then return end
    for _,s in ipairs(sessionList()) do
        if not talentInPlay(s.seatPos,s.talentGUID)
            or (s.cardGUID~=nil and getObjectFromGUID(s.cardGUID)==nil) then
            closeSession(s,true)
        elseif s.cardGUID~=nil then
            bumpBrowse(s)
            controls(s)
        end
    end
    magicTalentScheduleCheck()
end
