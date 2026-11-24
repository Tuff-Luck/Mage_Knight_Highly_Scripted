-- Panel open/close, turn handoff, saved choice serialization and startup restoration. Mutates the coordinator's live tables through supplied reset callbacks; retains public entry points.
local M={}

function M.clearAll(trackerPrivate,clearChoiceButtons,resetExpanded,shown,clearHighlight,combatConfig)
    if trackerPrivate.traceEnabled then trackerPrivate.traceEvent("tracker.reset") end
    for seat=1,4 do trackerPrivate.generation[seat]=(trackerPrivate.generation[seat] or 0)+1 end
    trackerPrivate.pendingSeatSettles={}
    trackerPrivate.pendingSeatRender={}
    clearChoiceButtons()
    resetExpanded()
    -- Do not discard choices when closing/reopening the Resource Tracker.
    for guid in pairs(shown) do clearHighlight(guid) end
    trackerPrivate.bySeat={}
    trackerPrivate.playCandidatesBySeat={}
    trackerPrivate.playCardMovements={}
    trackerPrivate.cardUIRecheckSerial={}
    resourceCardScanBySeat={}
    combatConfig.bowSourceModes={}
    combatConfig.amuletMana={gold=false,black=false}
    -- Ordinary resource sources disappear when tracking is OFF. Earned
    -- conditional interaction rewards/penalties remain pending until turn end.
    if turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber]~=nil then
        local fame,rep=combatConfig.startingCardConditionalFameRep()
        resourceFameRepApply(gStates.turnNumber,fame,rep)
    end
    -- Closing must not invoke tracker calculations or redraw its overlays.
    if resourceCardsPanelOpen() and gStates~=nil and gStates.resourceTracker~=nil then
        refreshResourceTrackerText()
        updateMoveDisplay()
    end
end

