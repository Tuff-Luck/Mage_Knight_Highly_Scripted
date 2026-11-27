-- Unit scan passes. Read live activation history and paid abilities; keep scan order,
-- shared records and final publication with the coordinator.
local M={}
local resourceOps=require("PlayingGame.PlayerBoard.ResourceTracker.Core.ResourceOperations")
local terrainPolicy=require("PlayingGame.PlayerBoard.ResourceTracker.Cards.TerrainModifiers")
local highlightPolicy=require("PlayingGame.PlayerBoard.ResourceTracker.Core.HighlightPolicy")
local effectRecords=require("PlayingGame.PlayerBoard.ResourceTracker.Combat.EnemyEffectRecords")

function M.process(context)
    local seatPos, cards, records = context.seatPos, context.cards, context.records
    local objects, activations, unitState = context.objects, context.activations, context.unitState
    local unitSiteMode, unitSite, chosenSiteUnit = context.unitSiteMode, context.unitSite, context.chosenSiteUnit
    local unitPaymentMana, unitCombatBoost, allUnitResistances = context.unitPaymentMana, context.unitCombatBoost, context.allUnitResistances
    local combatCalcOn, combatConfig, trackerPrivate = context.combatCalcOn, context.combatConfig, context.trackerPrivate
    local unitResourceDefinitions, cardPosture, clearHighlight = context.unitResourceDefinitions, context.cardPosture, context.clearHighlight
    local trackerChoiceScores, removeChoiceButtons, unitManaCounts = context.trackerChoiceScores, context.removeChoiceButtons, context.unitManaCounts
    local unitManaDecision, combatOneUnitSelect, combatUnitSitePermits = context.unitManaDecision, context.combatOneUnitSelect, context.combatUnitSitePermits
    local showUnitAbilityButtons, unitAbilityPaid, addResourceAmounts = context.showUnitAbilityButtons, context.unitAbilityPaid, context.addResourceAmounts
    local totals, current, setHighlight = context.totals, context.current, context.setHighlight
    local deferredUnfortifiedUnitEffects, unitAbilityTargetKey = context.deferredUnfortifiedUnitEffects, context.unitAbilityTargetKey
    local combatEffectChosenEnemy, footprint, monsters = context.combatEffectChosenEnemy, context.footprint, context.monsters
    local combatEffectTargetEligible, enemyEffects = context.combatEffectTargetEligible, context.enemyEffects
    -- Unit activation is historical: a Command token may stay on the card for
    -- the entire round, or be moved away by an ability. Only a Command move
    -- during THIS turn creates an entry, never a static token found on load.
    -- Read only released mana physically over each Unit; inventory mana does
    -- not pay costs. Familiar crystals are a persistent modifier, not a cost.
    local howlOwner=gStates~=nil and gStates.doingTheRounds
        and gStates.doingTheRounds["a92d73"] or nil
    local howlPenalty=howlOwner~=nil and howlOwner~=gStates.turnNumber
        and (gStates.soloCoop==nil or gStates.soloCoop["a92d73"]~=true)
    -- Call to Arms uses the original Unit card temporarily positioned by
    -- the offer browser. It gains a normal Unit activation without a Command
    -- slot only when the basic white Spell was actually paid and played.
    local offeredUnit=callOfferBorrowedUnitForSeat~=nil
        and callOfferBorrowedUnitForSeat(seatPos) or nil
    if offeredUnit~=nil then
        -- Call to Arms grants an activation without a Command token. Keep its
        -- abilities and buttons, but never highlight the borrowed Unit card.
        trackerPrivate.unitHighlightBlocked[offeredUnit.guid]=true
        clearHighlight(offeredUnit.guid)
        local spellRecord=records["2eb8e8"]
        local unitGUID=offeredUnit.guid
        local paid=spellRecord~=nil and spellRecord.complete==true
            and spellRecord.powered~=true and spellRecord.resources~=nil
        if paid and unitResourceDefinitions[unitGUID]~=nil then
            objects[unitGUID]=offeredUnit
            local activation=activations[unitGUID]
            if activation==nil or activation.callOffer~=true then
                local abilities=unitResourceDefinitions[unitGUID]
                local scores=trackerChoiceScores(unitGUID,seatPos)
                local chosen,best=1,-math.huge
                for i,ability in ipairs(abilities) do
                    if ability.manaCost==nil then
                        local score=scores[ability.key] or 0
                        if score>best then chosen,best=i,score end
                    end
                end
                activations[unitGUID]={seatPos=seatPos,callOffer=true,
                    choice=chosen,selected=abilities.multi==true and {} or nil}
            end
        elseif activations[unitGUID]~=nil and activations[unitGUID].callOffer then
            removeChoiceButtons(offeredUnit)
            activations[unitGUID]=nil
        end
    end
    -- A flipped attached Courage banner explicitly authorises the Unit to
    -- ready once this round. The broken banner authorises every used Unit.
    -- unitHistory owns the actual Command move, extra activation and undo;
    -- simply flipping a card never creates free Attack or Block resources.
    if not combatCalcOn and unitState~=nil then
        gStates.unitReadyLinks=gStates.unitReadyLinks or {}
        local byUnit=unitState.bannersByUnit or {}
        for unitGUID,banners in pairs(byUnit) do
            local courage=banners["Banner of Courage"]
            if courage~=nil and courage.faceDown and
                gStates.unitReadyLinks[courage.guid]==nil then
                unitHistoryReadyLink(courage.guid,unitGUID,seatPos,nil)
            end
        end
        local courageUses=trackerPrivate.bannerEffectUses().courage
        for _,card in ipairs(cards) do
            local data=gameCards[card.guid]
            if data~=nil and data.resourceKey=="artifactBannerCourage"
                and trackerPrivate.bannerStrongActive(card)
                and cardPosture(card)=="upright" then
                -- Capture eligible spent Units at the moment the Banner breaks.
                -- Spent Units appearing later in this Round are never added.
                if courageUses[card.guid]==nil then
                    local eligible={}
                    for index,entry in ipairs(unitState.units) do
                        if not entry.ready then
                            eligible[#eligible+1]={key=card.guid.."#ready"..index,
                                guid=entry.guid}
                        end
                    end
                    courageUses[card.guid]={eligible=eligible}
                end
                for _,entry in ipairs(courageUses[card.guid].eligible) do
                    -- The link, not a stale cached boolean, is authoritative.
                    -- A Break toggle off/on restores only the original eligible
                    -- Units, never Units spent after the first Break.
                    if gStates.unitReadyLinks[entry.key]==nil then
                        unitHistoryReadyLink(entry.key,entry.guid,seatPos,nil)
                    end
                end
            end
        end
    end
    local selectedUnitAttacks={}
    local activationByRecordKey={}
    local shocktroopsBoosts=0
    local attackTransforms={}
    local transformingUnits={}
    unitHistoryValidSources(seatPos)
    for unitGUID,currentActivation in pairs(activations) do
      if currentActivation.seatPos==seatPos then
       for useIndex,activation in ipairs(unitHistoryUses(unitGUID,currentActivation)) do
        if activation.priorTurnSpent~=true then
        local recordKey=unitHistoryKey(unitGUID,useIndex)
        activationByRecordKey[recordKey]=activation
            local unit=objects[unitGUID]
            local abilities=trackerPrivate.unitAbilitiesFor(unitGUID,unitState,seatPos)
            if unit~=nil and abilities~=nil then
                if unitState==nil then unitState=unitLayoutResourceState(seatPos) end
                if unitState==nil then error("Unable to read Unit resource state.",2) end
                local unwounded=true
                for _,entry in ipairs(unitState.units) do
                    if entry.guid==unitGUID then unwounded=entry.unwounded break end
                end
                local counts=activation.frozenCounts
                    or unitManaCounts(unit,seatPos,unitPaymentMana)
                if activation.frozenCounts==nil then
                    activation.lastCounts=unitHistoryCopyCounts(counts)
                end
                local decision=unitManaDecision(unit,abilities,activation,counts)
                local moveRole=combatConfig.unitMoveRole(recordKey,false)
                local deniedCombat=combatConfig.unitCombatBlocked(unit,abilities,useIndex)
                    and unitHistoryDecisionHasCombat(abilities,decision,moveRole)
                if activation.callOffer and unitSiteMode=="one"
                    and chosenSiteUnit==nil then
                    chosenSiteUnit=unitGUID
                    combatOneUnitSelect(seatPos,unitSite,unitGUID)
                end
                local sitePermits=combatUnitSitePermits(unitSiteMode,
                    unitState.bondsUnitGUID,chosenSiteUnit,unitGUID,false)
                if unitHistorySelectedNumber(unitGUID)==useIndex then
                    if sitePermits then
                        showUnitAbilityButtons(unit,abilities,activation,true,decision,useIndex)
                    else
                        removeChoiceButtons(unit)
                    end
                end
                local selected=decision.index~=nil and abilities[decision.index] or nil
                if (unwounded or activation.frozenCounts~=nil) and sitePermits then
                    local crystalCounts=selected~=nil and selected.bonusColor~=nil
                        and unitManaCounts(unit,seatPos,unitPaymentMana,true) or nil
                    -- Record the role of a genuinely selected, paid Move even
                    -- when a prior combat use makes this activation invalid.
                    -- Otherwise removing the enemy could silently make it legal.
                    if selected~=nil and (tonumber(selected.move) or 0)>0
                        and unitAbilityPaid(selected,counts) then
                        combatConfig.unitMoveRole(recordKey,true)
                    end
                    local resources=not deniedCombat and selected~=nil
                        and trackerPrivate.unitEffects.unitAbilityResources(selected,counts,crystalCounts,
                            unitCombatBoost,howlPenalty) or nil
                    local banners=unitState~=nil and unitState.bannersByUnit~=nil
                        and unitState.bannersByUnit[unitGUID] or nil
                    local gloryAttached=banners~=nil and banners["Banner of Glory"]~=nil
                    local gloryGlobal=(function()
                            for _,artifact in ipairs(cards) do
                                local data=gameCards[artifact.guid]
                                if data~=nil and data.resourceKey=="artifactBannerGlory"
                                    and trackerPrivate.bannerStrongActive(artifact)
                                    and cardPosture(artifact)=="upright" then return true end
                            end
                            return false
                        end)()
                    local hasGlory=gloryAttached or gloryGlobal
                    local gloryCombat
                    resources,gloryCombat=trackerPrivate.unitEffects.applyGlory(resources,hasGlory)
                    local result={guid=recordKey,sourceObjectGUID=unitGUID,
                        activationIndex=useIndex,kind="unit",known=true,
                        complete=not deniedCombat and (selected~=nil and unitAbilityPaid(selected,counts)
                            or abilities.multi==true and next(decision.selected or {})~=nil),
                        resources=resources,powered=false,links={},
                        swiftDouble=selected~=nil and selected.countsTwiceVsSwift==true or nil,
                        gloryFame=gloryCombat and (gloryGlobal and "global" or "attached") or nil,
                        fameRep=selected~=nil and selected.fameRep or nil}
                    result.fameRep=result.complete and result.fameRep or nil
                    addResourceAmounts(result,totals)
                    result.status=highlightPolicy.contribution(result.contributes)
                    records[recordKey]=result
                    current[unitGUID]=true
                    if unitHistorySelectedNumber(unitGUID)==useIndex then
                        setHighlight(unit,result.status,false)
                    end
                    if selected~=nil and selected.terrainEffects~=nil and result.complete then
                        terrainPolicy.stage(result,selected.terrainEffects,gStates.dayRound)
                    end
                    if selected~=nil and selected.boostOtherUnits and result.complete then
                        shocktroopsBoosts=shocktroopsBoosts+1
                    end
                    if selected~=nil and selected.grantUnitResistances and result.complete then
                        allUnitResistances=true
                    end
                    if selected~=nil and selected.attackTransform~=nil and result.complete then
                        attackTransforms[selected.attackTransform]=true
                        transformingUnits[recordKey]=selected.attackTransform
                    end
                    if result.complete then
                        local picked={}
                        if abilities.multi==true then
                            for index,ability in ipairs(abilities) do
                                if decision.selected~=nil and decision.selected[index]==true then
                                    picked[#picked+1]={index=index,ability=ability}
                                end
                            end
                        elseif selected~=nil then
                            picked[1]={index=decision.index,ability=selected}
                        end
                        for _,pickedAbility in ipairs(picked) do
                            local index,ability=pickedAbility.index,pickedAbility.ability
                            if ability.enemyEffect~=nil or ability.targetableEnemy==true then
                                local sourceKey=unitAbilityTargetKey(unitGUID,index,ability,useIndex)
                                if sourceKey~=unitGUID then
                                    effectRecords.register(result,sourceKey)
                                end
                                -- Every enemy-targeting Unit ability starts on a nearby
                                -- enemy, even if it is a non-resource/manual effect.
                                -- An explicit retarget wins over the nearest default.
                                -- Keep effect-only arrows separate from the Unit's
                                -- numeric Attack/Block source to prevent stale locks.
                                if ability.enemyEffect~=nil
                                    and ability.enemyEffect.noAttackUnfortified==true then
                                    deferredUnfortifiedUnitEffects[#deferredUnfortifiedUnitEffects+1]={
                                        sourceKey=sourceKey,unit=unit,unitGUID=unitGUID,
                                        result=result,spec=ability.enemyEffect}
                                else
                                    local target=combatEffectChosenEnemy(sourceKey,footprint(unit),
                                        monsters,combatEffectTargetEligible(ability.enemyEffect))
                                    if target~=nil then
                                        if ability.enemyEffect~=nil then
                                            combatEffectAdd(enemyEffects,target.guid,unitGUID,ability.enemyEffect,sourceKey)
                                            effectRecords.link(result,sourceKey~=unitGUID and sourceKey or nil,
                                                target.guid,{})
                                            -- The Unit is spent for Fear rather than
                                            -- its printed ability. Fame requires a legal
                                            -- enemy target; Arcane Immunity negates it.
                                            if ability.bannerFear and not combatEffectImmune(target.guid) then
                                                result.fameRep={fame=1}
                                                result.contributes=true
                                                highlightPolicy.linkedSource(result)
                                                if unitHistorySelectedNumber(unitGUID)==useIndex then
                                                    setHighlight(unit,result.status,false)
                                                end
                                            end
                                        end
                                        if ability.enemyEffect==nil and sourceKey~=unitGUID then
                                            effectRecords.target(result,sourceKey,target.guid)
                                        end
                                    end
                                end
                            end
                        end
                    end
                    if result.contributes then
                        selectedUnitAttacks[#selectedUnitAttacks+1]=recordKey
                    end
                end
            end
        end -- Earlier-round spent Command: no active source this turn.
       end
      end
    end
    -- Shocktroops' Ranged Attack 1 also boosts ALL other activated Units'
    -- Attacks, even if their ability was activated earlier this turn.
    if shocktroopsBoosts>0 then
        for _,unitGUID in ipairs(selectedUnitAttacks) do
            local record=records[unitGUID]
            local baseGUID=unitHistorySourceBase(unitGUID)
            local use=activationByRecordKey[unitGUID]
            local selected=use~=nil and unitResourceDefinitions[baseGUID]
                and unitResourceDefinitions[baseGUID][use.choice or 1] or nil
            local ownBoost=selected~=nil and selected.boostOtherUnits and 1 or 0
            local bonus=shocktroopsBoosts-ownBoost
            if bonus>0 and record~=nil and record.resources~=nil then
                local amounts={}
                for category,value in pairs(record.resources) do
                    local family=resourceOps.splitKey(category)
                    if type(value)=="number" and (family=="attack"
                        or family=="ranged" or family=="siege") then
                        amounts[category]=bonus
                    end
                end
                if next(amounts)~=nil then resourceOps.addAmounts(record,totals,amounts) end
            end
        end
    end
    return unitState,chosenSiteUnit,allUnitResistances,attackTransforms,transformingUnits
end

function M.resolveUnfortifiedTargets(context)
    local deferredUnfortifiedUnitEffects, monsters, enemyEffects = context.deferredUnfortifiedUnitEffects, context.monsters, context.enemyEffects
    local ignoreSiteFortifications, combatAssignmentState, combatEffectChosenEnemy = context.ignoreSiteFortifications, context.combatAssignmentState, context.combatEffectChosenEnemy
    local footprint = context.footprint
    -- Illusionists: now that every independent enemy effect has been read,
    -- evaluate *effective* Fortification rather than the printed token alone.
    -- Reevaluate legal locks each scan so an expired Remove Fortification
    -- effect cannot leave an invalid target or a misleading attack arrow.
    for _,pending in ipairs(deferredUnfortifiedUnitEffects) do
        local eligible={}
        for guid,enemy in pairs(monsters) do
            if enemy.is_face_down~=true
                and resourceCardsEnemyEffectivelyUnfortified(guid,enemyEffects,
                    ignoreSiteFortifications) then
                eligible[guid]=true
            end
        end
        attackAssignmentsPruneSourceTargets(pending.sourceKey,eligible)
        local locked=combatAssignmentState.targets[pending.sourceKey]
        if locked~=nil and eligible[locked]~=true then
            combatAssignmentState.targets[pending.sourceKey]=nil
            combatAssignmentState.explicit[pending.sourceKey]=nil
        end
        local target=combatEffectChosenEnemy(pending.sourceKey,footprint(pending.unit),
            monsters,function(_,guid) return eligible[guid]==true end)
        if target~=nil then
            combatEffectAdd(enemyEffects,target.guid,pending.unitGUID,pending.spec,pending.sourceKey)
            effectRecords.link(pending.result,pending.sourceKey,target.guid,{})
        end
    end
end

function M.markTransforms(context)
    local transformingUnits, trackerPrivate, resourceCardsRawValue = context.transformingUnits, context.trackerPrivate, context.resourceCardsRawValue
    local totals, records, objects = context.totals, context.records, context.objects
    local setHighlight = context.setHighlight
    -- Global Altem effects contribute when they upgrade an Attack, including
    -- a value entered manually into the Resource Tracker.
    local tracker=gStates.resourceTracker or {}
    for sourceKey,mode in pairs(transformingUnits) do
        local affected=false
        for _,family in ipairs(trackerPrivate.attackTransformFamilies) do
            for _,field in ipairs(trackerPrivate.attackTransformFields) do
                if (mode=="coldFire" and field~="iceFire")
                    or (mode=="siege" and family~="siege") then
                    if resourceCardsRawValue(tracker,totals,family,field)~=0 then
                        affected=true
                        break
                    end
                end
            end
            if affected then break end
        end
        local record=records[sourceKey]
        if record~=nil then
            record.contributes=affected
            record.status=highlightPolicy.contribution(affected)
            local unitGUID=unitHistorySourceBase(sourceKey)
            -- Only the Command's displayed use owns the physical highlight;
            -- earlier uses retain their own record for History and Undo.
            if unitHistorySelectedNumber(unitGUID)==record.activationIndex then
                setHighlight(objects[unitGUID],record.status,false)
            end
        end
    end
end

function M.payReadyInfluence(context)
    local records, totals = context.records, context.totals
    -- Pay for Ready links from the available Influence pool in creation
    -- order. If a resource source is later undone, retire unaffordable
    -- links newest-first, along with their dependent Unit activations.
    local ruthlessReadySpent=0
    local ruthlessReadyBySource={}
    local readyNeedsRescan=false
    local readyPayments={}
    local actionSources={}
    for guid,record in pairs(records) do
        if record.influenceAction then actionSources[#actionSources+1]=guid end
    end
    table.sort(actionSources)
    for key,link in pairs(gStates.unitReadyLinks or {}) do
        local owner=key:match("^([0-9a-f]+)#ready%d+$")
        local record=owner~=nil and records[owner] or nil
        local data=owner~=nil and gameCards[owner] or nil
        local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
        local unit=link~=nil and gameCards[link.unitGUID] or nil
        if record~=nil and record.complete and record.powered and rule~=nil
            and rule.readyWithInfluence~=nil and unit~=nil
            and (not rule.readyWithInfluence.requiresAction or record.influenceAction)
            and (rule.readyWithInfluence.maxUses==nil
                or (tonumber(key:match("#ready(%d+)$")) or 0)<=rule.readyWithInfluence.maxUses)
            and (tonumber(unit.level) or 99)<=rule.readyWithInfluence.maxLevel then
            readyPayments[#readyPayments+1]={key=key,owner=owner,
                cost=(tonumber(unit.level) or 0)*rule.readyWithInfluence.costPerLevel,
                number=tonumber(key:match("#ready(%d+)$")) or 0}
        end
    end
    table.sort(readyPayments,function(a,b)
        if a.owner~=b.owner then return a.owner<b.owner end
        return a.number<b.number
    end)
    local generatedInfluence=tonumber(totals.influence) or 0
    local availableInfluence=resourceOps.influenceBudget(totals,gStates.resourceTracker)
    for _,payment in ipairs(readyPayments) do
        if gStates.unitReadyLinks[payment.key]~=nil then
            if ruthlessReadySpent+payment.cost<=availableInfluence then
                ruthlessReadySpent=ruthlessReadySpent+payment.cost
                ruthlessReadyBySource[payment.owner]=
                    (ruthlessReadyBySource[payment.owner] or 0)+payment.cost
            else
                unitHistoryCancelReadySource(payment.key)
                readyNeedsRescan=true
            end
        end
    end
    for owner,spent in pairs(ruthlessReadyBySource) do
        if records[owner]~=nil then records[owner].readyInfluenceSpent=spent end
    end
    totals.influence=generatedInfluence-ruthlessReadySpent
    -- Readying and Heal share a single pool; the already-linked Ready gets
    -- priority. Trim unavailable Heal conversions instead of creating points.
    for _,guid in ipairs(actionSources) do
        local record=records[guid]
        local data=gameCards[guid]
        local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
        local selected=(gStates.startingCardSelections or {})[guid]
        if rule~=nil and rule.influenceAction~=nil and selected~=nil then
            local cost=rule.influenceAction.healCost
            local requested=math.max(0,math.floor(tonumber(selected.influenceHealing) or 0))
            local budget=resourceOps.influenceBudget(totals,gStates.resourceTracker)
            local healing=math.min(requested,math.max(0,math.floor(budget/cost)))
            selected.influenceHealing=healing
            record.influenceHealing=healing
            totals.influence=totals.influence-healing*cost
            totals.healing=(totals.healing or 0)+healing
        end
    end
    -- The combat calculator reads individual records rather than the tracker
    -- total. Allocate the same payments there so Ready/Heal cannot also Block.
    -- Negative manual adjustments also represent unavailable points.
    -- Positive adjustments can pay for effects, but never create a
    -- targetable physical combat source.
    resourceOps.allocateInfluenceSpend(records,generatedInfluence-totals.influence
        +math.max(0,-resourceOps.influenceAdjustment(gStates.resourceTracker)))
    return ruthlessReadySpent,readyNeedsRescan,#actionSources>0
end

return M
