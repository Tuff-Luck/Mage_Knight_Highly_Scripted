-- Physical zone observation, known released play sources, active Unit recovery, enemy reconciliation, inventory counts, and pre-payment Artifact and Unit state. Mana candidates come only from live zones.
local M={}

function M.observe(context)
    local seatPos, trackerPrivate, combatConfig = context.seatPos, context.trackerPrivate, context.combatConfig
    local combatEnemyData, resourceObjectKind, combatKeepHeldEnemies = context.combatEnemyData, context.resourceObjectKind, context.combatKeepHeldEnemies
    local resourceCardsCombatNightFromEnemies, combatCalcUpdate, footprint = context.resourceCardsCombatNightFromEnemies, context.combatCalcUpdate, context.footprint
    local objects,placements,monsters,playMonsters={},{},{},{}
    local combatMonsters,combatPlayMonsters={},{}
    local objectKinds={}
    local function inspectZone(guid,zoneKind)
        local zone=guid~=nil and getObjectFromGUID(guid) or nil
        if zone==nil then return end
        for _,obj in ipairs(zone.getObjects()) do
            if zoneKind=="play" or zoneKind=="unit" then
                local data=combatEnemyData(obj.guid,obj)
                if data~=nil and data.name~="Ruin" then
                    combatMonsters[obj.guid]=obj
                    if zoneKind=="play" then combatPlayMonsters[obj.guid]=obj end
                end
            end
            local kind=objectKinds[obj.guid]
            if kind==nil then
                kind=resourceObjectKind(obj)
                if kind~=nil then objectKinds[obj.guid]=kind end
            end
            if zoneKind=="play" and trackerPrivate.playCandidateKind(kind) then
                local candidates=trackerPrivate.playCandidatesBySeat[seatPos]
                if candidates==nil then
                    candidates={}
                    trackerPrivate.playCandidatesBySeat[seatPos]=candidates
                end
                candidates[obj.guid]=true
            end
            if kind~=nil and (kind~="mana" or trackerPrivate.readyForXZ(obj))
                and (zoneKind~="play" or not trackerPrivate.playCandidateKind(kind)
                    or not combatConfig.cardInTransit(obj))
                and (zoneKind=="play"
                or (zoneKind=="unit" and (kind=="unit" or kind=="mana" or kind=="puppet"))
                or (zoneKind=="crystal" and kind=="mana")) then
                -- Play-area placement takes precedence when scripting zones overlap.
                local existing=placements[obj.guid]
                if existing==nil or (zoneKind=="play" and existing~="play") then
                    objects[obj.guid]=obj
                    placements[obj.guid]=zoneKind
                end
            end
        end
    end
    inspectZone(playerCrystalAreas[seatPos],"crystal")
    inspectZone(playerUnitAreas[seatPos],"unit")
    inspectZone(playerPlayAreas[seatPos],"play")
    -- A released source may be above the shallow zone despite its X/Z being
    -- on the play mat. Recover only previously seen/dropped play sources,
    -- never arbitrary cards elsewhere on the table.
    do
        local playCandidates=trackerPrivate.playCandidatesBySeat[seatPos] or {}
        for guid in pairs(playCandidates) do
            if placements[guid]~="play" then
                local obj=getObjectFromGUID(guid)
                if obj==nil or (obj.isDestroyed~=nil and obj.isDestroyed()) then
                    playCandidates[guid]=nil
                elseif trackerPrivate.cardOverPlayMat(obj,seatPos) then
                    local kind=resourceObjectKind(obj)
                    if trackerPrivate.playCandidateKind(kind) then
                        objects[guid]=obj
                        placements[guid]="play"
                        objectKinds[guid]=kind
                    end
                elseif not combatConfig.cardInTransit(obj) then
                    playCandidates[guid]=nil
                end
            end
        end
    end
    -- A resting active Unit can be lifted above the thin Zone by its stacked
    -- Command/crystal without actually leaving the Unit mat. Reuse the same
    -- X/Z and held-object checks as the physical Unit layout rather than
    -- interpreting a missing zone entry as an undone activation.
    local missingActiveUnit=false
    for guid,activation in pairs(gStates.unitResourceActivations or {}) do
        if activation.seatPos==seatPos and objects[guid]==nil then
            missingActiveUnit=true
            break
        end
    end
    if missingActiveUnit then
        for _,unit in ipairs(unitLayoutSnapshot(seatPos).units) do
            if objects[unit.guid]==nil and gStates.unitResourceActivations[unit.guid]~=nil then
                objects[unit.guid]=unit
                objectKinds[unit.guid]="unit"
                placements[unit.guid]="unit"
            end
        end
    end
    -- One observation and one held-enemy reconciliation serve both systems.
    -- Reminders/Leader previews belong to combat, but never to card enemy-count bonuses.
    combatKeepHeldEnemies(seatPos,combatMonsters,combatPlayMonsters)
    -- Apply NightRules to the entire active combat, not just Dungeon/Tomb
    -- location checks. The same value powers mana legality and day/night Skills.
    trackerPrivate.renderCombatNight=resourceCardsCombatNightFromEnemies(combatMonsters)
    for guid,enemy in pairs(combatMonsters) do
        local pug=monsterPugs[guid]
        if pug~=nil and pug.name~="Ruin" then
            monsters[guid]=enemy
            if combatPlayMonsters[guid]~=nil then playMonsters[guid]=enemy end
        end
    end
    combatCalcUpdate(combatMonsters)
    local enemyEntries={}
    for guid,enemy in pairs(monsters) do
        if enemy.is_face_down~=true then enemyEntries[#enemyEntries+1]={guid=guid} end
    end

    -- Read *inventory* crystals only. A crystal moved to the Play Area is
    -- mana being spent, not part of a complete set in inventory.
    local inventoryCrystalCounts={}
    for guid,obj in pairs(objects) do
        if placements[guid]=="crystal" and isManaTokenFigurine(obj) then
            local color=manaTokenColor(obj)
            if color~=nil then
                inventoryCrystalCounts[color]=(inventoryCrystalCounts[color] or 0)+1
            end
        end
    end

    local cards,wounds,skills,manaObjects,footprints={}, {}, {}, {}, {}
    local unitPaymentMana={}
    local enemyEffects={}
    local pendingWingsNight={}
    -- Resolve conditional Unit targets after other cards, Units, Skills and
    -- rewards have had a chance to remove Fortification in this same scan.
    local deferredUnfortifiedUnitEffects={}
    local unitCombatBoost,preventUnitDamage,allUnitResistances=0,false,false
    local heroFirstWoundIgnored=false
    local heroPsychicBlock=false
    local hasUnits=false
    for guid,obj in pairs(objects) do
        local kind=objectKinds[guid]
        if kind=="card" and placements[guid]=="play"
            and trackerPrivate.bannerCardForm(guid)~="half"
            and (trainingOfferReservedCard==nil
                or not trainingOfferReservedCard(guid,seatPos))
            and (magicTalentInactivePreview==nil or not magicTalentInactivePreview(guid)) then
            cards[#cards+1]=obj
            footprints[guid]=footprint(obj)
        elseif kind=="wound" and placements[guid]=="play" then
            wounds[#wounds+1]=obj
            footprints[guid]=footprint(obj)
        elseif kind=="skill" and placements[guid]=="play" then
            skills[#skills+1]=obj
            footprints[guid]=footprint(obj)
        elseif kind=="mana" then
            if manaClaimDieHeld==nil or not manaClaimDieHeld(obj.guid) then
                manaObjects[#manaObjects+1]=obj
                if placements[guid]=="play" or placements[guid]=="unit" then
                    unitPaymentMana[#unitPaymentMana+1]=obj
                end
            end
        elseif kind=="unit" then
            -- Unit and Play Areas overlap; placement may be "play" here.
            -- The physical Unit-area snapshot still owns its wound/spent state.
            hasUnits=true
        end
    end
    return objects, placements, monsters, playMonsters, combatMonsters, enemyEntries, inventoryCrystalCounts, cards, wounds, skills, manaObjects, footprints, unitPaymentMana, enemyEffects, pendingWingsNight, deferredUnfortifiedUnitEffects, unitCombatBoost, preventUnitDamage, allUnitResistances, heroFirstWoundIgnored, heroPsychicBlock, hasUnits
end

-- Shared live Amulet permission policy, also used by link-only scans.
function M.amuletPermissions(cards,cardPosture)
    local permissions={gold=false,black=false}
    for _,card in ipairs(cards) do
        local data=gameCards[card.guid]
        local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
        if rule~=nil and rule.artifactMana~=nil and cardPosture(card)=="upright" then
            permissions[rule.artifactMana]=true
        end
    end
    return permissions
end

function M.prepare(context)
    local seatPos, cards, skills = context.seatPos, context.cards, context.skills
    local placements, hasUnits, combatMonsters = context.placements, context.hasUnits, context.combatMonsters
    local combatConfig, trackerPrivate, cardPosture = context.combatConfig, context.trackerPrivate, context.cardPosture
    local combatUnitSiteRestriction, combatOneUnitChosen, combatOneUnitSelect = context.combatUnitSiteRestriction, context.combatOneUnitChosen, context.combatOneUnitSelect
    local combatUnitSitePermits, unitResourceDefinitions, clearHighlight = context.combatUnitSitePermits, context.unitResourceDefinitions, context.clearHighlight
    -- Scan active Amulet permissions before resolving ANY physical mana.
    combatConfig.amuletMana=M.amuletPermissions(cards,cardPosture)

    combatConfig.artifactCombat.sword=false
    combatConfig.artifactCombat.bow=false
    combatConfig.artifactCombat.swordFame=false
    combatConfig.artifactCombat.bowFame=false
    for _,card in ipairs(cards) do
        local data=gameCards[card.guid]
        local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
        if rule~=nil and cardPosture(card)=="upright" then
            if rule.artifactGlobalCombat~=nil and resourceCardsArtifactBroken(card.guid,card) then
                combatConfig.artifactCombat[rule.artifactGlobalCombat]=true
            end
            if rule.artifactGlobalFame=="all" then
                combatConfig.artifactCombat.swordFame=true
            elseif rule.artifactGlobalFame=="range" and not resourceCardsArtifactBroken(card.guid,card) then
                combatConfig.artifactCombat.bowFame=true
            end
        end
    end

    -- Read the physical Unit state once per scan for highlights and Skills.
    -- A Command token already resting on a Unit from a previous turn means
    -- spent; a Unit activated by a Command move THIS turn is still active.
    local unitState=hasUnits and unitLayoutResourceState(seatPos) or nil
    gStates.unitResourceActivations=gStates.unitResourceActivations or {}
    local activations=gStates.unitResourceActivations
    local unitSiteMode,unitSite=combatUnitSiteRestriction(seatPos,combatMonsters)
    if unitSiteMode==nil then resourceCardsCombatClearOneUnit(seatPos) end
    local chosenSiteUnit=unitSiteMode=="one" and combatOneUnitChosen(seatPos,unitSite) or nil
    if unitSiteMode=="one" and chosenSiteUnit==nil and unitState~=nil then
        -- With just one used Unit, its Command token is an unambiguous choice.
        -- If several are active, do not infer that all may participate.
        local only,count=nil,0
        for _,entry in ipairs(unitState.units) do
            local activation=activations[entry.guid]
            if entry.unwounded and activation~=nil
                and activation.seatPos==seatPos then
                only,count=entry.guid,count+1
            end
        end
        if count==1 then
            chosenSiteUnit=only
            combatOneUnitSelect(seatPos,unitSite,only)
        end
    end
    trackerPrivate.unitHighlightBlocked={}
    if unitState~=nil then
        for _,entry in ipairs(unitState.units) do
            local activation=activations[entry.guid]
            local activeThisTurn=activation~=nil and activation.seatPos==seatPos
                and unitResourceDefinitions[entry.guid]~=nil
            -- Ready means no Command token is resting on the Unit card.
            -- Historical/borrowed abilities can still contribute resources,
            -- but cannot outline a Unit without its physical Command.
            if entry.ready or not entry.unwounded or not activeThisTurn
                or not combatUnitSitePermits(unitSiteMode,
                    unitState.bondsUnitGUID,chosenSiteUnit,entry.guid,false) then
                trackerPrivate.unitHighlightBlocked[entry.guid]=true
                clearHighlight(entry.guid)
            end
        end
    end
    local countWounds=false
    for _,card in ipairs(cards) do
        local data=gameCards[card.guid]
        local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
        if rule~=nil and rule.woundBonus~=nil then countWounds=true break end
    end
    if countWounds and unitState==nil then unitState=unitLayoutResourceState(seatPos) end
    for _,skill in ipairs(skills) do
        local rule=skillResourceDefinitions[skill.guid]
        local sideways=rule~=nil and rule.linkedCard~=nil and rule.linkedCard.sideways or nil
        if unitState==nil and rule~=nil and (rule.unitCondition~=nil
            or (sideways~=nil and sideways.perEmptyCommandSlot~=nil)) then
            unitState=unitLayoutResourceState(seatPos)
            break
        end
    end
    -- Hand-zone Wounds are not play-area Wounds. Count the latter only when
    -- physically placed on a Unit, via the shared Unit layout observer.
    local woundCount=nil
    if countWounds and unitState~=nil then
        local hand=getObjectFromGUID(handZones[seatPos])
        if hand~=nil then
            woundCount=unitState.woundCount or 0
            for _,obj in ipairs(hand.getObjects()) do
                if obj.type=="Card" and obj.getGMNotes()=="Wound"
                    and placements[obj.guid]~="play" then
                    woundCount=woundCount+1
                end
            end
        end
    end
    return unitState, activations, unitSiteMode, unitSite, chosenSiteUnit, woundCount
end

return M
