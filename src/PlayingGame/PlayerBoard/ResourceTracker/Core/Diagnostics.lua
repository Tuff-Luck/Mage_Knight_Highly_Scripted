-- Runtime-only Resource Tracker diagnostics. The coordinator supplies its
-- existing private state table so status always reads the current live queues.
return function(trackerPrivate)
    -- Opt-in ring trace for reproducing a stalled tracker without permanent log spam.
    -- Use the admin chat commands !trackertrace on/status/dump/off.
    trackerPrivate.traceEnabled=false
    trackerPrivate.traceLines={}
    trackerPrivate.traceSequence=0
    trackerPrivate.profileStats={}
    -- Lua CPU time when available; counts still work without os.clock.
    trackerPrivate.profileClock=function()
        if os~=nil and type(os.clock)=="function" then return os.clock() end
        return nil
    end
    trackerPrivate.profileStart=function()
        if trackerPrivate.traceEnabled then return trackerPrivate.profileClock() or false end
        return nil
    end
    trackerPrivate.profileFinish=function(name,started)
        if started==nil or not trackerPrivate.traceEnabled then return end
        local stats=trackerPrivate.profileStats[name] or {count=0,ms=0,maxMs=0,timed=0}
        trackerPrivate.profileStats[name]=stats
        stats.count=stats.count+1
        if type(started)=="number" then
            local now=trackerPrivate.profileClock()
            if type(now)=="number" then
                local ms=math.max(0,(now-started)*1000)
                stats.ms=stats.ms+ms
                stats.maxMs=math.max(stats.maxMs,ms)
                stats.timed=stats.timed+1
            end
        end
    end
    trackerPrivate.profileCount=function(name)
        trackerPrivate.profileFinish(name,false)
    end
    trackerPrivate.traceEvent=function(event,seat,guid,detail)
        if not trackerPrivate.traceEnabled then return end
        trackerPrivate.traceSequence=trackerPrivate.traceSequence+1
        local line=string.format("%04d %s seat=%s guid=%s %s",
            trackerPrivate.traceSequence,tostring(event),tostring(seat or "-"),
            tostring(guid or "-"),tostring(detail or ""))
        local lines=trackerPrivate.traceLines
        lines[#lines+1]=line
        if #lines>180 then table.remove(lines,1) end
    end

    trackerPrivate.traceCommand=function(command,playerColor)
        command=command or "status"
        if command=="on" then
            trackerPrivate.traceEnabled=true
            trackerPrivate.traceLines={}
            trackerPrivate.traceSequence=0
            trackerPrivate.profileStats={}
            trackerPrivate.traceEvent("trace.enabled")
        elseif command=="off" then
            trackerPrivate.traceEvent("trace.disabled")
            trackerPrivate.traceEnabled=false
        elseif command=="dump" then
            log("[TrackerTrace] BEGIN "..tostring(#trackerPrivate.traceLines).." events")
            for _,line in ipairs(trackerPrivate.traceLines) do
                log("[TrackerTrace] "..line)
            end
            log("[TrackerTrace] END")
        elseif command~="status" then
            return false
        end
        local movements={}
        for guid,movement in pairs(trackerPrivate.playCardMovements or {}) do
            local obj=getObjectFromGUID(guid)
            local held=obj~=nil and obj.held_by_color or nil
            local smooth=obj~=nil and obj.isSmoothMoving~=nil and obj.isSmoothMoving() or false
            movements[#movements+1]=guid.."(seat="..tostring(movement.seatPos)
                ..",held="..tostring(held)..",smooth="..tostring(smooth)
                ..",watch="..tostring(movement.releasing)
                ..",samples="..tostring(movement.samples)..")"
        end
        table.sort(movements)
        local seat=turnOrder~=nil and gStates~=nil
            and turnOrder[gStates.turnNumber]~=nil
            and turnOrder[gStates.turnNumber].seatPos or nil
        local pending=seat~=nil and trackerPrivate.pendingSeatSettles[seat] or nil
        local pendingCount=0
        for _ in pairs(pending or {}) do pendingCount=pendingCount+1 end
        local status="Tracker trace "..(trackerPrivate.traceEnabled and "ON" or "OFF")
            .."; panel="..tostring(resourceCardsPanelOpen())
            .."; seat="..tostring(seat)
            .."; renderQueued="..tostring(seat~=nil and trackerPrivate.pendingSeatRender[seat] or nil)
            .."; settleWaits="..pendingCount
            .."; movements="..(#movements>0 and table.concat(movements,", ") or "none")
            .."; events="..#trackerPrivate.traceLines
        log("[TrackerTrace] "..status)
        if command=="dump" or command=="status" then
            local names={}
            for name in pairs(trackerPrivate.profileStats) do names[#names+1]=name end
            table.sort(names)
            for _,name in ipairs(names) do
                local stats=trackerPrivate.profileStats[name]
                local timing=stats.timed>0 and string.format(
                    " total=%.2fms avg=%.2fms max=%.2fms",stats.ms,stats.ms/stats.timed,stats.maxMs)
                    or ""
                log("[TrackerProfile] "..name.." count="..stats.count..timing)
            end
        end
        if playerColor~=nil then
            broadcastToColor(status,playerColor,{0.7,0.9,1})
        end
        return true
    end
end
