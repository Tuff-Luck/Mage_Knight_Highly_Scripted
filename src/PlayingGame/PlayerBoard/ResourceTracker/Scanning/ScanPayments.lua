-- Ordered physical mana reservation and Action/Skill link resolution. Preserves highest eligible card selection, separate casting and effect roles, and optional terrain mana.
local M={}
local payment=require("PlayingGame.PlayerBoard.ResourceTracker.Scanning.ManaPayments")

function M.resolve(context)
    local seatPos, cards, wounds = context.seatPos, context.cards, context.wounds
    local skills, manaObjects, footprints = context.skills, context.manaObjects, context.footprints
    local placements, unitState, resolveManaSkillLinks = context.placements, context.unitState, context.resolveManaSkillLinks
    local resolveSkillCardLinks, trackerPrivate, cardPosture = context.resolveSkillCardLinks, context.trackerPrivate, context.cardPosture
    local matchesCardMana, manaColor, effectManaPossibilities = context.matchesCardMana, context.manaColor, context.effectManaPossibilities
    local resolveActionLinks = context.resolveActionLinks
    -- Wounds may be Skill targets, but are not ordinary Action-link candidates.
    local skillTargets={}
    for _,card in ipairs(cards) do skillTargets[#skillTargets+1]=card end
    for _,wound in ipairs(wounds) do skillTargets[#skillTargets+1]=wound end

    -- First reserve conversion mana (Polarization), then sideways-skill mana,
    -- so one physical mana never powers two separate interactions.
    table.sort(cards,function(a,b) return a.guid<b.guid end)
    -- Cards already present when opening a saved/minimized tracker have no
    -- reliable order; give them one shared ordinal instead of inventing one.
    -- Subsequent real zone entries are recorded immediately at entry time.
    if not context.linkOnly then
        gStates.resourceCardPlayOrder=gStates.resourceCardPlayOrder or {}
        gStates.resourceCardPlaySerial=gStates.resourceCardPlaySerial or 0
        local missingOrder=false
        for _,card in ipairs(cards) do
            if gStates.resourceCardPlayOrder[card.guid]==nil then
                missingOrder=true break
            end
        end
        if missingOrder then
            gStates.resourceCardPlaySerial=gStates.resourceCardPlaySerial+1
            for _,card in ipairs(cards) do
                if gStates.resourceCardPlayOrder[card.guid]==nil then
                    gStates.resourceCardPlayOrder[card.guid]=gStates.resourceCardPlaySerial
                end
            end
        end
    end
    -- Probe with ordinary rules only when Mana Storm is physically upright.
    -- This reuses the real allocation and stronger-link resolver, including
    -- Conversion, Concentration/Will Focus and a granted stronger side.
    local stormActive,stormProtected=false,{}
    if context.manaStormEnabled and not context.stormProbe then
        for _,card in ipairs(cards) do
            if card.guid=="e2b570" and card.is_face_down~=true and cardPosture(card)=="upright" then
                local probe={}
                for key,value in pairs(context) do probe[key]=value end
                probe.stormProbe=true
                probe.linkOnly=true
                stormActive,stormProtected=M.resolve(probe)
                break
            end
        end
    end
    local paymentColor=manaColor
    if stormActive then
        paymentColor=function(mana)
            return payment.stormColor(manaColor(mana),mana.type=="Dice",true)
        end
    end
    local manaByObject,manaBySkill,manaByCard=
        resolveManaSkillLinks(skills,manaObjects,cards,footprints,placements)
    local skillReserved=manaByObject
    if stormActive and next(stormProtected)~=nil then
        skillReserved={}
        for guid,link in pairs(manaByObject) do skillReserved[guid]=link end
        for guid in pairs(stormProtected) do skillReserved[guid]=true end
    end
    local skillLinksByTarget,skillLinksBySkill,sidewaysSkillMana=
        resolveSkillCardLinks(skills,skillTargets,footprints,manaObjects,placements,skillReserved,unitState,paymentColor)
    local function colorForCard(mana,card)
        if card.guid=="e2b570" then return manaColor(mana) end
        return paymentColor(mana)
    end
    local ordinarySpellMana={}
    local powered,usedMana,spellCastingPaid,powerManaColorsByCard={}, {}, {}, {}
    -- Some cards require a separate coloured mana payment to choose their
    -- effect. Record those candidates before deciding which mana powers the
    -- strong side; one token can never fill both roles.
    local effectManaByCard,specialPaymentByCard,freeCastSides={},{},{}
    for _,card in ipairs(cards) do
        if not context.directOnly and magicTalentOfferCastSide~=nil then
            local side=magicTalentOfferCastSide(seatPos,card.guid)
            if side~=nil then freeCastSides[card.guid]=side end
        end
        local data=gameCards[card.guid]
        local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
        if rule~=nil and rule.effectManaChoice~=nil then
            specialPaymentByCard[card.guid]=rule.effectManaChoice
        end
    end
    local function ancientsMana(card,color)
        local data=gameCards[card.guid]
        return data~=nil and data.resourceKey=="bloodOfAncients"
            and (color=="Red" or color=="Blue" or color=="White" or color=="Green"
                or payment.wildcard(color,resourceCardsGoldAllowed()))
    end
    local function spendMana(card,color,manaGUID)
        -- Never record an illegal Daytime Black payment through the separate
        -- spell-effect or mana-conversion paths.
        if color=="Black" and not resourceCardsBlackAllowed() then return end
        local data=gameCards[card.guid]
        -- Free casting does not consume ordinary colour or Black mana.
        -- Extra printed effect payments still belong to their own role.
        if freeCastSides[card.guid]~=nil then
            local spec=specialPaymentByCard[card.guid]
            if spec==nil or (spec.colors[color]==nil
                and not payment.wildcard(color,resourceCardsGoldAllowed())) then return end
            local candidates=effectManaByCard[card.guid] or {}
            candidates[#candidates+1]={guid=manaGUID,color=color}
            effectManaByCard[card.guid]=candidates
            usedMana[manaGUID]=card.guid
            return
        end
        if ancientsMana(card,color) then
            -- A basic colour is a purchase cost, not necessarily Red power.
            usedMana[manaGUID]=card.guid
            if color=="Red" or payment.wildcard(color,resourceCardsGoldAllowed()) then
                powered[card.guid]=true
                powerManaColorsByCard[card.guid]=powerManaColorsByCard[card.guid] or {}
                powerManaColorsByCard[card.guid][color]=true
            end
            return
        end
        if data~=nil and data.cardType=="Spell" and color~="Black"
            and matchesCardMana(card,color) then
            spellCastingPaid[card.guid]=true
        end
        if specialPaymentByCard[card.guid]~=nil then
            local candidates=effectManaByCard[card.guid] or {}
            candidates[#candidates+1]={guid=manaGUID,color=color}
            effectManaByCard[card.guid]=candidates
        elseif data~=nil and data.cardType=="Spell" then
            -- Casting mana selects the normal Spell; only Black powers
            -- the stronger effect and may activate Mana Overload.
            local candidates=ordinarySpellMana[card.guid] or {}
            candidates[#candidates+1]={guid=manaGUID,color=color}
            ordinarySpellMana[card.guid]=candidates
            local cast,strong=payment.ordinarySpellRoles(candidates,resourceCardsBlackAllowed())
            spellCastingPaid[card.guid]=cast or nil
            powered[card.guid]=strong or nil
            powerManaColorsByCard[card.guid]=strong and {Black=true} or nil
        else
            powered[card.guid]=true
            powerManaColorsByCard[card.guid]=powerManaColorsByCard[card.guid] or {}
            powerManaColorsByCard[card.guid][color]=true
        end
        usedMana[manaGUID]=card.guid
        if trackerPrivate.traceEnabled then
            trackerPrivate.traceEvent("mana.assigned",seatPos,manaGUID,
                "color="..tostring(color).." card="..card.guid)
        end
    end
    -- Mana physically on the Skill cannot also power the card directly.
    for _,mana in ipairs(manaObjects) do
        if placements[mana.guid]=="play" and manaByObject[mana.guid]==nil
            and sidewaysSkillMana[mana.guid]==nil then
            local color=paymentColor(mana)
            if color~=nil then
                local best=trackerPrivate.bestManaCard(mana,cards,footprints,function(card)
                    local color=colorForCard(mana,card)
                    if freeCastSides[card.guid]~=nil then
                        local spec=specialPaymentByCard[card.guid]
                        return cardPosture(card)=="upright" and card.is_face_down~=true
                            and spec~=nil and (spec.colors[color]~=nil
                                or payment.wildcard(color,resourceCardsGoldAllowed()))
                    end
                    return cardPosture(card)=="upright" and card.is_face_down~=true
                        and (matchesCardMana(card,color) or ancientsMana(card,color)
                            or (specialPaymentByCard[card.guid]~=nil
                                and (specialPaymentByCard[card.guid].colors[color]~=nil
                                    or payment.wildcard(color,resourceCardsGoldAllowed()))))
                end)
                if best~=nil then spendMana(best,colorForCard(mana,best),mana.guid) end
            end
        end
    end
    for _,link in pairs(manaBySkill) do
        if link.targetGUID~=nil then
            local card=getObjectFromGUID(link.targetGUID)
            if card~=nil then spendMana(card,link.converted,link.manaGUID) end
        end
    end
    -- Power the stronger side only when a complete distinct payment set is
    -- possible. Pure Magic needs effect + Blue; Mana Thunderbolt needs
    -- casting Blue/Gold + Black + a separate effect mana.
    for guid,candidates in pairs(effectManaByCard) do
        local spec=specialPaymentByCard[guid]
        local options,wildcard=effectManaPossibilities(spec,candidates,true,
            resourceCardsGoldAllowed(),resourceCardsBlackAllowed())
        if freeCastSides[guid]==nil and (wildcard or next(options)~=nil) then powered[guid]=true end
    end
    for guid,strong in pairs(freeCastSides) do
        local data=gameCards[guid]
        if data~=nil and data.cardType=="Spell" then spellCastingPaid[guid]=true end
        powered[guid]=strong
    end
    local borrowedRepeats={}
    if magicTalentOfferActionRepeat~=nil then
        for guid in pairs(freeCastSides) do
            borrowedRepeats[guid]=magicTalentOfferActionRepeat(seatPos,guid)
        end
    end
    local links,boostBy,boostSource,discarded,hasDiscard,linkedCardBySource,
        repeatByTarget,discardBoostBySource=
        resolveActionLinks(cards,wounds,footprints,powered,skillLinksByTarget,borrowedRepeats)
    if context.stormProbe then
        local active=false
        for _,card in ipairs(cards) do
            if card.guid=="e2b570" and card.is_face_down~=true and cardPosture(card)=="upright"
                and discarded[card.guid]==nil then
                active=powered[card.guid]==true or boostBy[card.guid]~=nil
                break
            end
        end
        local protected={}
        if active then
            for manaGUID,cardGUID in pairs(usedMana) do
                if cardGUID=="e2b570" or cardGUID==boostSource["e2b570"] then
                    protected[manaGUID]=true
                end
            end
        end
        return active,protected
    end
    if context.linkOnly then return repeatByTarget,discarded,hasDiscard,spellCastingPaid end
    -- A direct Maximal Effect target can be face down. Its printed effect
    -- mana remains payable even though ordinary card power is forbidden.
    -- Do not reassign a token already owned by another card or Skill.
    local repeatedManaCards={}
    for _,card in ipairs(cards) do
        local repeated=repeatByTarget[card.guid]
        if repeated~=nil and not repeated.borrowed and specialPaymentByCard[card.guid]~=nil then
            repeatedManaCards[#repeatedManaCards+1]=card
            -- The repeat source supplies the side; coloured mana on the
            -- target only selects effects, never powers that target.
            powered[card.guid]=nil
            powerManaColorsByCard[card.guid]=nil
        end
    end
    if #repeatedManaCards>0 then
        for _,mana in ipairs(manaObjects) do
            if placements[mana.guid]=="play" and usedMana[mana.guid]==nil
                and manaByObject[mana.guid]==nil and sidewaysSkillMana[mana.guid]==nil then
                local color=paymentColor(mana)
                local best=trackerPrivate.bestManaCard(mana,repeatedManaCards,footprints,function(card)
                    local spec=specialPaymentByCard[card.guid]
                    return cardPosture(card)=="upright"
                        and (spec.colors[color]~=nil or payment.wildcard(color,resourceCardsGoldAllowed()))
                end)
                if best~=nil then spendMana(best,color,mana.guid) end
            end
        end
    end
    resourceCardsMaximalEffectSyncMarks(seatPos,cards,repeatByTarget,discarded,hasDiscard)
    -- Extra terrain mana is an optional physical payment, separate from the
    -- mana that powers the strong action. Never reuse a claimed mana object.
    local extraTerrainManaByCard,extraTerrainManaByObject={},{}
    for _,mana in ipairs(manaObjects) do
        if placements[mana.guid]=="play" and usedMana[mana.guid]==nil
            and manaByObject[mana.guid]==nil and sidewaysSkillMana[mana.guid]==nil then
            local color=paymentColor(mana)
            local best=trackerPrivate.bestManaCard(mana,cards,footprints,function(card)
                local data=gameCards[card.guid]
                local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
                local spec=rule~=nil and rule.extraTerrainMana or nil
                return spec~=nil and payment.basicPayment(color,spec.color,false)
                    and extraTerrainManaByCard[card.guid]==nil
                    and (not spec.poweredOnly or powered[card.guid]==true or boostBy[card.guid]~=nil)
                    and card.is_face_down~=true and cardPosture(card)=="upright"
            end)
            if best~=nil then
                extraTerrainManaByCard[best.guid]=mana.guid
                extraTerrainManaByObject[mana.guid]=best.guid
                usedMana[mana.guid]=best.guid
            end
        end
    end
    return manaByObject, manaBySkill, manaByCard, skillLinksByTarget, skillLinksBySkill, sidewaysSkillMana, powered, usedMana, spellCastingPaid, powerManaColorsByCard, effectManaByCard, links, boostBy, boostSource, discarded, hasDiscard, linkedCardBySource, repeatByTarget, discardBoostBySource, extraTerrainManaByCard, extraTerrainManaByObject, paymentColor
end

return M
