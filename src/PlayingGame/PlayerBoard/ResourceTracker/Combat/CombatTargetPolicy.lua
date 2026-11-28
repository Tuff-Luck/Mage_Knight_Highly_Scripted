-- Shared target policy for physical targeting and calculator controls.
-- Read caller-owned assignment state and current scan data without storing copies.
local M={}

function M.requiresUnfortified(sourceKey,unitResourceDefinitions)
    if type(sourceKey)~="string" then return false end
    local guid,index=sourceKey:match("^([^#]+)#effect(%d+)$")
    if guid==nil then guid,index=sourceKey:match("^([^#]+)#use%d+#effect(%d+)$") end
    local abilities=guid~=nil and unitResourceDefinitions~=nil
        and unitResourceDefinitions[guid] or nil
    local ability=abilities~=nil and abilities[tonumber(index)] or nil
    return ability~=nil and ability.enemyEffect~=nil
        and ability.enemyEffect.noAttackUnfortified==true
end

function M.effectivelyUnfortified(guid,effects,ignoreSiteFortifications,combatEnemyData,combatEffectOf,combatEnemyFortificationCount,combatEnemyHasTrait)
    local data,mode=combatEnemyData(guid)
    if data==nil or mode=="attackOnly" or data.attackOnly==true then return false end
    local perks=gStates~=nil and gStates.monsterPerks~=nil
        and gStates.monsterPerks[guid] or nil
    local effect=effects~=nil and effects[guid] or combatEffectOf(guid)
    local fortified=combatEnemyFortificationCount(data,perks)
    -- Demolish removes site/wall Fortification, but not printed Fortified.
    if ignoreSiteFortifications==true and fortified>0 and perks~=nil then
        fortified=math.max(0,fortified
            -(perks.fortified==true and 1 or 0)
            -(perks.wallFortified==true and 1 or 0))
    end
    if effect~=nil and effect.removedPrinted~=nil
        and effect.removedPrinted.fortified==true and data.fortified==true
        and not combatEnemyHasTrait(data,perks,"unfortified") then
        fortified=math.max(0,fortified-1)
    end
    return fortified==0 or (effect~=nil and effect.removeFortify==true)
end

function M.rejectMessage(sourceKey,targetGUID,combatAssignmentActiveSeat)
    local seat=combatAssignmentActiveSeat()
    local scan=seat~=nil and resourceCardScanBySeat[seat] or nil
    local record=scan~=nil and scan.cards[sourceKey] or nil
    if record~=nil and record.possessEnemyGUID==targetGUID then
        return "Possess cannot use an enemy's own Attack against itself."
    end
    if resourceCardsUnitTargetRequiresUnfortified(sourceKey) then
        return "Illusionists can only target an unfortified enemy."
    end
    if apocalypseDragonGroundHeadNameForGUID~=nil
        and apocalypseDragonGroundHeadNameForGUID(targetGUID)=="Control" then
        return "The Control head cannot be attacked."
    end
    if sourceKey=="6a33c1" then
        return "Curse's Armour reduction cannot target an attack-only reminder."
    end
    return "Only Block/Move or attack reductions can target a reminder."
end

