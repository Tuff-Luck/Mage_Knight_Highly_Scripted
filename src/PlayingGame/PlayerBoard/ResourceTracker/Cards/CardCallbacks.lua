-- Player-facing card, Skill and Artifact choice callbacks, interaction rewards, Ready links and Throw/Recover. Uses live selections and coordinator helpers; public protected UI names remain unchanged.
local M={}
local resourceOps=require("PlayingGame.PlayerBoard.ResourceTracker.Core.ResourceOperations")
local moveOptions=require("PlayingGame.PlayerBoard.ResourceTracker.Interface.MoveRoleOptions")

function M.healUnits(player,value,id,combatCalcOn,combatEnemyInPlay,trackerPrivate,cardPosture,cardInSeatPlayArea)
    if not resourceCardsPanelOpen()
        or not resourceCardsPlayerCanEdit(player~=nil and player.color or nil)
        or type(id)~="string" or combatCalcOn or combatEnemyInPlay then return end
    local guid=id:match("^ResourceCardChoice_([0-9a-f]+)_healAllUnits$")
    local data=guid~=nil and gameCards[guid] or nil
    if data==nil or data.resourceKey~="artifactBannerFortitude"
        or trackerPrivate.bannerCardForm(guid)~="full" then return end
    local current=turnOrder~=nil and gStates~=nil
        and turnOrder[gStates.turnNumber] or nil
    local card=getObjectFromGUID(guid)
    if current==nil or card==nil or not resourceCardsArtifactBroken(guid,card)
        or cardPosture(card)~="upright"
        or not cardInSeatPlayArea(guid,current.seatPos) then return end
    local layout=unitLayoutSnapshot(current.seatPos)
    local trash=getObjectFromGUID(trashCan)
    if trash==nil then return end
    local uses=trackerPrivate.bannerEffectUses().healing
    if uses[guid] then return end
    -- Activating the break effect consumes it, even if no Units are wounded.
    uses[guid]=true
    local healed=0
    for _,obj in ipairs(layout.objects or {}) do
        if unitLayoutIsWound(obj) then
            trash.putObject(obj)
            healed=healed+1
        end
    end
    if healed>0 then scheduleUnitLayoutRefresh(current.seatPos) end
    -- Refresh the spent HEAL control even when zero Wounds were present.
    resourceCardsSourceChanged()
    broadcastToColor("Banner of Fortitude: healed "..tostring(healed)
        .." Unit Wound(s).",player.color,{0.7,0.95,0.7})
end

