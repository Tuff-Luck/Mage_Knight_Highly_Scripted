-- Change detection, scan publication, reward reconciliation, combat/movement refresh and departed-object cleanup. Uses live coordinator state without owning saved decisions.
local M={}

function M.publish(context)
    local seatPos, records, resourceCardsMoveRole = context.seatPos, context.records, context.resourceCardsMoveRole
    local trackerPrivate, combatEnemyInPlay, terrainModifiers = context.trackerPrivate, context.combatEnemyInPlay, context.terrainModifiers
    local terrainModifierPrecedes, totals, movementEffects = context.terrainModifierPrecedes, context.totals, context.movementEffects
    local attackTransforms, resourceCardsSyncInteractionPower, combatConfig = context.attackTransforms, context.resourceCardsSyncInteractionPower, context.combatConfig
    local current, enemyEffects, ruthlessReadySpent = context.current, context.enemyEffects, context.ruthlessReadySpent
    local ignoreSiteFortifications, unitState, cards = context.ignoreSiteFortifications, context.unitState, context.cards
    local cardPosture, preventUnitDamage, allUnitResistances = context.cardPosture, context.preventUnitDamage, context.allUnitResistances
    local heroFirstWoundIgnored, heroPsychicBlock, usesCurrentHexBlock = context.heroFirstWoundIgnored, context.heroPsychicBlock, context.usesCurrentHexBlock
    local usesCurrentHexHealing, usesSkillLocation, readyNeedsRescan = context.usesCurrentHexHealing, context.usesSkillLocation, context.readyNeedsRescan
    local refreshCombatEnemyPanel, combatMonsters, resourceCardsApplyFameRep = context.refreshCombatEnemyPanel, context.combatMonsters, context.resourceCardsApplyFameRep
    local clearHighlight, choiceButtonShown, removeChoiceButtons = context.clearHighlight, context.choiceButtonShown, context.removeChoiceButtons
    local choiceExpandedByGUID = context.choiceExpandedByGUID
    local profile
    if trackerPrivate.traceEnabled then profile=trackerPrivate.profileStart() end
    -- First recognition determines phase; later enemy arrivals do not change it.
    local moveSplit={movement=0,combat=0}
    for guid,record in pairs(records) do
        local amount=math.max(0,tonumber(record.resources~=nil and record.resources.move) or 0)
        if amount>0 then
            local role=resourceCardsMoveRole(guid,true)
            moveSplit[role]=moveSplit[role]+amount
        end
    end
    local previous=trackerPrivate.bySeat[seatPos] or {}
    local previousScan=resourceCardScanBySeat[seatPos]
    local phaseAttackPreview=combatConfig.resourceOperations~=nil
        and combatConfig.resourceOperations.previewAttackBonuses(records,attackTransforms) or {}
    local previousPreview=previousScan~=nil and previousScan.phaseAttackPreview or {}
    -- Linking/unlinking can change a card's effective resource family without
    -- a choice click. Clear only assignments whose linked resource disappeared
    -- or changed; identical copied/printed resources retain their target.
    local changedLinkedSources={}
    for guid,record in pairs(records) do
        local old=previousScan~=nil and previousScan.cards[guid] or nil
        if old~=nil then
            local before=old.shapeshiftField or old.copiedBasicField
            local after=record.shapeshiftField or record.copiedBasicField
            if before~=after and not (combatConfig.phaseObjectLocked~=nil
                and combatConfig.phaseObjectLocked(guid)) then
                local incompatible=(before~=nil and after~=nil)
                    or (before~=nil and (tonumber(record.resources~=nil and record.resources[before]) or 0)<=0)
                    or (after~=nil and (tonumber(old.resources~=nil and old.resources[after]) or 0)<=0)
                if incompatible then changedLinkedSources[#changedLinkedSources+1]=guid end
            end
        end
    end
    local previousMove=previousScan~=nil and (previousScan.totals.move or 0) or 0
    local previousSplit=previousScan~=nil and previousScan.moveSplit or nil
    local enemyStateChanged=previousScan==nil
        or previousScan.enemyPresent~=combatEnemyInPlay
    local influenceActionChanged=previousScan==nil
        or (previousScan.influenceAction==true)~=(context.influenceAction==true)
    local moveSplitChanged=previousSplit==nil
        or previousSplit.movement~=moveSplit.movement
        or previousSplit.combat~=moveSplit.combat
    table.sort(terrainModifiers,terrainModifierPrecedes)
    local prior=previousScan~=nil and previousScan.terrainModifiers or nil
    local terrainChanged=prior==nil and #terrainModifiers>0
        or prior~=nil and #prior~=#terrainModifiers
    if prior~=nil and not terrainChanged then
        for i,effect in ipairs(terrainModifiers) do
            if prior[i]~=effect then terrainChanged=true break end
        end
    end
    -- The prior candidate may have been withheld while reconciling Unit history.
    local totalsChanged=previousScan==nil or combatConfig.scanAwaitingRescan==true
        or (previousScan.totals.recruitDiscount or 0)~=(totals.recruitDiscount or 0)
    if not totalsChanged then
        for category in pairs(trackerPrivate.totalsKeys) do
            if (previousScan.totals[category] or 0)~=(totals[category] or 0)
                or (previousPreview[category] or 0)~=(phaseAttackPreview[category] or 0) then
                totalsChanged=true
                break
            end
        end
    end
    local priorMovement=previousScan~=nil and previousScan.movementEffects or nil
    local movementChanged=priorMovement==nil
        or priorMovement.jumpTwoSpaces~=movementEffects.jumpTwoSpaces
        or priorMovement.ignoreRampagers~=movementEffects.ignoreRampagers
        or (priorMovement.windFlightMax or 0)~=movementEffects.windFlightMax
        or (priorMovement.singleSpaceDiscount or 0)~=movementEffects.singleSpaceDiscount
    local previousTransform=previousScan~=nil and previousScan.attackTransforms or nil
    local transformChanged=previousTransform==nil
        or (previousTransform.coldFire==true)~=(attackTransforms.coldFire==true)
        or (previousTransform.siege==true)~=(attackTransforms.siege==true)
    -- The normal recruitment discount cannot coexist with the stronger
    -- side of the same card. Remove its pending event if the side changes.
    for guid,selected in pairs(gStates.startingCardSelections or {}) do
        local data=gameCards[guid]
        local record=records[guid]
        if data~=nil and data.resourceKey=="ruthlessCoercion"
            and record~=nil and record.powered==true then
            selected.recruited=nil
        end
    end
    local fameTotal,repTotal=0,0
    for _,record in pairs(records) do
        if record.fameRep~=nil then
            fameTotal=fameTotal+(record.fameRep.fame or 0)
            repTotal=repTotal+(record.fameRep.rep or 0)
        end
    end
    resourceCardsSyncInteractionPower(records)
    local earnedFame,earnedRep=combatConfig.startingCardConditionalFameRep()
    fameTotal=fameTotal+earnedFame
    repTotal=repTotal+earnedRep
    local fameRepBase={fame=fameTotal,rep=repTotal}
    trackerPrivate.bySeat[seatPos]=current
    resourceCardScanBySeat[seatPos]={cards=records,totals=totals,
        moveSplit=moveSplit,enemyPresent=combatEnemyInPlay,
        attackTransforms=attackTransforms,phaseAttackPreview=phaseAttackPreview,
        terrainModifiers=terrainModifiers,movementEffects=movementEffects,
        enemyEffects=enemyEffects,fameRepBase=fameRepBase,
        ruthlessReadySpent=ruthlessReadySpent,influenceAction=context.influenceAction==true,
        ignoreSiteFortifications=ignoreSiteFortifications,
        unitState=unitState,gloryBroken=(function()
            for _,card in ipairs(cards) do
                local data=gameCards[card.guid]
                if data~=nil and data.resourceKey=="artifactBannerGlory"
                    and trackerPrivate.bannerStrongActive(card)
                    and cardPosture(card)=="upright" then
                    return true
                end
            end
            return false
        end)(),preventUnitDamage=preventUnitDamage,
        allUnitResistances=allUnitResistances,heroFirstWoundIgnored=heroFirstWoundIgnored,
        heroPsychicBlock=heroPsychicBlock,
        usesCurrentHexBlock=usesCurrentHexBlock,
        usesCurrentHexHealing=usesCurrentHexHealing,
        usesSkillLocation=usesSkillLocation}
    resourceCardScanBySeat[seatPos].enemyEffectArrowKinds,
        resourceCardScanBySeat[seatPos].enemyEffectDefenceRequirements,
        resourceCardScanBySeat[seatPos].enemyEffectPreventionSources=
        combatEffectArrowKinds(records,enemyEffects)
    for _,guid in ipairs(changedLinkedSources) do
        context.combatForgetPhysicalSourceTargets(guid)
        if attackAssignmentsClearForObject~=nil then attackAssignmentsClearForObject(guid) end
    end
    if attackAssignmentsRefreshAmbushLinks~=nil then attackAssignmentsRefreshAmbushLinks() end
    -- This also retracts a saved Ready if its card loses power or the new
    -- Rejuvenate side can no longer ready that Unit level.
    if profile~=nil then profile=trackerPrivate.profileCheckpoint("publish.state",profile) end
    combatConfig.scanAwaitingRescan=unitHistoryValidSources(seatPos) or readyNeedsRescan==true
    if profile~=nil then profile=trackerPrivate.profileCheckpoint("publish.unitHistory",profile) end
    if combatConfig.scanAwaitingRescan then
        -- Source validation needs the candidate scan above, but the Combat
        -- Calculator must not accept it as an authoritative damage plan.
        resourceCardsSourceChanged()
    else
        refreshCombatEnemyPanel(combatMonsters,true)
    end
    if profile~=nil then profile=trackerPrivate.profileCheckpoint("publish.combat",profile) end
    local resourceProfile=profile
    -- Refresh conversion counters against the just-published shared budget,
    -- not the preceding scan used during the initial card UI pass.
    for guid,record in pairs(records) do
        if (record.combatConversion~=nil or record.influenceAction) and context.objects[guid]~=nil then
            context.showChoiceButtons(context.objects[guid],record.choices,record.powered,
                nil,nil,record.resources,record.repeatLink,record.shapeshiftField)
        end
    end
    if resourceProfile~=nil then resourceProfile=trackerPrivate.profileCheckpoint("resources.conversions",resourceProfile) end
    resourceCardsApplyFameRep(seatPos)
    if resourceProfile~=nil then resourceProfile=trackerPrivate.profileCheckpoint("resources.fameRep",resourceProfile) end
    -- Refresh Reputation on every settled Skill scan so flipping Arcane
    -- Disguise updates Influence without requiring a panel toggle.
    local reputationBefore=gStates.resourceTracker~=nil
        and gStates.resourceTracker.influence~=nil
        and gStates.resourceTracker.influence.reputation or nil
    refreshResourceTrackerReputation()
    local reputationAfter=gStates.resourceTracker~=nil
        and gStates.resourceTracker.influence~=nil
        and gStates.resourceTracker.influence.reputation or nil
    if resourceProfile~=nil then resourceProfile=trackerPrivate.profileCheckpoint("resources.reputation",resourceProfile) end
    -- Redraw movement when ability flags change, even if total Move stays equal.
    if totalsChanged or terrainChanged or transformChanged or moveSplitChanged
        or enemyStateChanged or influenceActionChanged or reputationBefore~=reputationAfter then
        refreshResourceTrackerText()
    end
    if resourceProfile~=nil then resourceProfile=trackerPrivate.profileCheckpoint("resources.trackerText",resourceProfile) end
    if previousMove~=(totals.move or 0) or moveSplitChanged
        or terrainChanged or movementChanged then
        updateMoveDisplay()
    end
    if resourceProfile~=nil then
        local finished=trackerPrivate.profileCheckpoint("resources.moveDisplay",resourceProfile)
        trackerPrivate.profileFinish("publish.resources",profile,finished)
        profile=finished
    end
    for guid in pairs(previous) do
        if current[guid]~=true then
            combatConfig.sacrificeCastPairs[guid]=nil
            clearHighlight(guid)
            local previousObject=getObjectFromGUID(guid)
            if not combatConfig.cardInTransit(previousObject) then
                if choiceButtonShown[guid]~=nil and choiceButtonShown[guid]~="hidden" then
                    removeChoiceButtons(previousObject)
                end
                -- A genuinely removed card must rebuild its controls on re-entry.
                -- Preserve the existing object UI and its signature during
                -- transient lifts; the settled drop scan owns their cleanup.
                choiceButtonShown[guid]=nil
                choiceExpandedByGUID[guid]=nil
            end
            -- A used Skill leaves play at end of turn; do not allow the
            -- previous turn's Block link to be silently reused next turn.
            local rule=skillResourceDefinitions[guid]
            if rule~=nil and rule.damageMitigation~=nil and gStates~=nil then
                local obj=getObjectFromGUID(guid)
                if obj==nil or (obj.held_by_color==nil and not obj.isSmoothMoving()) then
                    if guid=="ae8673" then gStates.elementalResistanceAttackKey=nil
                    else gStates.battleHardenedAttackKey=nil end
                end
            end
            if rule~=nil and rule.blockSourceBoost~=nil
                and attackAssignmentsForgetBlockLink~=nil then
                local obj=getObjectFromGUID(guid)
                if obj==nil or (obj.held_by_color==nil
                    and not obj.isSmoothMoving()) then
                    attackAssignmentsForgetBlockLink(guid)
                end
            end
        end
    end
    if profile~=nil then profile=trackerPrivate.profileCheckpoint("publish.departed",profile) end
    -- A borrowed offer Unit is not a normal Unit-zone object. Zone-exit
    -- tracker refreshes can drop its independent cycling UI during dragging.
    -- Restore it after all tracker-owned UI writes, without touching resources.
    if callOfferEnsureControls~=nil then callOfferEnsureControls(seatPos) end
    if magicTalentEnsureControls~=nil then magicTalentEnsureControls(seatPos) end
    if unitReplacementEnsureControls~=nil then unitReplacementEnsureControls(seatPos) end
    if steadyTempoRefreshAll~=nil and next(gStates.steadyTempoPending or {})~=nil then
        steadyTempoRefreshAll()
    end
    trackerPrivate.renderCombatNight=nil
    if trackerPrivate.traceEnabled then trackerPrivate.traceEvent("render.done",seatPos) end
    if profile~=nil then trackerPrivate.profileFinish("publish.controls",profile) end
end

return M