function M.acceptsSource(sourceKey,targetGUID,combatAssignmentActiveSeat,combatEnemyData,combatConfig,combatAssignmentSources,combatAssignmentState,selectedResourceByGUID)
    -- Committed pre-Damage Unit resources are historical. Keep the enemy
    -- originally attacked, but never let a destroyed Unit retarget them.
    local ledger=gStates~=nil and gStates.combatWoundApplication or nil
    for _,sources in pairs(ledger~=nil and ledger.retiredUnitSources or {}) do
        for _,source in ipairs(sources) do
            if source.key==sourceKey then
                return source.retiredTarget==targetGUID
            end
        end
    end
    local data=combatEnemyData(targetGUID)
    if data==nil then return false end
    -- Post-Damage companion sources are Attack-only. Their generated keys do
    -- not appear in the ordinary live source list, so reject attack-only
    -- reminder tokens explicitly (including the Dragon's Control head).
    if type(sourceKey)=="string" and sourceKey:match("#postDamage$")
        and (data.attackOnly==true
            or (apocalypseDragonGroundHeadNameForGUID~=nil
                and apocalypseDragonGroundHeadNameForGUID(targetGUID)=="Control")) then
        return false
    end
    local seat=combatAssignmentActiveSeat()
    local scan=seat~=nil and resourceCardScanBySeat[seat] or nil
    local record=scan~=nil and scan.cards[sourceKey] or nil
    if record~=nil and record.possessEnemyGUID==targetGUID then return false end
    local effectRequiresDefence=scan~=nil and scan.enemyEffectDefenceRequirements or nil
    local effectSource=combatConfig.effectSources[sourceKey]
    local commitment=combatEffectSummonCommitment~=nil and combatEffectSummonCommitment(sourceKey) or nil
    if commitment~=nil then
        if not commitment.targets[targetGUID] then return false end
        if commitment.committed[targetGUID] then return true end
    end
    local prevention=scan~=nil and scan.enemyEffectPreventionSources or nil
    if prevention~=nil and prevention[sourceKey]~=nil
        and not combatEffectSummonPreventionLegal(targetGUID,prevention[sourceKey]) then return false end
    if apocalypseDragonGroundHeadNameForGUID~=nil
        and apocalypseDragonGroundHeadNameForGUID(targetGUID)=="Control" then
        if effectRequiresDefence~=nil and effectRequiresDefence[sourceKey]~=nil then
            return not effectRequiresDefence[sourceKey]
        end
        if effectSource~=nil then return not effectSource.requiresDefence end
        for _,source in ipairs(combatAssignmentSources(seat)) do
            if source.key==sourceKey then
                return source.ranged+source.siege+source.attack==0
            end
        end
        return sourceKey~="6a33c1"
    end
    if resourceCardsUnitTargetRequiresUnfortified(sourceKey) then
        local seat=combatAssignmentActiveSeat()
        local scan=seat~=nil and resourceCardScanBySeat~=nil
            and resourceCardScanBySeat[seat] or nil
        return resourceCardsEnemyEffectivelyUnfortified(targetGUID,
            scan~=nil and scan.enemyEffects or nil,
            scan~=nil and scan.ignoreSiteFortifications==true)
    end
    if type(sourceKey)=="string" and sourceKey:match("^d01b70#fork%d+$") then
        if data.attackOnly==true then return false end
        for key,target in pairs(combatAssignmentState.targets or {}) do
            if key~=sourceKey and key:match("^d01b70#fork%d+$")
                and target==targetGUID then return false end
        end
    end
    -- Explosive Bolt's follow-up reduces Armour, never reminder Attack.
    if type(sourceKey)=="string" and sourceKey:match("#explosiveAttack$") then
        return data.attackOnly~=true
    end
    if (sourceKey=="4ac9f6" or sourceKey=="19daf9") and data.monsters~=nil then
        return false -- Nature's Vengeance targets a summoned monster, never its Summoner.
    end
    if data.attackOnly~=true then return true end
    if effectRequiresDefence~=nil and effectRequiresDefence[sourceKey]~=nil then
        return not effectRequiresDefence[sourceKey]
    end
    if effectSource~=nil then return not effectSource.requiresDefence end
    -- An Attack-only reminder has no Armour to reduce. Curse's Attack option
    -- can still target its attack, but its Armour option cannot.
    if sourceKey=="6a33c1" then
        local saved=selectedResourceByGUID[sourceKey]
        if saved~=nil and saved.effect=="armour" then return false end
    end
    for _,source in ipairs(combatAssignmentSources(combatAssignmentActiveSeat())) do
        if source.key==sourceKey then
            return source.ranged+source.siege+source.attack==0
        end
    end
    return true
end

function M.effectArrowKind(sourceKey,combatAssignmentActiveSeat)
    local seat=combatAssignmentActiveSeat()
    local scan=seat~=nil and resourceCardScanBySeat[seat] or nil
    return scan~=nil and scan.enemyEffectArrowKinds~=nil
        and scan.enemyEffectArrowKinds[sourceKey] or nil
end

function M.blockLinkSkillActive(guid)
    local active=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
    local scan=active~=nil and resourceCardScanBySeat[active.seatPos] or nil
    local record=scan~=nil and scan.cards[guid] or nil
    local rule=skillResourceDefinitions[guid]
    return record~=nil and record.kind=="skill" and rule~=nil
        and rule.blockSourceBoost~=nil and resourceCardsPanelOpen()
end

function M.blockLinkTargets(combatConfig)
    local active=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
    local scan=active~=nil and resourceCardScanBySeat[active.seatPos] or nil
    local targets={}
    for guid,record in pairs(scan~=nil and scan.cards or {}) do
        if record.resources~=nil and record.contributes==true
            and record.kind~="mana" and record.kind~="wound" then
            for _,field in ipairs(combatConfig.spiritGuideBlockFields) do
                if (tonumber(record.resources[field]) or 0)>0 then
                    local obj=getObjectFromGUID(guid)
                    if obj~=nil and not obj.isDestroyed() then targets[guid]=obj end
                    break
                end
            end
        end
    end
    return targets
end

function M.ambushEligibleTarget(guid,record,sourceGUID,combatConfig,cardPosture)
    if guid==sourceGUID or record==nil or record.resources==nil then return false end
    local data=gameCards[guid]
    if data==nil or (data.cardType~="Starting" and data.cardType~="Advanced Action"
        and data.cardType~="Spell" and data.cardType~="Artifact") then return false end
    local card=getObjectFromGUID(guid)
    if card==nil or card.isDestroyed() or card.is_face_down==true
        or cardPosture(card)=="discard" then return false end
    for _,key in ipairs(combatConfig.ambushCombatCategories) do
        if (tonumber(record.resources[key]) or 0)>0 then return true end
    end
    return false
end

function M.ambushSourceActive(guid,resourceCardsDetailsOpen,cardPosture)
    local active=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
    local scan=active~=nil and resourceCardScanBySeat[active.seatPos] or nil
    local record=scan~=nil and scan.cards[guid] or nil
    local data=gameCards[guid]
    local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
    local card=getObjectFromGUID(guid)
    return resourceCardsPanelOpen() and resourceCardsDetailsOpen()
        and rule~=nil and rule.combatLink~=nil
        and record~=nil and record.complete==true and record.resources~=nil
        and card~=nil and not card.isDestroyed() and card.is_face_down~=true
        and cardPosture(card)=="upright"
end

function M.ambushLinkTargets(sourceGUID,combatConfig)
    local targets={}
    if not resourceCardsAmbushSourceActive(sourceGUID) then return targets end
    local active=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
    local scan=active~=nil and resourceCardScanBySeat[active.seatPos] or nil
    for guid,record in pairs(scan~=nil and scan.cards or {}) do
        if combatConfig.ambushEligibleTarget(guid,record,sourceGUID) then
            targets[guid]=getObjectFromGUID(guid)
        end
    end
    return targets
end

function M.additionalTargetLimit(sourceKey,combatAssignmentActiveSeat,combatAssignmentSources,combatConfig,currentChoice,sideChoices)
    if type(sourceKey)~="string" then return 1 end
    local seat=combatAssignmentActiveSeat()
    local scan=seat~=nil and resourceCardScanBySeat[seat] or nil
    local guid=sourceKey:match("^[^#]+")
    local record=scan~=nil and scan.cards[guid] or nil
    if record~=nil and record.complete==true then
        for _,key in ipairs(record.enemyEffectTargetKeys or {}) do
            if key==sourceKey then
                local data=gameCards[guid]
                local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
                local index=tonumber(sourceKey:match("#rep(%d+)$"))
                local _,category
                if index~=nil and record.repeatLink~=nil then
                    _,category=combatConfig.repeatChoiceFor(guid,record.powered,
                        record.repeatLink.options~=nil
                            and record.repeatLink.options[index]
                            or sideChoices(rule,record.powered),index)
                else
                    _,category=currentChoice(guid,record.powered,
                        sideChoices(rule,record.powered))
                end
                local spec=combatEffectSpec(rule,record.powered,category)
                if spec~=nil then
                    if spec.multiTargetMove==true then return math.huge,"move" end
                    local maximum=tonumber(spec.maxTargets) or 0
                    if maximum>1 then return maximum,"targets" end
                end
                break
            end
        end
    end
    for _,source in ipairs(combatAssignmentSources(seat)) do
        if source.key==sourceKey then
            local converted=tonumber(source.convertedAmount) or 0
            if converted>1 then return converted,"points" end
            local influence=tonumber(source.psychicInfluence) or 0
            if influence>1 then return influence,"influence" end
            local move=tonumber(source.move) or 0
            if move>1 then return move,"movePoints" end
            break
        end
    end
    return 1
end

return M
