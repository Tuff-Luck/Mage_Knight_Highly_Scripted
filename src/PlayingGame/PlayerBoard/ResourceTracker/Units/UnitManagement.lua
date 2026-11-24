-- Command and Unit activation lifecycle, using live saved history and coordinator helpers.
local M={}

function M.spentCommands()
    local round=tonumber(gStates.currentRound) or 0
    local state=gStates.unitSpentCommandTokens
    if type(state)~="table" or state.round~=round then
        state={round=round,tokens={},owners={}}
        gStates.unitSpentCommandTokens=state
    end
    state.owners=state.owners or {}
    return state.tokens
end

function M.commandSpent(tokenGUID)
    return gStates~=nil and resourceUnitsSpentCommands()[tokenGUID]==true
end

function M.setCommandSpent(tokenGUID,spent)
    if gStates==nil or tokenGUID==nil then return end
    resourceUnitsSpentCommands()[tokenGUID]=spent==true and true or nil
end

function M.commandOwner(tokenGUID)
    if gStates==nil then return nil end
    resourceUnitsSpentCommands()
    return gStates.unitSpentCommandTokens.owners[tokenGUID]
end

function M.recordSpentCommands(seatPos)
    if gStates==nil or seatPos==nil then return end
    local spent=resourceUnitsSpentCommands()
    local owners=gStates.unitSpentCommandTokens.owners
    local layout=unitLayoutSnapshot(seatPos)
    for _,token in ipairs(layout.commands) do
        local unit=unitLayoutCommandTarget(token,seatPos)
        if unit~=nil then
            spent[token.guid]=true
            owners[token.guid]=unit.guid
        end
    end
end

function M.adoptCommand(tokenGUID,unitGUID,seatPos,approvedRecruit)
    if gStates==nil or tokenGUID==nil or unitGUID==nil then return false end
    resourceUnitsSpentCommands()
    local owners=gStates.unitSpentCommandTokens.owners
    local previous=owners[tokenGUID]
    if previous==unitGUID then return true end
    if approvedRecruit~=true then
        if previous==nil or unitLayoutObjectInAnyUnitArea(previous) then return false end
    end
    if previous~=nil and previous~=unitGUID
        and unitLayoutObjectInAnyUnitArea(previous)==false then
        if resourceUnitsRetireUnit~=nil then resourceUnitsRetireUnit(previous) end
    end
    resourceUnitsSetCommandSpent(tokenGUID,false)
    owners[tokenGUID]=unitGUID
    return true
end

function M.retireUnit(unitGUID,removeChoiceButtons,choiceButtonShown,choiceExpandedByGUID)
    if unitGUID==nil then return end
    if unitHistoryReleaseUnit~=nil then unitHistoryReleaseUnit(unitGUID) end
    removeChoiceButtons(getObjectFromGUID(unitGUID))
    choiceButtonShown[unitGUID]=nil
    choiceExpandedByGUID[unitGUID]=nil
    if gStates~=nil and gStates.unitReadyCardChoices~=nil then
        gStates.unitReadyCardChoices[unitGUID]=nil
    end
    if resourceCardsSourceChanged~=nil then resourceCardsSourceChanged() end
end

function M.reconcileNewUnit(unitGUID,seatPos)
    if unitGUID==nil or seatPos==nil then return false end
    local layout=unitLayoutSnapshot(seatPos)
    local slot=layout.unitSlotByGuid[unitGUID]
    local token=slot~=nil and layout.commands[slot] or nil
    if token==nil then return false end
    local changed=resourceUnitsCommandOwner(token.guid)~=unitGUID
        and resourceUnitsAdoptCommand(token.guid,unitGUID,seatPos,false)
    if changed==true and resourceCardsSourceChanged~=nil then
        resourceCardsSourceChanged()
    end
    return changed==true
end

function M.cancelMovedCommand(tokenGUID,seatPos,targetGUID,removeChoiceButtons,choiceExpandedByGUID)
    local activations=gStates~=nil and gStates.unitResourceActivations or nil
    if activations==nil then return false end
    local changed=false
    for unitGUID,activation in pairs(activations) do
        if activation.tokenGUID==tokenGUID and activation.seatPos==seatPos
            and unitGUID~=targetGUID then
            local sourceKey=targetGUID==nil and unitHistoryReadyPermission(unitGUID) or nil
            if sourceKey~=nil then
                -- This is a real Ready effect, not an undo. Preserve the
                -- contribution and wait for the Command token to return.
                unitHistoryMarkReady(unitGUID,sourceKey)
            else
                -- No linked Ready permission: lifting a Command token away
                -- from its Unit undoes only its latest activation.
                unitHistoryUndoLatest(unitGUID)
                removeChoiceButtons(getObjectFromGUID(unitGUID))
                choiceExpandedByGUID[unitGUID]=nil
            end
            changed=true
        end
    end
    return changed
