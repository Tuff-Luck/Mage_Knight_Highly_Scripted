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
