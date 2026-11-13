-- Regression: bound physics-settle work and skip empty Object UI writes.
-- Run from repository root: lua5.2 tools/test-optimization-stage-two.lua
local function read(path)
    local file=assert(io.open(path,"r"))
    local text=file:read("*a")
    file:close()
    return text
end
local function eq(actual,expected,label)
    assert(actual==expected,(label or "Mismatch")..": expected "..
        tostring(expected)..", got "..tostring(actual))
end
local function extract(source,first,last)
    local a=assert(source:find(first,1,true),first)
    local b=assert(source:find(last,a+#first,true),last)
    return source:sub(a,b-1)
end

-- A held Command must not poll every frame. Its eventual drop restarts one
-- bounded settle check, and returning it to its own Unit zone is a no-op.
local layout=read("src/PlayingGame/PlayerBoard/UnitLayout.lua")
local frames,waits,refreshes,stopped={},{},{},{}
local commands={}
local inside={}
local env={
    getObjectFromGUID=function(guid) return commands[guid] end,
    unitLayoutObjectInUnitArea=function(guid) return inside[guid]==true end,
    scheduleUnitLayoutRefresh=function(seat) refreshes[#refreshes+1]=seat end,
    safeWaitFrames=function(_,callback,delay)
        frames[#frames+1]={callback=callback,delay=delay}
        return #frames
    end,
    safeWaitCondition=function(_,callback,condition,timeout,onTimeout)
        waits[#waits+1]={callback=callback,condition=condition,
            timeout=timeout,onTimeout=onTimeout}
        return #waits
    end,
    Wait={stop=function(id) stopped[#stopped+1]=id end}
}
setmetatable(env,{__index=_G})
local implementation=layout:sub(assert(layout:find(
    "--Players routinely lift Command tokens",1,true)))
assert(load(implementation,"Command release watcher","t",env))()
local function runFrames()
    local ready=frames
    frames={}
    for _,entry in ipairs(ready) do entry.callback() end
end
local function command(guid,held,resting,moving)
    local obj={guid=guid,held_by_color=held,resting=resting,moving=moving}
    obj.isSmoothMoving=function() return obj.moving end
    commands[guid]=obj
    return obj
end

local held=command("aaa111","Blue",false,true)
env.scheduleUnitLayoutRefreshAfterCommandRelease(2,held.guid)
env.scheduleUnitLayoutRefreshAfterCommandRelease(2,held.guid)
eq(#waits,0,"held Command performs no per-frame polling")
held.held_by_color=nil
held.moving=false
env.unitLayoutCommandDropped(held)
eq(#frames,1,"drop schedules a single delayed check")
runFrames()
eq(#waits,1,"drop creates one settle check")
eq(waits[1].timeout,5,"Command settle check is bounded")
eq(waits[1].condition(),false,"still-bouncing Command is not settled")
held.resting=true
eq(waits[1].condition(),true,"Command settle condition detects resting")
waits[1].callback()
runFrames()
eq(#refreshes,1,"Unit layout refreshes after actual drop")
eq(refreshes[1],2,"original Unit seat refreshed")

local jitter=command("bbb222",nil,false,true)
env.scheduleUnitLayoutRefreshAfterCommandRelease(3,jitter.guid)
env.scheduleUnitLayoutRefreshAfterCommandRelease(3,jitter.guid)
eq(#waits,2,"duplicate settle events coalesced")
eq(waits[2].timeout,5,"jitter wait also bounded")
waits[2].onTimeout()
runFrames()
eq(#refreshes,2,"timeout safely reconciles remaining Units")

local returning=command("ccc333","Blue",false,true)
inside[returning.guid]=true
env.scheduleUnitLayoutRefreshAfterCommandRelease(1,returning.guid)
returning.held_by_color=nil
returning.resting=true
returning.moving=false
env.unitLayoutCommandDropped(returning)
runFrames()
eq(#waits,3,"returned Command gets a settle check")
waits[3].callback()
runFrames()
eq(#refreshes,2,"returned Command does not collapse its Unit zone")

local reheld=command("ddd444",nil,false,true)
env.scheduleUnitLayoutRefreshAfterCommandRelease(4,reheld.guid)
reheld.held_by_color="Blue"
waits[4].onTimeout()
eq(#refreshes,2,"timeout never moves layout while token is held")
reheld.held_by_color=nil
reheld.resting=true
reheld.moving=false
env.unitLayoutCommandDropped(reheld)
runFrames()
eq(#waits,5,"drop after timeout resumes the deferred check")
waits[5].callback()
runFrames()
eq(#refreshes,3,"deferred Command finally refreshes on drop")
assert(layout:find("function unitLayoutCommandDropped(obj)",1,true),
    "drop recovery callback must be available")

-- The real Source wait must have a finite timeout, and must not mirror the
-- face of an unsettled die at that timeout. A later entry can refresh it.
local events=read("src/PlayingGame/Events.lua")
local source=extract(events,"local function manaSourceDiceResting()",
    "\nfunction __onObjectEnterZone_raw(")
local die={type="Dice",resting=false}
local sourceZone={getObjects=function() return {die} end}
local manaWait,sourceUpdates,timeouts=nil,0,0
local manaEnv={
    GUID={zone={mana="source"}},
    gStates={firstStarted=true,tacticRemove=false,tacticShown=false},
    getObjectFromGUID=function(guid) if guid=="source" then return sourceZone end end,
    mirrorSourceUpdate=function() sourceUpdates=sourceUpdates+1 end,
    safeWaitCondition=function(_,callback,condition,timeout,onTimeout)
        manaWait={callback=callback,condition=condition,timeout=timeout,onTimeout=onTimeout}
        return 97
    end,
    Wait={stop=function() end},
    log=function() timeouts=timeouts+1 end,
    pulseSourceRandomizeFences=function() end,
}
setmetatable(manaEnv,{__index=_G})
local manaEnter=assert(load(source.."\nreturn handleManaZoneEnter",
    "Mana Source entry settle","t",manaEnv))()
manaEnter({zoneGUID="source",objType="Dice"})
eq(manaWait.timeout,10,"Mana Source settle check is bounded")
eq(manaWait.condition(),false,"Source rolling die is not yet ready")
die.resting=true
manaWait.callback()
eq(sourceUpdates,1,"settled Source updates mirror")
die.resting=false
manaEnter({zoneGUID="source",objType="Dice"})
manaWait.onTimeout()
eq(sourceUpdates,1,"timeout does not mirror a rolling face")
eq(timeouts,1,"stubborn dice report one timeout")
die.resting=true
manaEnter({zoneGUID="source",objType="Dice"})
manaWait.callback()
eq(sourceUpdates,2,"next Source event recovers normally")
assert(events:find("unitLayoutCommandDropped(dropped_object)",1,true),
    "global drop must resume held Command release checks")

-- Do not rebuild an Object UI that is already empty. Preserve clearing real
-- buttons/other script XML on cards and enemies exiting the play area.
local playerBoard=read("src/PlayingGame/PlayerBoard/Events.lua")
local clearSource=extract(playerBoard,
    "local function playerBoardClearObjectUIIfPresent(obj)",
    "\nfunction playerBoardZoneLeave(ctx)")
local clear=assert(load(clearSource..
    "\nreturn playerBoardClearObjectUIIfPresent","Object UI clearing"))()
local xml,clears={},0
local obj={UI={
    getXmlTable=function() return xml end,
    setXmlTable=function() clears=clears+1 end
}}
eq(clear(obj),false,"empty {} UI not replaced")
xml={{}}
eq(clear(obj),false,"empty {{}} UI not replaced")
eq(clears,0,"no writes for empty UI")
xml={{tag="Button",attributes={id="test"}}}
eq(clear(obj),true,"button UI is removed")
eq(clears,1,"nonempty UI replaced once")
assert(playerBoard:find("playerBoardClearObjectUIIfPresent(obj)",
    assert(playerBoard:find("function playerBoardZoneLeave(ctx)",1,true)),true),
    "play-area exits must use guarded clearing")

print("Optimization stage 2 settle and Object UI regressions passed")
