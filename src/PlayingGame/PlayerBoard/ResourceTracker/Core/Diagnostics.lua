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
    trackerPrivate.profileFinish=function(name,started,finished)
        if started==nil or not trackerPrivate.traceEnabled then return end
        local stats=trackerPrivate.profileStats[name] or {count=0,ms=0,maxMs=0,timed=0}
        trackerPrivate.profileStats[name]=stats
        stats.count=stats.count+1
        if type(started)=="number" then
            local now=finished
            if now==nil then now=trackerPrivate.profileClock() end
            if type(now)=="number" then
                local ms=math.max(0,(now-started)*1000)
                stats.ms=stats.ms+ms
                stats.maxMs=math.max(stats.maxMs,ms)
                stats.timed=stats.timed+1
            end
        end
    end
    -- Consecutive stages share a single clock reading at each boundary.
    -- A false timestamp means timing is unavailable, but counts still work.
    -- Disabled profiling does not read the clock or allocate a stats record.
    trackerPrivate.profileCheckpoint=function(name,started)
        if started==nil or not trackerPrivate.traceEnabled then return nil end
        local now=trackerPrivate.profileClock() or false
        trackerPrivate.profileFinish(name,started,now)
        return now
    end
    trackerPrivate.profileCount=function(name)
        trackerPrivate.profileFinish(name,false)
    end
    -- Group actual UI writes by displayed column, not by individual element ID.
    -- Use one elapsed measurement for both the total and the column breakdown.
    trackerPrivate.profileUIWrite=function(id,started)
        if started==nil or not trackerPrivate.traceEnabled then return end
        local finished=trackerPrivate.profileClock() or false
        trackerPrivate.profileFinish("ui.setAttribute",started,finished)
        local family=id:match("^CombatSourceSlot%d+(%a+)%d+")
            or id:match("^CombatSourceGrid%d+(%a+)$")
            or id:match("^CombatSourceCell%d+(%a+)$")
        if family~="range" and family~="block" and family~="attack" then
            local column=id:match("^CombatEnemyRow%d+(%a+)$")
            if id:match("^CombatEnemyResultToggle") or id=="CombatResultHeader" then column="Result"
            elseif id:match("^CombatEnemyAttackCell") or id:match("^CombatEnemyAttackCycle")
                or id=="CombatEnemyAttackHeader" then column="Attacks"
            elseif id=="CombatRangeSiegeHeader" then family="range"
            elseif id=="CombatBlockHeader" then family="block"
            elseif id=="CombatAssignedAttackHeader" then family="attack"
            elseif id:match("^CombatEnemyNameCell") or id=="CombatMonsterHeader" then column="Name"
            elseif id=="CombatArmourHeader" then column="Armour"
            elseif id=="CombatDefenceTraitsHeader" then column="Traits"
            elseif id=="CombatOffenceHeader" then column="Offence" end
            if family~="range" and family~="block" and family~="attack" then
                if column=="Result" or column=="Attacks" or column=="Name" or column=="Armour"
                    or column=="Traits" or column=="Offence" then family=column
                elseif id:match("^CombatTotal") or id:match("^CombatApplyWounds")
                    or id:match("^CombatKnockoutWarning") then family="wounds"
                else family="layout" end
            end
        end
        trackerPrivate.profileFinish("ui.write."..family,started,finished)
    end

    -- Heap sampling is observational only: never force or stop garbage collection.
    -- Some TTS Lua environments restrict collectgarbage; fall back to timings.
    trackerPrivate.profileHeap=function()
        if type(collectgarbage)~="function" then return nil end
        local ok,kb=pcall(collectgarbage,"count")
        return ok and type(kb)=="number" and kb or nil
    end
    trackerPrivate.profileMemory={}
    trackerPrivate.profileScanStart=function()
        if not trackerPrivate.traceEnabled then return nil end
        local memory=trackerPrivate.profileMemory
        local kb
        if not memory.unavailable then
            kb=trackerPrivate.profileHeap()
            if kb==nil then memory.unavailable=true end
        end
        return {started=trackerPrivate.profileStart(),kb=kb}
    end
    trackerPrivate.profileScanFinish=function(sample)
        if sample==nil or not trackerPrivate.traceEnabled then return end
        local finished=trackerPrivate.profileClock() or false
        trackerPrivate.profileFinish("tracker.scan",sample.started,finished)
        if sample.kb==nil then return end
        local memory=trackerPrivate.profileMemory
        local kb=trackerPrivate.profileHeap()
        if kb==nil then memory.unavailable=true return end
        local delta=kb-sample.kb
        memory.count=(memory.count or 0)+1
        memory.firstKB=memory.firstKB or sample.kb
        memory.lastKB=kb
        memory.minKB=math.min(memory.minKB or sample.kb,sample.kb,kb)
        memory.maxKB=math.max(memory.maxKB or sample.kb,sample.kb,kb)
        memory.totalDelta=(memory.totalDelta or 0)+delta
        if delta<0 then
            memory.drops=(memory.drops or 0)+1
            memory.dropKB=(memory.dropKB or 0)-delta
        end
        if type(sample.started)=="number" and type(finished)=="number" then
            local ms=math.max(0,(finished-sample.started)*1000)
            if memory.slowestMs==nil or ms>memory.slowestMs then
                memory.slowestMs=ms
                memory.slowestDelta=delta
            end
            -- Record each completed scan for correlation, without spamming trace
            -- events or altering the ordinary render.* event sequence.
            local samples=memory.samples or {}
            memory.samples=samples
            samples[#samples+1]={ms=ms,delta=delta}
            if #samples>12 then table.remove(samples,1) end
        end
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
            trackerPrivate.profileMemory={}
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
            local memory=trackerPrivate.profileMemory
            if memory.count~=nil then
                log(string.format("[TrackerProfile] heap scans=%d first=%.1fKB last=%.1fKB min=%.1fKB max=%.1fKB netScanDelta=%+.1fKB drops=%d dropKB=%.1fKB",
                    memory.count,memory.firstKB,memory.lastKB,memory.minKB,memory.maxKB,
                    memory.totalDelta,memory.drops or 0,memory.dropKB or 0))
                if memory.slowestMs~=nil then
                    log(string.format("[TrackerProfile] heap.slowestScan %.2fms delta=%+.1fKB",
                        memory.slowestMs,memory.slowestDelta))
                    local samples={}
                    for _,sample in ipairs(memory.samples or {}) do
                        samples[#samples+1]=string.format("%.2fms/%+.1fKB",sample.ms,sample.delta)
                    end
                    log("[TrackerProfile] heap.recent "..table.concat(samples," "))
                end
            elseif memory.unavailable then
                log("[TrackerProfile] heap unavailable (Lua memory sampling restricted)")
            end
        end
        if playerColor~=nil then
            broadcastToColor(status,playerColor,{0.7,0.9,1})
        end
        return true
    end
end