end

function M.commandPickedUp(playerColor,obj,trackerPrivate)
    if not resourceCardsPanelOpen() or obj==nil or not unitLayoutIsCommand(obj) then return end
    local current=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    if current==nil or legalPlayerCheck(playerColor,current.seatPos)~=true then return end
    local origin=unitLayoutCommandTarget(obj,current.seatPos)
    trackerPrivate.commandPickupForUnits[obj.guid]={seatPos=current.seatPos,
        turnNumber=gStates.turnNumber,origin=origin~=nil and origin.guid or nil}
end

function M.commandDropped(playerColor,obj,trackerPrivate,resourceUnitsCancelMovedCommand,queueSeat,unitResourceDefinitions,trackerChoiceScores,choiceExpandedByGUID)
    if not resourceCardsPanelOpen() or obj==nil or not unitLayoutIsCommand(obj) then return end
    local pickup=trackerPrivate.commandPickupForUnits[obj.guid]
    trackerPrivate.commandPickupForUnits[obj.guid]=nil
    if pickup==nil or not resourceCardsPanelOpen() then return end
    local guid=obj.guid
    local serial=trackerPrivate.trackerSession
    safeWaitCondition("PlayerBoard.CardRecognition",function()
        if not resourceCardsPanelOpen() or trackerPrivate.trackerSession~=serial then return end
        local current=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
        if current==nil or current.seatPos~=pickup.seatPos
            or gStates.turnNumber~=pickup.turnNumber then return end
        local token=getObjectFromGUID(guid)
        local unit=token~=nil and unitLayoutCommandTarget(token,pickup.seatPos) or nil
        local targetGUID=unit~=nil and unit.guid or nil
        if resourceUnitsCancelMovedCommand(guid,pickup.seatPos,targetGUID) then
            queueSeat(pickup.seatPos,nil)
        end
        if unit==nil then unitHistoryPriorTurnCommandMoved(guid,pickup.seatPos) end
        if unit==nil or unit.guid==pickup.origin
            or unitResourceDefinitions[unit.guid]==nil then return end
        local state=unitLayoutResourceState(pickup.seatPos)
        if state==nil then return end
        for _,entry in ipairs(state.units) do
            if entry.guid==unit.guid and not entry.unwounded then return end
        end
        -- Choose an unpowered default only. Physical mana overrides it
        -- automatically when a particular paid ability is unambiguous.
        local abilities=unitResourceDefinitions[unit.guid]
        local scores=trackerChoiceScores(unit.guid,pickup.seatPos)
        local choice,bestScore=1,-math.huge
        for i,ability in ipairs(abilities) do
            if ability.manaCost==nil then
                local score=scores[ability.key] or 0
                if score>bestScore then choice,bestScore=i,score end
            end
        end
        gStates.unitResourceActivations=gStates.unitResourceActivations or {}
        -- A new Unit claimed into this Command's slot is Ready even if the
        -- former Unit used this token earlier in the same Round.
        resourceUnitsAdoptCommand(guid,unit.guid,pickup.seatPos,false)
        local previous=gStates.unitResourceActivations[unit.guid]
        local newActivation={seatPos=pickup.seatPos,tokenGUID=guid,
            choice=choice,selected=abilities.multi==true and {} or nil}
        local useIndex=1
        local permission=unitHistoryAwaiting(unit.guid)
            or unitHistoryReadyPermission(unit.guid)
        if previous~=nil or resourceUnitsCommandSpent(guid) or permission~=nil then
            if permission==nil or (previous~=nil and previous.tokenGUID~=guid) then return end
            local appendedIndex=unitHistoryAppend(unit.guid,newActivation,permission)
            if appendedIndex==nil then return end
            useIndex=appendedIndex
        else
            gStates.unitResourceActivations[unit.guid]=newActivation
            unitHistoryEnsure(unit.guid,newActivation)
            unitHistoryRefreshToken(unit.guid)
        end
        -- A newly used Command must remember which physical Unit owns it,
        -- independent of the current turn's activation-history snapshots.
        resourceUnitsSpentCommands()
        gStates.unitSpentCommandTokens.owners[guid]=unit.guid
        resourceCardsCombatSelectOneUnit(unit.guid)
        choiceExpandedByGUID[unit.guid]=nil
        -- The final settled scan owns the choice and target buttons. Painting
        -- them here used an older combatCalcOn state, which could show a
        -- choice but omit its enemy target (or immediately erase both).
        queueSeat(pickup.seatPos,nil)
    end,function()
        if not resourceCardsPanelOpen() or trackerPrivate.trackerSession~=serial then return true end
        local token=getObjectFromGUID(guid)
        return token==nil or trackerPrivate.readyForXZ(token)
    end,8)