function M.startingControl(player,value,id,resourceCardsDetailsOpen,cardPosture,cardInSeatPlayArea)
    if not resourceCardsPanelOpen() or not resourceCardsDetailsOpen()
        or not resourceCardsPlayerCanEdit(player~=nil and player.color or nil)
        or type(id)~="string" then return end
    local guid,control=id:match("^ResourceCardChoice_([0-9a-f]+)_([%a]+)$")
    if guid==nil then return end
    local card=getObjectFromGUID(guid)
    local data=gameCards[guid]
    local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
    local current=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
    if current==nil or card==nil or rule==nil or card.is_face_down
        or cardPosture(card)~="upright"
        or not cardInSeatPlayArea(guid,current.seatPos) then return end
    local scan=resourceCardScanBySeat[current.seatPos]
    local record=scan~=nil and scan.cards[guid] or nil
    if record==nil or not record.complete or record.resources==nil then return end
    gStates.startingCardSelections=gStates.startingCardSelections or {}
    local selected=gStates.startingCardSelections[guid] or {}
    local right=tostring(value)=="-2"
    if control=="interaction" and rule.interactionReward~=nil then
        selected.interaction=not selected.interaction
        selected.interactionPowered=selected.interaction and record.powered or nil
    elseif control=="recruitCount" and rule.recruitmentReward~=nil then
        if unitRecruitmentAdjust~=nil then unitRecruitmentAdjust(current.seatPos,right and -1 or 1) end
        return
    elseif control=="recruit" and rule.recruitDiscount~=nil and not record.powered then
        selected.recruited=not selected.recruited
    elseif control=="terrain" and rule.selectedTerrainDiscount~=nil and record.powered
        and (tonumber(record.resources.move) or 0)>0
        and (gStates.resourceCardMoveRoles or {})[guid]~="combat" then
        if right then selected.terrain=nil
        else
            local terrains={"plains","hills","forest","wasteland","desert",
                "swamp","lake","mountain","city"}
            local index=0
            for i,terrain in ipairs(terrains) do
                if terrain==selected.terrain then index=i break end
            end
            selected.terrain=terrains[index%#terrains+1]
        end
    elseif control=="influenceAction" and rule.influenceAction~=nil then
        if scan.enemyPresent then return end
        selected.influenceAction=not selected.influenceAction
        if selected.influenceAction then
            -- The player can choose only one such Action this turn.
            for other,selection in pairs(gStates.startingCardSelections) do
                if other~=guid then selection.influenceAction=nil end
            end
        else
            selected.influenceHealing=nil
        end
    elseif control=="influenceHeal" and rule.influenceAction~=nil
        and record.influenceAction then
        local used=math.max(0,tonumber(record.influenceHealing) or 0)
        if right then selected.influenceHealing=math.max(0,used-1)
        elseif resourceOps.influenceBudget(scan.totals,gStates.resourceTracker)>=rule.influenceAction.healCost then
            selected.influenceHealing=used+1
        else return end
    elseif control=="ruthlessReady" and rule.readyWithInfluence~=nil
        and record.powered
        and (not rule.readyWithInfluence.requiresAction or record.influenceAction) then
        local links=gStates.unitReadyLinks or {}
        if right then
            local highest=0
            for key in pairs(links) do
                local index=tonumber(key:match("^"..guid.."#ready(%d+)$"))
                if index~=nil and index>highest then highest=index end
            end
            if highest>0 then unitHistoryCancelReadySource(guid.."#ready"..highest) end
        else
            -- A new click chooses a fresh independent Ready source; old links
            -- and their dependent activation history remain intact.
            local spec=rule.readyWithInfluence
            local index=1
            if spec.maxUses~=1 then
                while links[guid.."#ready"..index]~=nil do index=index+1 end
            end
            if spec.maxUses~=nil and index>spec.maxUses then return end
            if links[guid.."#ready"..index]==nil
                and resourceOps.influenceBudget(scan.totals,gStates.resourceTracker)<spec.costPerLevel then return end
            attackAssignmentsBeginUnitReady(guid,guid.."#ready"..index,player.color,
                rule.readyWithInfluence.maxLevel)
        end
    else return end
    gStates.startingCardSelections[guid]=selected
    resourceCardsSourceChanged()
end

function M.grailFame(player,value,id,resourceCardsDetailsOpen,cardPosture,cardInSeatPlayArea,combatConfig)
    if not resourceCardsPanelOpen() or not resourceCardsDetailsOpen()
        or not resourceCardsPlayerCanEdit(player~=nil and player.color or nil)
        or type(id)~="string" or gStates==nil then return end
    local guid=id:match("^ResourceCardChoice_([0-9a-f]+)_grailFame$")
    local data=guid~=nil and gameCards[guid] or nil
    local card=guid~=nil and getObjectFromGUID(guid) or nil
    local current=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    if data==nil or data.resourceKey~="artifactGoldenGrail" or card==nil
        or current==nil or cardPosture(card)~="upright"
        or resourceCardsArtifactBroken(guid,card)
        or not cardInSeatPlayArea(guid,current.seatPos)
        or combatConfig.phaseObjectLocked(guid) then return end
    local scan=resourceCardScanBySeat[current.seatPos]
    local record=scan~=nil and scan.cards[guid] or nil
    if record==nil or not record.complete or record.powered then return end
    gStates.artifactGrailHealingUsed=gStates.artifactGrailHealingUsed or {}
    local used=math.max(0,math.min(2,
        tonumber(gStates.artifactGrailHealingUsed[guid]) or 0))
    local delta=tostring(value)=="-2" and -1 or 1
    gStates.artifactGrailHealingUsed[guid]=math.max(0,math.min(2,used+delta))
    resourceCardsSourceChanged()
end

function M.artifactBreak(player,value,id,resourceCardsDetailsOpen,cardPosture,cardInSeatPlayArea,combatConfig,combatEnemyInPlay,trackerPrivate,choiceExpandedByGUID)
    if not resourceCardsPanelOpen() or not resourceCardsDetailsOpen()
        or not resourceCardsPlayerCanEdit(player~=nil and player.color or nil)
        or type(id)~="string" or gStates==nil then return end
    local guid=id:match("^ResourceCardChoice_([0-9a-f]+)_artifactBreak$")
    local data=guid~=nil and gameCards[guid] or nil
    local card=guid~=nil and getObjectFromGUID(guid) or nil
    local current=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    if data==nil or data.cardType~="Artifact" or data.full~=nil
        or card==nil or current==nil or card.is_face_down==true
        or cardPosture(card)~="upright"
        or not cardInSeatPlayArea(guid,current.seatPos)
        or combatConfig.phaseObjectLocked(guid) then return end
    local broken=resourceCardsArtifactBroken(guid,card)
    if magicTalentTomeCommitted~=nil and magicTalentTomeCommitted(guid) then
        safeBroadcastToColor("Tome of All Spells: cast already completed. Use Rewind to undo.",
            player.color,warningColor)
        return
    end
    if data.resourceKey=="artifactBookOfWisdom"
        and ((gStates.trainingOfferClaims or {})[guid] or 0)>0 then
        safeBroadcastToColor("Book of Wisdom: exchange already completed. Use Rewind to undo.",
            player.color,warningColor)
        return
    end
    if not broken and combatEnemyInPlay then
        if data.resourceKey=="artifactDruidicStaff" then
            safeBroadcastToColor("Druidic Staff: Throw requires two different "
                .."options; only Blue is usable in combat.",player.color,warningColor)
            return
        elseif data.resourceKey=="artifactBannerCourage"
            or data.resourceKey=="artifactBannerFortitude" then
            safeBroadcastToColor("This Banner's stronger effect can only be used "
                .."outside combat.",player.color,warningColor)
            return
        end
    end
    -- Undo only this Banner's Ready permissions on unbreaking. A later
    -- re-Break can restore the original eligible snapshot without granting
    -- duplicate activations or newly-spent Units an extra Ready.
    if broken and data.resourceKey=="artifactBannerCourage" then
        local uses=trackerPrivate.bannerEffectUses().courage[guid]
        for _,entry in ipairs(uses~=nil and uses.eligible or {}) do
            if gStates.unitReadyLinks~=nil and gStates.unitReadyLinks[entry.key]~=nil then
                unitHistoryCancelReadySource(entry.key)
            end
        end
    end
    gStates.artifactBreaks=gStates.artifactBreaks or {}
    gStates.artifactBreaks[guid]=not broken
    -- Update the X immediately; the next tracker scan also reconciles it.
    resourceCardsMaximalEffectMark(card,not broken)
    choiceExpandedByGUID[guid]=nil
    resourceCardsSourceChanged()
    if data.resourceKey=="artifactBookOfWisdom" and trainingOfferScheduleCardCheck~=nil then
        trainingOfferScheduleCardCheck()
    end
end

function M.choiceClicked(player,value,id,combatConfig,resourceCardsDetailsOpen,factionRewardForObject,cardPosture,cardCanPlaySideways,trackerPrivate,currentChoice,choiceCategory,combatCalcOn,combatCumbersomeActive,combatEnemyInPlay,choiceAvailable,inventorySetChoice,choiceExpandedByGUID,showChoiceButtons,selectedResourceByGUID,sideChoices,resourceCardsMoveRole,combatForgetPhysicalSourceTargets,queueSeat)
    if not resourceCardsPanelOpen() or type(id)~="string"
        or not resourceCardsPlayerCanEdit(player~=nil and player.color or nil) then return end
    local guid,repeatIndex,category=id:match(
        "^ResourceCardChoice_([0-9a-f]+)_rep(%d+)_([%w]+)$")
    local setIndex=nil
    if guid==nil then
        guid,setIndex,category=id:match(
            "^ResourceCardChoice_([0-9a-f]+)_set(%d+)_([%w]+)$")
    end
    if guid==nil then
        guid,category=id:match("^ResourceCardChoice_([0-9a-f]+)_([%w]+)$")
    end
    if guid==nil or (combatConfig~=nil and combatConfig.phaseObjectLocked~=nil
        and combatConfig.phaseObjectLocked(guid)) then return end
    setIndex=setIndex~=nil and tonumber(setIndex) or nil
    repeatIndex=repeatIndex~=nil and tonumber(repeatIndex) or nil
    if not resourceCardsDetailsOpen() then return end
    local card=getObjectFromGUID(guid)
    local data=card~=nil and gameCards[guid] or nil
    local isSkill=skillTokens[guid]~=nil
    local isReward=card~=nil and factionRewardForObject(card)~=nil
    local isPuppet=card~=nil and card.getGMNotes()=="Puppet Master"
    local rule=isSkill and skillResourceDefinitions[guid]
        or (data~=nil and cardResourceDefinitions[data.resourceKey] or nil)
    local currentSeat=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    if card==nil or currentSeat==nil then return end
    local scan=resourceCardScanBySeat[currentSeat.seatPos]
    local record=scan~=nil and scan.cards[guid] or nil
    local linkedWound=card.getGMNotes()=="Wound" and record~=nil
        and record.linkedSkill~=nil
    if rule==nil and not isSkill and not isPuppet and not isReward and not (cardPosture(card)=="sideways"
        and (cardCanPlaySideways(card) or linkedWound)) then return end
    local zone=getObjectFromGUID(playerPlayAreas[currentSeat.seatPos])
    local inZone=false
    if zone~=nil then
        for _,obj in ipairs(zone.getObjects()) do
            if obj.guid==guid then inZone=true break end
        end
    end
    if not inZone then return end
    -- Linked cards take the powered choice even without mana placed on them.
    local powered=record~=nil and record.powered==true
    local sideways=not isSkill and not isReward and cardPosture(card)=="sideways"
    local mainChoices
    if record~=nil and record.copiedBasicField~=nil then
        -- A copied Basic effect is fixed; never offer the generic sideways menu.
        if record.copiedBasicField~="move" then return end
        mainChoices=record.choices
    elseif isSkill or isPuppet or isReward then
        mainChoices=record~=nil and record.choices or (rule~=nil and rule.choices or nil)
    elseif sideways and (cardCanPlaySideways(card) or linkedWound) then
        mainChoices=trackerPrivate.sidewaysChoices
    elseif not sideways then
        -- Paid mana choices were filtered during the most recent physical scan.
        -- Do not rediscover the full printed menu and offer unpaid alternatives.
        mainChoices=record~=nil and record.choices or nil
    end
    if (mainChoices==nil or #mainChoices==0) and record~=nil
        and (tonumber(record.resources~=nil and record.resources.move) or 0)>0 then
        mainChoices={{move=record.resources.move}}
    end
    local choices=mainChoices
    if repeatIndex~=nil then
        local repeated=record~=nil and record.repeatLink or nil
        if repeated==nil or repeatIndex<1 or repeatIndex>repeated.count then return end
        choices=repeated.options~=nil and repeated.options[repeatIndex] or mainChoices
    end
    local inventorySpec=not sideways and powered and rule~=nil
        and rule.inventorySetChoices or nil
    if rule~=nil and rule.staffDualChoices==true and powered and not sideways then
        local _,firstKey=currentChoice(guid,true,mainChoices)
        local remaining={}
        for _,option in ipairs(mainChoices or {}) do
            if choiceCategory(option)~=firstKey then
                remaining[#remaining+1]=option
            end
        end
        inventorySpec={choices=remaining}
    end
    local inventorySets=inventorySpec~=nil and record~=nil
        and record.inventorySetCount or 0
    if setIndex~=nil then
        if inventorySpec==nil or setIndex<1 or setIndex>inventorySets then return end
        choices=inventorySpec.choices
    end
    local decodedCategory,requestedMoveRole=moveOptions.decodeCardCategory(category)
    category=decodedCategory
    if data~=nil and data.resourceKey=="artifactDruidicStaff"
        and combatEnemyInPlay and category~="blue" then
        safeBroadcastToColor("Druidic Staff: only the two-crystal option is usable in combat.",
            player.color,warningColor)
        return
    end
    local valid=choiceAvailable(choices,category)
    if not valid then return end
    local shapeshiftTarget=rule~=nil and rule.shapeshift==true
        and record~=nil and record.shapeshiftTargetGUID or nil
    if rule~=nil and rule.shapeshift==true and shapeshiftTarget==nil then return end
    local producesMove=shapeshiftTarget~=nil and category=="move"
    for _,option in ipairs(choices) do
        if choiceCategory(option)==category and moveOptions.producesMove(option,category) then
            producesMove=true
            break
        end
    end
    -- Validate the actual selected resource and its owning physical source.
    local validMoveRole
    requestedMoveRole,validMoveRole=moveOptions.resolve(producesMove,
        requestedMoveRole=="combat" and combatConfig.moveRoleAvailable(shapeshiftTarget or guid),
        requestedMoveRole)
    if not validMoveRole then return end
    -- Any card whose newly selected effect is Move-only must start without
    -- an enemy assignment. Move can Block Cumbersome, but only when the
    -- player explicitly targets it; never carry an old Attack/Block arrow.
    local _,previousCategory
    if repeatIndex~=nil then
        _,previousCategory=combatConfig.repeatChoiceFor(guid,powered,choices,repeatIndex)
    elseif setIndex~=nil then
        _,previousCategory=inventorySetChoice(guid,setIndex,choices,mainChoices)
    else
        _,previousCategory=currentChoice(guid,powered,choices,sideways)
    end
    local selectedMoveOnly=false
    if previousCategory~=category then
        for _,option in ipairs(choices or {}) do
            if choiceCategory(option)==category and moveOptions.producesMove(option,category) then
                selectedMoveOnly=true
                for _,field in ipairs(combatConfig.sourceFields) do
                    if (tonumber(option[field.key]) or 0)>0 then
                        selectedMoveOnly=false
                        break
                    end
                end
                break
            end
        end
    end
    local rowId=repeatIndex~=nil and ("rep"..repeatIndex)
        or setIndex~=nil and ("set"..setIndex) or "base"
    local currentlyExpanded=choiceExpandedByGUID[guid]
    if currentlyExpanded~=rowId and not (rowId=="base" and currentlyExpanded==true) then
        -- Opening a row never changes the chosen resource.
        choiceExpandedByGUID[guid]=rowId
        showChoiceButtons(card,mainChoices,powered,inventorySpec,inventorySets,
            record~=nil and record.resources,record~=nil and record.repeatLink,
            record~=nil and record.shapeshiftField)
        return
    end
    if not sideways and rule~=nil and rule.woundPaymentChoice==category then
        -- Only an actual option selection (not opening the row) deals
        -- its Wound. Stale base controls cannot pay a repeated application.
        if data==nil or record==nil or cardPosture(card)~="upright"
            or (card.is_face_down==true and record.repeatLink==nil)
            or (record.repeatLink~=nil and repeatIndex==nil)
            or (data.cardType=="Spell" and record.spellCastPaid~=true)
            or gStates.preEndTurn==true then return end
        if not trackerPrivate.choicePolicy.payWoundChoice(
            guid,category,repeatIndex,currentSeat.seatPos,player.color) then return end
    end
    local selected=selectedResourceByGUID[guid] or {}
    if record~=nil and record.copiedBasicField~=nil then
        -- Only the role changes; the original sideways choice stays intact.
    elseif repeatIndex~=nil then
        selected.repeatChoices=selected.repeatChoices or {}
        selected.repeatChoices[repeatIndex]=category
    elseif setIndex~=nil then
        selected.inventorySets=selected.inventorySets or {}
        selected.inventorySets[setIndex]=category
    elseif not sideways then
        selected.effect=category
    elseif choiceAvailable(sideChoices(rule,false),category)
        or choiceAvailable(sideChoices(rule,true),category) then
        selected.effect=category
        selected.sideways=nil
    else
        selected.sideways=category
    end
    if record==nil or record.copiedBasicField==nil then
        selectedResourceByGUID[guid]=selected
    end
    local roleGUID=shapeshiftTarget or guid
    local previousMoveRole=requestedMoveRole~=nil
        and resourceCardsMoveRole(roleGUID,true) or nil
    if requestedMoveRole~=nil then
        gStates.resourceCardMoveRoles[roleGUID]=requestedMoveRole
    end
    if repeatIndex~=nil and record~=nil and record.repeatLink~=nil
        and not combatConfig.compositePhasesMatch(
            guid,powered,mainChoices,record.repeatLink) then
        safeBroadcastToColor(
            "Repeated effect: each choice needs its own payment and all uses must resolve in one phase. "
            .."Adjust the rows or payments; incompatible choices contribute nothing.",
            player.color,warningColor)
    end
    if selectedMoveOnly or (previousMoveRole=="combat"
        and requestedMoveRole=="movement")
        or (shapeshiftTarget~=nil and previousCategory~=category) then
        -- Clear both the saved arrow and the independent calculator lock
        -- before the rescan. The newly selected Move stays available for
        -- a deliberate new target, but does not auto-Block any enemy.
        local sourceKey=roleGUID
        if record~=nil and record.kind=="factionReward" and record.splitTargets~=nil
            and requestedMoveRole~=nil then
            -- Only Move leaves combat. Preserve Boot's independent Attack.
            sourceKey=roleGUID.."#block"
        end
        combatForgetPhysicalSourceTargets(sourceKey)
        if attackAssignmentsClearForObject~=nil then attackAssignmentsClearForObject(sourceKey) end
    end
    if data~=nil and rule~=nil and rule.unitReadyLevels~=nil
        and not rule.simultaneousReady and not rule.staffDualChoices then
        gStates.unitReadyCardChoices=gStates.unitReadyCardChoices or {}
        gStates.unitReadyCardChoices[guid]=selected.effect=="ready" or nil
    end
    choiceExpandedByGUID[guid]=nil
    showChoiceButtons(card,mainChoices,powered,inventorySpec,inventorySets,
        record~=nil and record.resources,record~=nil and record.repeatLink,
        record~=nil and record.shapeshiftField)
    if data~=nil and rule~=nil and rule.unitReadyLevels~=nil
        and not rule.simultaneousReady and not rule.staffDualChoices then
        unitHistoryValidSources(currentSeat.seatPos)
        if attackAssignmentsRefreshReadyUI~=nil then attackAssignmentsRefreshReadyUI() end
    end
    queueSeat(currentSeat.seatPos,nil)
end

function M.regenerationReady(player,value,id,resourceCardsDetailsOpen)
    if not resourceCardsPanelOpen() or not resourceCardsDetailsOpen()
        or not resourceCardsPlayerCanEdit(player~=nil and player.color or nil)
        or type(id)~="string" then return end
    local guid,index=id:match("^ResourceCardChoice_([0-9a-f]+)_regenReady(%d+)$")
    local data=guid~=nil and gameCards[guid] or nil
    local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
    if rule==nil or rule.simultaneousReady~=true then return end
    local sourceKey=guid.."#ready"..index
    if tostring(value)=="-2" then
        if gStates.unitReadyLinks~=nil and gStates.unitReadyLinks[sourceKey]~=nil then
            unitHistoryCancelReadySource(sourceKey)
            resourceCardsSourceChanged()
        end
        return
    end
    if not resourceCardsReadySourceValid(sourceKey) then return end
    local active=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
    if active==nil then return end
    attackAssignmentsBeginUnitReady(guid,sourceKey,player.color,
        resourceCardsReadySourceLevelLimit(sourceKey,active.seatPos))
end

return M
