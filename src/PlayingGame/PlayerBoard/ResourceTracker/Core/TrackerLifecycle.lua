-- Cohesive TrackerLifecycle services; preserve original lexical and factory boundaries.

-- ScanScheduler
local scheduler=(function()
-- Coalesced settled-object scans and per-seat generation cancellation. Uses existing protected waits; no independent tracker state.
local M={}

function M.schedule(seatPos,trackerPrivate,renderSeat)
    local generation=trackerPrivate.generation[seatPos] or 0
    if trackerPrivate.pendingSeatRender[seatPos]==generation then
        if trackerPrivate.traceEnabled then trackerPrivate.traceEvent("render.coalesced",seatPos) end
        return
    end
    trackerPrivate.pendingSeatRender[seatPos]=generation
    if trackerPrivate.traceEnabled then trackerPrivate.traceEvent("render.queued",seatPos,nil,"gen="..generation) end
    safeWaitFrames("PlayerBoard.CardRecognition",function()
        if trackerPrivate.pendingSeatRender[seatPos]~=generation then return end
        trackerPrivate.pendingSeatRender[seatPos]=nil
        if (trackerPrivate.generation[seatPos] or 0)==generation and resourceCardsPanelOpen() then
            renderSeat(seatPos)
        end
    end,1)
end

function M.queue(seatPos,triggerGUID,trackerPrivate,scheduleSeatRender)
    if not resourceCardsPanelOpen() or seatPos==nil or seatPos<1 or seatPos>4 then return end
    if triggerGUID==nil then scheduleSeatRender(seatPos) return end
    local generation=trackerPrivate.generation[seatPos] or 0
    local waits=trackerPrivate.pendingSeatSettles[seatPos]
    if waits==nil then waits={} trackerPrivate.pendingSeatSettles[seatPos]=waits end
    -- Zone entry and drop frequently report the same moving object.
    if waits[triggerGUID]==generation then
        if trackerPrivate.traceEnabled then trackerPrivate.traceEvent("settle.coalesced",seatPos,triggerGUID) end
        return
    end
    local obj=getObjectFromGUID(triggerGUID)
    if obj==nil or trackerPrivate.readyForXZ(obj) then
        if trackerPrivate.traceEnabled then trackerPrivate.traceEvent("settle.ready",seatPos,triggerGUID) end
        scheduleSeatRender(seatPos)
        return
    end
    waits[triggerGUID]=generation
    if trackerPrivate.traceEnabled then trackerPrivate.traceEvent("settle.wait",seatPos,triggerGUID) end
    local function stillCurrent()
        return (trackerPrivate.generation[seatPos] or 0)==generation
            and trackerPrivate.pendingSeatSettles[seatPos]==waits
            and waits[triggerGUID]==generation and resourceCardsPanelOpen()
    end
    local function settled()
        if not stillCurrent() then return end
        waits[triggerGUID]=nil
        if trackerPrivate.traceEnabled then trackerPrivate.traceEvent("settle.done",seatPos,triggerGUID) end
        scheduleSeatRender(seatPos)
    end
    safeWaitCondition("PlayerBoard.CardRecognition",settled,function()
        if not stillCurrent() then return true end
        local live=getObjectFromGUID(triggerGUID)
        return live==nil or trackerPrivate.readyForXZ(live)
    end,8,function()
        -- A perpetually held/rolling token must not keep the watcher alive
        -- or delay other objects' refreshes. Its eventual drop queues anew.
        if trackerPrivate.pendingSeatSettles[seatPos]==waits
            and waits[triggerGUID]==generation then
            waits[triggerGUID]=nil
            if trackerPrivate.traceEnabled then trackerPrivate.traceEvent("settle.timeout",seatPos,triggerGUID) end
        end
    end)
end

function M.sourceChanged(trackerPrivate,queueSeat)
    local current=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
    if current~=nil and resourceCardsPanelOpen() then
        if trackerPrivate.traceEnabled then trackerPrivate.traceEvent("source.changed",current.seatPos) end
        queueSeat(current.seatPos,nil)
    end
end

return M
end)()

-- TrackerLifecycle
local lifecycle=(function()
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

-- Dynamic reward and puppet GUIDs are not guaranteed to exist in gameCards.
-- Save a validated source kind, so restoring during startup need not inspect
-- an object whose TTS script has not yet loaded.
local function selectionKind(obj,guid,resourceObjectKind)
    if gameCards[guid]~=nil then return "card" end
    if skillTokens~=nil and skillTokens[guid]~=nil then return "skill" end
    local kind=obj~=nil and resourceObjectKind~=nil and resourceObjectKind(obj) or nil
    if kind=="factionReward" or kind=="puppet" or kind=="wound" then return kind end
end

function M.choicesSave(selectedResourceByGUID,trackerPrivate,resourceObjectKind)
    if gStates==nil then return end
    local selected={}
    local active=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    if active~=nil and active.seatPos~=nil then
        local present={}
        for _,zoneGUID in ipairs({playerPlayAreas[active.seatPos],playerUnitAreas[active.seatPos]}) do
            local zone=zoneGUID~=nil and getObjectFromGUID(zoneGUID) or nil
            if zone~=nil then
                for _,obj in ipairs(zone.getObjects()) do present[obj.guid]=obj end
            end
        end
        for guid,selection in pairs(selectedResourceByGUID) do
            local obj=present[guid]
            local kind=obj~=nil and selectionKind(obj,guid,resourceObjectKind) or nil
            if kind~=nil then
                local copy=trackerPrivate.copyCardSelection(selection,false)
                if copy~=nil then
                    copy.sourceKind=kind
                    selected[guid]=copy
                end
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
        if type(guid)=="string" and type(selection)=="table" then
            local kind=selectionKind(nil,guid,nil)
            local dynamic=guid:match("^[0-9a-f]+$")~=nil and #guid==6
                and (selection.sourceKind=="factionReward" or selection.sourceKind=="puppet"
                    or selection.sourceKind=="wound")
            if kind~=nil or dynamic then
                getChoices()[guid]=trackerPrivate.copyCardSelection(selection,true)
            end
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
    if gStates~=nil then
        gStates.resourceCardMoveRoles={}
        gStates.resourceCardSelectedChoices={}
        gStates.resourceCardConversions={}
    end
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
end)()

return {scheduler=scheduler,lifecycle=lifecycle}