end

function M.reconcileChoiceTargets(unit,abilities,activation,unitManaDecision,combatConfig,unitAbilityTargetCategory,unitAbilityTargetKey,combatAssignmentState)
    -- A changed historical choice may retire only THAT use's target. The
    -- other activations of this same physical Unit keep their own arrows.
    local allowed={}
    local current=gStates~=nil and gStates.unitResourceActivations
        and gStates.unitResourceActivations[unit.guid] or activation
    for useIndex,entry in ipairs(unitHistoryUses(unit.guid,current)) do
        local decision=unitManaDecision(unit,abilities,entry,
            entry.frozenCounts or entry.lastCounts)
        local combatBlocked=combatConfig.unitCombatBlocked(unit,abilities,useIndex)
        local key=unitHistoryKey(unit.guid,useIndex)
        local moveRole=combatConfig.unitMoveRole(key,false)
        local denied=combatBlocked and unitHistoryDecisionHasCombat(abilities,decision,moveRole)
        local function allow(index)
            local ability=abilities[index]
            if ability==nil or denied then return end
            local category=unitAbilityTargetCategory(ability)
            if category=="move" and moveRole~="combat" then category=nil end
            -- Do not retire committed Move just because a Cumbersome enemy
            -- disappeared. The target solver owns enemy eligibility.
            if category~=nil or (moveRole=="combat" and (tonumber(ability.move) or 0)>0) then
                allowed[key]=true
            end
            if ability.enemyEffect~=nil or ability.targetableEnemy==true then
                allowed[unitAbilityTargetKey(unit.guid,index,ability,useIndex)]=true
            end
        end
        if abilities.multi==true then
            for index,chosen in pairs(decision.selected or {}) do
                if chosen==true then allow(index) end
            end
        elseif decision.index~=nil then
            allow(decision.index)
        end
    end
    local prefix=unit.guid.."#"
    for key in pairs(combatAssignmentState.targets) do
        if (key==unit.guid or key:sub(1,#prefix)==prefix)
            and allowed[key]~=true then
            combatAssignmentState.targets[key]=nil
            combatAssignmentState.explicit[key]=nil
            if combatAssignmentState.selected==key then
                combatAssignmentState.selected=nil
            end
        end
    end
    attackAssignmentsPruneUnitChoiceSources(unit.guid,allowed)
end

function M.pruneHistoricalTargets(unitGUID,trackerPrivate)
    local activation=gStates~=nil and gStates.unitResourceActivations
        and gStates.unitResourceActivations[unitGUID] or nil
    local unit=getObjectFromGUID(unitGUID)
    local abilities=trackerPrivate.unitAbilitiesFor(unitGUID,nil,
        activation~=nil and activation.seatPos or nil)
    if activation~=nil and unit~=nil and abilities~=nil then
        resourceUnitsReconcileChoiceTargets(unit,abilities,activation)
    elseif attackAssignmentsPruneUnitChoiceSources~=nil then
        attackAssignmentsPruneUnitChoiceSources(unitGUID,{})
    end
end

function M.choiceClicked(player,value,id,moveRoleAvailable,trackerPrivate,unitManaDecision,choiceExpandedByGUID,showUnitAbilityButtons,unitManaCounts,resourceCardsMoveRole,renderSeat)
    if not resourceCardsPanelOpen() or type(id)~="string"
        or not resourceCardsPlayerCanEdit(player~=nil and player.color or nil) then return end
    local unitGUID,index=id:match("^ResourceCardChoice_([0-9a-f]+)_unit(%d+)Combat$")
    local combatMoveChoice=unitGUID~=nil
    if unitGUID==nil then
        unitGUID,index=id:match("^ResourceCardChoice_([0-9a-f]+)_unit(%d+)$")
    end
    index=tonumber(index)
    local latest=unitGUID~=nil and gStates.unitResourceActivations
        and gStates.unitResourceActivations[unitGUID] or nil
    local activation,useIndex=unitHistorySelected(unitGUID,latest)
    local current=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    local abilities=unitGUID~=nil and trackerPrivate.unitAbilitiesFor(
        unitGUID,nil,current~=nil and current.seatPos) or nil
    if activation==nil or abilities==nil or current==nil or index==nil
        or abilities[index]==nil or activation.seatPos~=current.seatPos then return end
    if combatMoveChoice and ((tonumber(abilities[index].move) or 0)<=0
        or not moveRoleAvailable(unitHistoryKey(unitGUID,useIndex))) then return end
    local unit=getObjectFromGUID(unitGUID)
    if unit==nil then return end
    resourceCardsCombatSelectOneUnit(unitGUID)
    local state=unitLayoutResourceState(current.seatPos)
    if state==nil then return end
    for _,entry in ipairs(state.units) do
        if entry.guid==unitGUID and not entry.unwounded then return end
    end
    local decision=unitManaDecision(unit,abilities,activation,
        activation.frozenCounts)
    local available=false
    for _,candidate in ipairs(decision.display) do
        if candidate==index then available=true break end
    end
    if not available then return end
    local dualMove=(tonumber(abilities[index].move) or 0)>0
        and moveRoleAvailable(unitHistoryKey(unitGUID,useIndex))
    if (not decision.ambiguous or abilities.paidChoiceExpandable or decision.index~=nil)
        and choiceExpandedByGUID[unitGUID]~=true and (#decision.display>1 or dualMove) then
        -- Clicking the collapsed option (including either Move role) opens
        -- the menu. Selecting an expanded alternative commits and collapses it.
        choiceExpandedByGUID[unitGUID]=true
        showUnitAbilityButtons(unit,abilities,activation,true,decision)
        return
    end
    if abilities.bannerFearIndex~=nil and index==abilities.bannerFearIndex then
        activation.choice=index
        activation.bannerFearSelected=true
        activation.manaChoice=nil
        activation.lastPaidIndex=nil
        choiceExpandedByGUID[unitGUID]=nil
    elseif abilities.multi==true then
        activation.bannerFearSelected=nil
        -- Gold payments may be assigned to several different abilities, but
        -- never more abilities than the actual number of Gold tokens.
        -- Choosing another button reassigns Gold instead of silently
        -- preserving an older choice the player can no longer see as active.
        activation.selected=activation.selected or {}
        if activation.manaSignature~=decision.signature then activation.selected={} end
        activation.manaSignature=decision.signature
        if decision.selected[index]==true then
            activation.selected[index]=nil
        else
            local goldCount=((activation.frozenCounts
                or unitManaCounts(unit,current.seatPos)).Gold or 0)
            local prior={}
            for _,candidate in ipairs(decision.display) do
                if candidate~=index and activation.selected[candidate]==true then
                    prior[#prior+1]=candidate
                end
            end
            while #prior>=goldCount and #prior>0 do
                activation.selected[table.remove(prior,1)]=nil
            end
            activation.selected[index]=true
        end
        choiceExpandedByGUID[unitGUID]=true
    elseif decision.ambiguous then
        activation.bannerFearSelected=nil
        activation.manaChoice=index
        activation.manaSignature=decision.signature
        -- Once a payable alternative is selected, collapse to its icon and
        -- restore the target button, regardless of the Unit's display style.
        choiceExpandedByGUID[unitGUID]=nil
    else
        activation.bannerFearSelected=nil
        activation.choice=index
        activation.manaChoice=nil
        activation.manaSignature=nil
        activation.lastPaidIndex=nil
        choiceExpandedByGUID[unitGUID]=nil
    end
    if (tonumber(abilities[index].move) or 0)>0 then
        gStates.resourceCardMoveRoles=gStates.resourceCardMoveRoles or {}
        local sourceKey=unitHistoryKey(unitGUID,useIndex)
        gStates.resourceCardMoveRoles[sourceKey]=combatMoveChoice and "combat" or "movement"
        -- Reconcile exact activation keys below; clearing the bare GUID
        -- would also remove every later use of this same physical Unit.
    end
    resourceUnitsReconcileChoiceTargets(unit,abilities,activation)
    unitHistoryValidSources(current.seatPos)
    showUnitAbilityButtons(unit,abilities,activation,true,nil,useIndex)
    if attackAssignmentsRefreshReadyUI~=nil then attackAssignmentsRefreshReadyUI() end
    -- Recalculate Unit choices immediately; enemy modifiers are shown directly
    -- in the Combat Calculator rather than broadcast into chat.
    renderSeat(current.seatPos)
end

function M.borrowedUnitEnded(guid,combatForgetPhysicalSourceTargets,removeChoiceButtons,choiceButtonShown,choiceExpandedByGUID)
    local activation=gStates~=nil and gStates.unitResourceActivations
        and gStates.unitResourceActivations[guid] or nil
    if activation~=nil and activation.callOffer==true then
        gStates.unitResourceActivations[guid]=nil
        if gStates.resourceCardMoveRoles~=nil then gStates.resourceCardMoveRoles[guid]=nil end
    end
    -- Retire the old Unit's combat source first. A failed Object UI update
    -- must never leave its target arrow behind when Call to Arms cycles.
    combatForgetPhysicalSourceTargets(guid)
    if attackAssignmentsClearForObject~=nil then attackAssignmentsClearForObject(guid) end
    if attackAssignmentsPruneUnitChoiceSources~=nil then
        attackAssignmentsPruneUnitChoiceSources(guid,{})
    end
    removeChoiceButtons(getObjectFromGUID(guid))
    choiceButtonShown[guid]=nil
    choiceExpandedByGUID[guid]=nil
    if resourceCardsPanelOpen() then resourceCardsSourceChanged() end
end

function M.resetTurn(removeChoiceButtons,choiceExpandedByGUID,trackerPrivate)
    if gStates~=nil then
        for unitGUID in pairs(gStates.unitResourceActivations or {}) do
            removeChoiceButtons(getObjectFromGUID(unitGUID))
            choiceExpandedByGUID[unitGUID]=nil
        end
        unitHistoryReset()
        gStates.unitReadyCardChoices={}
        gStates.unitResourceActivations={}
    end
    trackerPrivate.commandPickupForUnits={}
    if attackAssignmentsRefreshReadyUI~=nil then attackAssignmentsRefreshReadyUI() end
end

function M.refreshButtons()
    if not resourceCardsPanelOpen() or gStates==nil
        or next(gStates.unitResourceActivations or {})==nil then return end
    resourceCardsSourceChanged()
end

function M.rebuildFromTable(unitResourceDefinitions,trackerChoiceScores)
    if not resourceCardsPanelOpen() or gStates==nil then return end
    local current=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    if current==nil then return end
    local seat=current.seatPos
    local layout=unitLayoutSnapshot(seat)
    local state=unitLayoutResourceState(seat)
    local unwounded={}
    for _,entry in ipairs(state~=nil and state.units or {}) do
        unwounded[entry.guid]=entry.unwounded
    end
    local activations={}
    for _,token in ipairs(layout.commands) do
        local unit=unitLayoutCommandTarget(token,seat)
        local abilities=unit~=nil and unitResourceDefinitions[unit.guid] or nil
        if unit~=nil and abilities~=nil and unwounded[unit.guid]
            and activations[unit.guid]==nil and not resourceUnitsCommandSpent(token.guid) then
            local scores=trackerChoiceScores(unit.guid,seat)
            local choice,bestScore=1,-math.huge
            for i,ability in ipairs(abilities) do
                if ability.manaCost==nil then
                    local score=scores[ability.key] or 0
                    if score>bestScore then choice,bestScore=i,score end
                end
            end
            local activation={seatPos=seat,tokenGUID=token.guid,choice=choice,
                selected=abilities.multi==true and {} or nil}
            activations[unit.guid]=activation
            -- A Ready completed while the panel was closed still belongs to
            -- the current turn, never to the previous spent anchor.
            local awaiting=unitHistoryAwaiting(unit.guid)
            if awaiting~=nil then
                unitHistoryAppend(unit.guid,activation,awaiting)
            else
                unitHistoryEnsure(unit.guid,activation)
            end
        end
    end
    gStates.unitResourceActivations=activations
    for guid in pairs(activations) do unitHistoryRefreshToken(guid) end
end

return M