function M.copyCardSelection(selection,fromSave)
    if type(selection)~="table" then return nil end
    local result={}
    for _,field in ipairs({"effect","sideways"}) do
        if type(selection[field])=="string" then result[field]=selection[field] end
    end
    for _,field in ipairs({"repeatChoices","inventorySets"}) do
        local entries={}
        if fromSave then
            for _,entry in ipairs(type(selection[field])=="table" and selection[field] or {}) do
                local index=type(entry)=="table" and tonumber(entry.index) or nil
                if index~=nil and index>=1 and index%1==0 and type(entry.choice)=="string" then
                    entries[index]=entry.choice
                end
            end
        else
            for index,choice in pairs(type(selection[field])=="table" and selection[field] or {}) do
                if type(index)=="number" and index>=1 and index%1==0 and type(choice)=="string" then
                    entries[#entries+1]={index=index,choice=choice}
                end
            end
            table.sort(entries,function(a,b) return a.index<b.index end)
        end
        if next(entries)~=nil then result[field]=entries end
    end
    return next(result)~=nil and result or nil
end

function M.choicesSave(selectedResourceByGUID,trackerPrivate)
    if gStates==nil then return end
    local selected={}
    local active=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    if active~=nil and active.seatPos~=nil then
        local present={}
        for _,zoneGUID in ipairs({playerPlayAreas[active.seatPos],playerUnitAreas[active.seatPos]}) do
            local zone=zoneGUID~=nil and getObjectFromGUID(zoneGUID) or nil
            if zone~=nil then
                for _,obj in ipairs(zone.getObjects()) do present[obj.guid]=true end
            end
        end
        for guid,selection in pairs(selectedResourceByGUID) do
            if present[guid]==true and gameCards[guid]~=nil then
                selected[guid]=trackerPrivate.copyCardSelection(selection,false)
            end
        end
    end
    gStates.resourceCardSelectedChoices=selected
end

function M.choicesRestore(resetChoices,getChoices,trackerPrivate)
    resetChoices()
    local stored=gStates~=nil and gStates.resourceCardSelectedChoices or nil
    if type(stored)~="table" then return end
    for guid,selection in pairs(stored) do
        if type(guid)=="string" and gameCards[guid]~=nil then
            getChoices()[guid]=trackerPrivate.copyCardSelection(selection,true)
        end
    end
end

function M.panelChanged(open,trackerPrivate,combatConfig,combatCalcShutdown,clearAll,getChoices,resourceUnitsRebuildFromTable,renderSeat)
    local current=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
    if open==true and (current==nil or not resourceCardsSeatEnabled(current.seatPos)) then return end
    -- A newly shown panel may need a frame before TTS reports its attributes.
    -- That temporary state is not a player-requested OFF transition.
    if open==true and not resourceCardsPanelReady() then return end
    trackerPrivate.trackerStartupRequest=trackerPrivate.trackerStartupRequest+1
    if open~=true then
        -- Closing the tracker cancels a pending decision, not a physical
        -- transaction whose rewind point is already being stored.
        if combatConfig.woundConfirmation~=nil then
            combatConfig.woundConfirmClose()
        end
        trackerPrivate.trackerWasDisabled=true
        trackerPrivate.trackerSession=trackerPrivate.trackerSession+1
        -- Turn the tracker completely off: stop callbacks and remove its visuals.
        combatCalcShutdown()
        clearAll()
        unitHistoryHideControls()
        for guid in pairs(trackerPrivate.choiceResetGenerationByGUID) do
            trackerPrivate.choiceResetGenerationByGUID[guid]=trackerPrivate.choiceResetGenerationByGUID[guid]+1
        end
        trackerPrivate.crystalHighlightCleared={}
        trackerPrivate.unitHighlightBlocked={}
        -- Fresh starts never inherit manual resource offsets or an old avatar position.
        -- Keep moveCost: those are real day/night and manually adjusted terrain rules.
        local tracker=gStates~=nil and gStates.resourceTracker or nil
        if tracker~=nil then
            for _,category in ipairs({"move","influence","healing"}) do
                for field,value in pairs(tracker[category] or {}) do
                    if type(value)=="number" and not (category=="influence" and field=="reputation") then
                        tracker[category][field]=0
                    end
                end
            end
            tracker.playerPos=nil
        end
        clearMoveDisplayVisuals()
        if refreshUnitOfferHighlights~=nil then refreshUnitOfferHighlights() end
        return
    end
    -- Expanding after an OFF period rebuilds from scratch, not cached choices.
    local restart=trackerPrivate.trackerWasDisabled
    trackerPrivate.trackerWasDisabled=false
    if restart then refreshResourceTrackerReputation() end
    clearAll()
    if invalidateResourceTrackerDisplayCache~=nil then invalidateResourceTrackerDisplayCache() end
    unitHistoryRestoreCurrent()
    for guid,ready in pairs(gStates.unitReadyCardChoices or {}) do
        if ready and getChoices()[guid]==nil then
            getChoices()[guid]={effect="ready"}
        end
    end
    if restart and next(gStates.unitResourceActivations or {})==nil then
        resourceUnitsRebuildFromTable()
    end
    for guid in pairs(gStates.unitResourceActivations or {}) do
        unitHistoryRefreshToken(guid)
    end
    if attackAssignmentsRefreshReadyUI~=nil then attackAssignmentsRefreshReadyUI() end
    resourceUnitsRefreshButtons()
    if refreshUnitOfferHighlights~=nil then refreshUnitOfferHighlights() end
    local player=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    if player==nil then return end
    local seat=player.seatPos
    -- TTS may not expose the just-set ResourceTrackerDetail.active attribute
    -- until the next UI update. queueSeat rejects closed panels immediately,
    -- so invoking it in the same button callback could silently lose the scan.
    -- Wait only while opening, then read every physical object exactly once.
    local serial=trackerPrivate.generation[seat]
    safeWaitCondition("PlayerBoard.CardRecognition",function()
        if trackerPrivate.generation[seat]==serial and resourceCardsPanelOpen() then
            renderSeat(seat)
        end
    end,function()
        -- Closing or reopening the panel invalidates this pending request.
        return trackerPrivate.generation[seat]~=serial or resourceCardsPanelOpen()
    end,1)
end

function M.beforeTurnHandoff(nextSeat,resetChoices)
    if gStates==nil or gStates.firstStarted~=true then return end
    local current=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    if current==nil or current.seatPos==nextSeat then return end
    resourceCardsPanelChanged(false)
    resourceUnitsResetTurn()
    resetChoices()
    if gStates~=nil then gStates.resourceCardMoveRoles={} end
end

function M.afterTurnHandoff(previousSeat)
    if gStates==nil or gStates.firstStarted~=true then return end
    local current=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    if current==nil or current.seatPos==previousSeat then return end
    local enabled=resourceCardsSeatEnabled(current.seatPos)
    UI.setAttribute("CombatCalculatorHelp","active","false")
    UI.setAttribute("ResourceTrackerDetail","active",enabled and "true" or "false")
    -- The previous seat may have left terrain/combat submenus expanded.
    -- Preserve their visibility without squeezing them into the default height.
    resourceTrackerSyncLayout(enabled)
    if enabled then resourceCardsOnLoad() end
end

function M.onLoad(restoringSave,trackerPrivate)
    if restoringSave==true then trackerPrivate.restoreAssignmentsPending=true end
    if gStates==nil or gStates.firstStarted~=true then return end
    local current=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    if current~=nil and not resourceCardsSeatEnabled(current.seatPos) then
        UI.setAttribute("ResourceTrackerDetail","active","false")
        resourceTrackerSyncLayout(false)
        resourceCardsPanelChanged(false)
        return
    end
    -- TTS rewinds rebuild Global XML with a 35px collapsed root. Size the
    -- tracker first, then reveal its details, so the lower-anchored contents
    -- cannot cover the header/minimize button during the load transition.
    if restoringSave==true and current~=nil then
        resourceTrackerRestoreExpandedLayout()
    elseif UI.getAttribute("ResourceTrackerDetail","active")=="true" then
        -- Normal reopen/turn handoff keeps any chosen nested sections.
        resourceTrackerSyncLayout(true)
    end
    trackerPrivate.trackerStartupRequest=trackerPrivate.trackerStartupRequest+1
    local request=trackerPrivate.trackerStartupRequest
    safeWaitCondition("PlayerBoard.CardRecognition",function()
        if trackerPrivate.trackerStartupRequest==request and resourceCardsPanelReady() then
            if trackerPrivate.restoreAssignmentsPending==true then
                trackerPrivate.restoreAssignmentsPending=false
                attackAssignmentsRestore()
            end
            resourceCardsPanelChanged(true)
        end
    end,function()
        return trackerPrivate.trackerStartupRequest~=request or resourceCardsPanelReady()
    end,5,function()
        -- A panel that is still collapsed after the readiness wait stays
        -- OFF; it must never scan until the player explicitly expands it.
        if trackerPrivate.trackerStartupRequest==request and not resourceCardsPanelReady() then
            resourceCardsPanelChanged(false)
        end
    end)
end

return M
