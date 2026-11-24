-- Explicit combat control decisions. Assignment tables and caches are supplied live by the
-- coordinator on every call; this module never owns, replaces or snapshots them.
local M={}

function M.selectOneUnit(guid,combatUnitSiteRestriction,combatOneUnitSelect)
    local player=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
    if player==nil or guid==nil then return false end
    local mode,site=combatUnitSiteRestriction(player.seatPos)
    if mode~="one" then return false end
    combatOneUnitSelect(player.seatPos,site,guid)
    return true
end

function M.assignSource(sourceGUID,enemyGUID,combatConfig,combatAssignmentState)
    if combatConfig~=nil and combatConfig.phaseKeyLocked~=nil
        and combatConfig.phaseKeyLocked(sourceGUID) then return end
    if not resourceCardsCombatTargetAcceptsSource(sourceGUID,enemyGUID) then return end
    if gStates~=nil and combatAssignmentState.targets[sourceGUID]~=enemyGUID then
        if sourceGUID=="0688d8" then gStates.battleHardenedAttackKey=nil end
        if sourceGUID=="ae8673" then gStates.elementalResistanceAttackKey=nil end
    end
    combatAssignmentState.targets[sourceGUID]=enemyGUID
    combatAssignmentState.explicit[sourceGUID]=true
    resourceCardsRefreshCombatEnemies()
    resourceCardsSourceChanged()
end

