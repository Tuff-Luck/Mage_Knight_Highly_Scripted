-- Ordered physical mana reservation and Action/Skill link resolution. Preserves highest eligible card selection, separate casting and effect roles, and optional terrain mana.
local M={}

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
    local manaByObject,manaBySkill,manaByCard=
        resolveManaSkillLinks(skills,manaObjects,cards,footprints,placements)
    local skillLinksByTarget,skillLinksBySkill,sidewaysSkillMana=
        resolveSkillCardLinks(skills,skillTargets,footprints,manaObjects,placements,manaByObject,unitState)
    local powered,usedMana,spellCastingPaid,powerManaColorsByCard={}, {}, {}, {}
    -- Some cards require a separate coloured mana payment to choose their
    -- effect. Record those candidates before deciding which mana powers the
    -- strong side; one token can never fill both roles.
    local effectManaByCard,specialPaymentByCard={},{}
    for _,card in ipairs(cards) do
        local data=gameCards[card.guid]
        local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
        if rule~=nil and rule.effectManaChoice~=nil then
            specialPaymentByCard[card.guid]=rule.effectManaChoice
        end
    end
    local function spendMana(card,color,manaGUID)
        -- Never record an illegal Daytime Black payment through the separate
        -- spell-effect or mana-conversion paths.
        if color=="Black" and not resourceCardsBlackAllowed() then return end
        local data=gameCards[card.guid]
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
            if color=="Black" then
                powered[card.guid]=true
                powerManaColorsByCard[card.guid]=powerManaColorsByCard[card.guid] or {}
                powerManaColorsByCard[card.guid][color]=true
            end
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
            local color=manaColor(mana)
            if color~=nil then
                local best=trackerPrivate.bestManaCard(mana,cards,footprints,function(card)
                    return cardPosture(card)=="upright" and card.is_face_down~=true
                        and (matchesCardMana(card,color)
                            or (specialPaymentByCard[card.guid]~=nil
                                and (specialPaymentByCard[card.guid].colors[color]~=nil
                                    or (color=="Gold" and resourceCardsGoldAllowed()))))
                end)
                if best~=nil then spendMana(best,color,mana.guid) end
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
        if wildcard or next(options)~=nil then powered[guid]=true end
    end
    local links,boostBy,boostSource,discarded,hasDiscard,linkedCardBySource,
        repeatByTarget,discardBoostBySource=
        resolveActionLinks(cards,wounds,footprints,powered,skillLinksByTarget)
    resourceCardsMaximalEffectSyncMarks(seatPos,cards,repeatByTarget,discarded,hasDiscard)
    -- Extra terrain mana is an optional physical payment, separate from the
    -- mana that powers the strong action. Never reuse a claimed mana object.
    local extraTerrainManaByCard,extraTerrainManaByObject={},{}
    for _,mana in ipairs(manaObjects) do
        if placements[mana.guid]=="play" and usedMana[mana.guid]==nil
            and manaByObject[mana.guid]==nil and sidewaysSkillMana[mana.guid]==nil then
            local color=manaColor(mana)
            local best=trackerPrivate.bestManaCard(mana,cards,footprints,function(card)
                local data=gameCards[card.guid]
                local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
                local spec=rule~=nil and rule.extraTerrainMana or nil
                return spec~=nil and spec.color==color
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
    return manaByObject, manaBySkill, manaByCard, skillLinksByTarget, skillLinksBySkill, sidewaysSkillMana, powered, usedMana, spellCastingPaid, powerManaColorsByCard, effectManaByCard, links, boostBy, boostSource, discarded, hasDiscard, linkedCardBySource, repeatByTarget, discardBoostBySource, extraTerrainManaByCard, extraTerrainManaByObject
end

return M