function M.cycleAttack(row,nextSource,combatPhaseLock,combatAssignmentActiveSeat,combatAssignmentRowTargets,combatAttackChoiceByRow,combatReductionActiveSource,combatReductionAttackChoice)
    if combatPhaseLock~=nil and combatPhaseLock(combatAssignmentActiveSeat())~=nil then return end
    local guid=combatAssignmentRowTargets[row]
    local selector=combatAttackChoiceByRow[row]
    if guid==nil or selector==nil or #selector.options<2 then return end
    local reductions=selector.reductions
    local active=combatReductionActiveSource[guid] or (reductions[1].id or tostring(reductions[1].source))
    if nextSource then
        for i,reduction in ipairs(reductions) do
            if (reduction.id or tostring(reduction.source))==active then
                local following=reductions[i%#reductions+1]
                combatReductionActiveSource[guid]=following.id or tostring(following.source)
                break
            end
        end
    else
        local selected=combatReductionAttackChoice[guid] or {}
        local previous=selected[active]
        local nextIndex=selector.options[1]
        for i,index in ipairs(selector.options) do
            if previous==index then nextIndex=selector.options[i+1] break end
        end
        selected[active]=nextIndex
        combatReductionAttackChoice[guid]=next(selected)~=nil and selected or nil
    end
    resourceCardsRefreshCombatEnemies()
end

function M.toggleGroup(row,combatPhaseLock,combatAssignmentActiveSeat,combatAssignmentRowTargets,combatAssignmentRowIndices,combatEnemyData,combatAssignmentJoined)
    if combatPhaseLock~=nil and combatPhaseLock(combatAssignmentActiveSeat())~=nil then return end
    local guid=combatAssignmentRowTargets[row]
    local index=combatAssignmentRowIndices[row]
    if guid==nil or index==nil or index<2 then return end
    local data=combatEnemyData(guid)
    if data~=nil and data.attackOnly then return end
    combatAssignmentJoined[guid]=combatAssignmentJoined[guid]~=true or nil
    resourceCardsRefreshCombatEnemies()
end

function M.toggleResult(row,combatAssignmentRowTargets,combatConfig,combatExpandedResults)
    local guid=combatAssignmentRowTargets[row]
    if guid==nil then return end
    local cache=combatConfig.resultRowCache[row]
    if cache==nil or cache.guid~=guid then
        combatExpandedResults[guid]=not combatExpandedResults[guid]
        resourceCardsRefreshCombatEnemies()
        return
    end
    if not cache.hasDetails then return end
    combatExpandedResults[guid]=not combatExpandedResults[guid]
    combatConfig.refreshResultRowOnly(row)
end

function M.forgetSource(sourceGUID,replacementTargetGUID,combatConfig,combatAssignmentState)
    if combatConfig~=nil and combatConfig.phaseKeyLocked~=nil
        and combatConfig.phaseKeyLocked(sourceGUID) then return end
    -- Deleting one of several arrows must not wipe the remaining allocations.
    -- The caller passes a deterministic replacement only when the primary
    -- arrow itself has disappeared; nil still clears the source entirely.
    combatAssignmentState.targets[sourceGUID]=replacementTargetGUID
    combatAssignmentState.explicit[sourceGUID]=replacementTargetGUID~=nil or nil
end

function M.forgetPhysicalSourceTargets(unitGUID,combatAssignmentState)
    local prefix=unitGUID.."#"
    for key in pairs(combatAssignmentState.targets) do
        if key==unitGUID or key:sub(1,#prefix)==prefix then
            combatAssignmentState.targets[key]=nil
            combatAssignmentState.explicit[key]=nil
        end
    end
    local selected=combatAssignmentState.selected
    if type(selected)=="string"
        and (selected==unitGUID or selected:sub(1,#prefix)==prefix) then
        combatAssignmentState.selected=nil
    end
end

function M.assignmentClick(id,mouseButton,combatAssignmentSlotSources,combatConfig,combatAssignmentRowTargets,combatAssignmentState,combatAssignmentSources,combatGUIDHasCumbersome,combatSourceArrowKind)
    local lockedSource=combatAssignmentSlotSources[id]
    if lockedSource~=nil and combatConfig~=nil and combatConfig.phaseKeyLocked~=nil
        and combatConfig.phaseKeyLocked(lockedSource) then return end
    if tostring(mouseButton)=="-2" and combatConfig.artifactCombat.bow then
        local key=combatAssignmentSlotSources[id]
        local family=combatConfig.slotBowFamilies[id]
        if key~=nil and family~=nil then
            local modeKey=key.."#"..family
            local old=combatConfig.bowSourceModes[modeKey]
                or (family=="ranged" and "double" or "none")
            combatConfig.bowSourceModes[modeKey]=family=="ranged"
                and (old=="double" and "siege" or "double")
                or (old=="none" and "ranged" or "none")
            resourceCardsSourceChanged()
            return
        end
    end
    local row=id:match("^CombatSourceSlot(%d+)")
    local index=row~=nil and tonumber(row) or nil
    local targetGUID=index~=nil and combatAssignmentRowTargets[index] or nil
    if targetGUID==nil then return end
    local sourceGUID=combatAssignmentSlotSources[id]
    local moved=combatAssignmentState.selected
    if moved~=nil and combatConfig~=nil and combatConfig.phaseKeyLocked~=nil
        and combatConfig.phaseKeyLocked(moved) then
        combatAssignmentState.selected=nil
        combatConfig.refreshSelectedSlots()
        return
    end
    if moved~=nil then
        if sourceGUID==moved then
            combatAssignmentState.selected=nil
            combatConfig.refreshSelectedSlots()
            return
        else
            local movedSource=nil
            for _,candidate in ipairs(combatAssignmentSources(combatAssignmentState.seat)) do
                if candidate.key==moved then movedSource=candidate break end
            end
            local effectSource=combatConfig.effectSources[moved]
            if effectSource==nil and movedSource~=nil
                and movedSource.ranged+movedSource.siege+movedSource.block+movedSource.attack==0
                and not combatGUIDHasCumbersome(targetGUID) then
                combatAssignmentState.selected=nil
                combatConfig.refreshSelectedSlots()
                return
            end
            if not resourceCardsCombatTargetAcceptsSource(moved,targetGUID) then
                combatAssignmentState.selected=nil
                combatConfig.refreshSelectedSlots()
                return
            end
            combatAssignmentState.targets[moved]=targetGUID
            combatAssignmentState.explicit[moved]=true
            combatAssignmentState.selected=nil
            attackAssignmentsSetSourceTarget(moved,targetGUID,
                effectSource~=nil and effectSource.arrow
                or movedSource~=nil and combatSourceArrowKind(movedSource) or nil)
            resourceCardsSourceChanged()
        end
        resourceCardsRefreshCombatEnemies()
        return
    end
    if sourceGUID~=nil then combatAssignmentState.selected=sourceGUID end
    combatConfig.refreshSelectedSlots()
end

function M.forkedLightningPhaseClicked(player,value,id)
    if id~="ResourceCardChoice_d01b70_forkPhase"
        or not resourceCardsPanelOpen()
        or not resourceCardsPlayerCanEdit(player~=nil and player.color or nil) then return end
    gStates.forkedLightningPhase=gStates.forkedLightningPhase=="attack" and "range" or "attack"
    resourceCardsSourceChanged()
end

function M.battleHardenedAttackClicked(player,value,id,combatAssignmentState,combatHardenedAttackOptions)
    if not resourceCardsPanelOpen() or not resourceCardsPlayerCanEdit(player~=nil and player.color or nil) then return end
    local guid=type(id)=="string" and id:match("^ResourceCardChoice_([0-9a-f]+)_hardenedCycle$") or nil
    if guid~="0688d8" and guid~="ae8673" then return end
    local stateKey=guid=="ae8673" and "elementalResistanceAttackKey" or "battleHardenedAttackKey"
    local target=combatAssignmentState.targets[guid]
    local options=combatHardenedAttackOptions(target)
    if #options<2 then return end
    local current=gStates~=nil and gStates[stateKey] or nil
    local index=1
    for i,option in ipairs(options) do if option.key==current then index=i break end end
    gStates[stateKey]=options[index%#options+1].key
    resourceCardsSourceChanged()
end

function M.conversionClicked(player,value,id,combatAssignmentActiveSeat,combatConfig)
    if not resourceCardsPanelOpen()
        or not resourceCardsPlayerCanEdit(player~=nil and player.color or nil) then return end
    local guid,part,useIndex=nil,nil,nil
    if type(id)=="string" then
        guid,part,useIndex=id:match(
            "^ResourceCardChoice_([0-9a-f]+)_convert([%a]+)(%d*)$")
    end
    -- The match above uses two captures; do not mistake a missing part for an action.
    if guid~="878d92" and guid~="8c3de6" then return end
    local seat=combatAssignmentActiveSeat()
    local kind=guid=="878d92" and "agility" or "diplomacy"
    local conversion,available,valid,record=combatConfig.conversionFor(seat,kind)
    if not valid or record==nil or conversion==nil then return end
    local index=useIndex~="" and tonumber(useIndex) or nil
    if index~=nil and (kind~="diplomacy" or record.repeatLink==nil
        or index<1 or index>record.repeatLink.count) then return end
    if part=="Element" then
        if kind~="diplomacy" or record.powered~=true then return end
        if index~=nil then
            conversion.elementUses[index]=conversion.elementUses[index]=="F" and "I" or "F"
        else
            conversion.element=conversion.element=="F" and "I" or "F"
        end
    else
        local delta=tostring(value)=="-2" and -1 or 1
        if kind=="agility" and part=="Attack" and index==nil then
            conversion.attack=math.max(0,math.min(available-2*conversion.ranged,
                conversion.attack+delta))
        elseif kind=="agility" and part=="Ranged" and index==nil then
            conversion.ranged=math.max(0,math.min(
                math.floor((available-conversion.attack)/2),conversion.ranged+delta))
        elseif kind=="diplomacy" and part=="Block" and index~=nil then
            local current=conversion.blockUses[index] or 0
            local unspent=available-conversion.block+current
            conversion.blockUses[index]=math.max(0,math.min(unspent,current+delta))
        elseif kind=="diplomacy" and part=="Block" and index==nil then
            conversion.block=math.max(0,math.min(available,conversion.block+delta))
        else return end
    end
    resourceCardsSourceChanged()
end

return M
