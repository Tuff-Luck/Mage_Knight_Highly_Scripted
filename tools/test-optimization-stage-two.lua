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
local layout=read("src/PlayingGame/PlayerBoard/Units/UnitLayout.lua")
local frames,waits,refreshes,stopped={},{},{},{}
local commands={}
local inside={}
local env={
    getObjectFromGUID=function(guid) return commands[guid] end,
    playerUnitAreas={[1]="unit1",[2]="unit2",[3]="unit3",[4]="unit4"},
    unitLayoutObjectOnMat=function() return false end,
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
local layoutStart=assert(layout:find("--Players routinely lift Command tokens",1,true))
local implementation=layout:sub(layoutStart)
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
-- Position-based Unit layout checks deliberately ignore the resting flag.
-- A released non-smooth token can be reconciled while falling in Y.
eq(waits[1].condition(),true,
    "released non-smooth Command may reconcile before physics resting")
held.resting=true
eq(waits[1].condition(),true,"settled Command remains eligible")
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
local events=read("src/PlayingGame/GameFlow/Events.lua")
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

-- Source arrivals must protect settled neighbours before extraction, without
-- locking rolling or newly spawning dice. Overlapping arrivals share the lock.
do
    local manaSource=read("src/PlayingGame/Components/ManaSource.lua")
    local protection=extract(manaSource,"local sourceArrivalLocks={}",
        "\nscheduleReturnedSourceMirror=function")
    local objects,zoneDice,arrivalFrames,arrivalWaits={},{},{},{}
    local function makeDie(guid,resting,locked,spawning)
        local obj={guid=guid,type="Dice",resting=resting,spawning=spawning}
        obj.getLock=function() return locked end
        obj.setLock=function(value) locked=value end
        objects[guid]=obj
        zoneDice[#zoneDice+1]=obj
        return obj
    end
    local settled=makeDie("old",true,false,false)
    local rolling=makeDie("rolling",false,false,false)
    local manuallyLocked=makeDie("manual",true,true,false)
    local held=makeDie("held",true,false,false)
    held.held_by_color="Blue"
    local zone={getObjects=function() return zoneDice end}
    local arrivalEnv={
        GUID={zone={mana="source"}},
        getObjectFromGUID=function(guid) return guid=="source" and zone or objects[guid] end,
        safeWaitFrames=function(_,callback,delay)
            arrivalFrames[#arrivalFrames+1]=callback
            return #arrivalFrames
        end,
        safeWaitCondition=function(_,callback,condition,timeout,onTimeout)
            arrivalWaits[#arrivalWaits+1]={callback=callback,condition=condition,timeout=timeout,onTimeout=onTimeout}
            return #arrivalWaits
        end,
    }
    setmetatable(arrivalEnv,{__index=_G})
    local spawn=assert(load(protection.."\nreturn spawnReturnedSourceDie","Source arrival protection","t",arrivalEnv))()
    local first,second
    local bag={takeObject=function(params)
        eq(settled.getLock(),true,"neighbour locked before extraction")
        eq(rolling.getLock(),false,"rolling neighbour left free")
        eq(held.getLock(),false,"held die not locked")
        if first~=nil then eq(first.getLock(),false,"first arrival not locked during second spawn") end
        return makeDie(params.guid,true,false,true)
    end}
    first=spawn(bag,{guid="first"})
    first.spawning=false -- transient resting before the physics check starts
    second=spawn(bag,{guid="second"})
    eq(second.getLock(),false,"second arrival remains unlocked")
    arrivalFrames[1]()
    arrivalFrames[2]()
    first.resting=false
    eq(arrivalWaits[1].condition(),false,"first rolling arrival not settled")
    eq(arrivalWaits[2].condition(),false,"second still spawning")
    first.resting=true
    eq(arrivalWaits[1].condition(),true,"first settled")
    arrivalWaits[1].callback()
    eq(settled.getLock(),true,"second arrival still owns protection")
    eq(arrivalWaits[2].timeout,10,"arrival wait bounded")
    arrivalWaits[2].onTimeout()
    eq(settled.getLock(),false,"final timeout releases temporary lock")
    eq(manuallyLocked.getLock(),true,"manual lock preserved")
    eq(first.getLock(),false,"first arrival remains free")
    eq(second.getLock(),false,"second arrival remains free")

    first.resting=false
    second.resting=false
    eq(spawn({takeObject=function(params) return nil end},{}),nil,"empty bag safe")
    eq(settled.getLock(),false,"failed extraction releases temporary lock")
    local third=spawn({takeObject=function(params) return makeDie("third",false,false,false) end},{})
    arrivalFrames[3]()
    objects[third.guid]=nil
    eq(arrivalWaits[3].condition(),true,"destroyed arrival resolves")
    arrivalWaits[3].callback()
    eq(settled.getLock(),false,"destroyed arrival releases protection")

    -- Ordinary cleanup relocates existing dice directly, instead of extracting
    -- replacement dice from a bag. Lock before either move or randomize.
    local function cleanupDie(guid,expectProtection)
        local returned={guid=guid,type="Dice",resting=true}
        objects[guid]=returned
        local locked=false
        returned.getLock=function() return locked end
        returned.setLock=function(value) locked=value end
        returned.setPosition=function(position)
            eq(settled.getLock(),expectProtection,"neighbour lock before cleanup relocation")
            eq(locked,false,"returning die unlocked before relocation")
            zoneDice[#zoneDice+1]=returned
        end
        returned.randomize=function()
            eq(settled.getLock(),expectProtection,"neighbour lock before cleanup roll")
            eq(locked,false,"returning die free to roll")
            returned.resting=false
        end
        return returned
    end
    local cleanupA=cleanupDie("cleanupA",true)
    local cleanupB=cleanupDie("cleanupB",true)
    arrivalEnv.manaSourceReturnDie(cleanupA,{0,2,0},true)
    arrivalEnv.manaSourceReturnDie(cleanupB,{0,2,0},true)
    eq(cleanupA.getLock(),false,"first cleanup die can bounce off second")
    eq(cleanupB.getLock(),false,"second cleanup die can bounce off first")
    arrivalFrames[4]()
    arrivalFrames[5]()
    eq(arrivalWaits[4].condition(),false,"first cleanup roll in progress")
    cleanupA.resting=true
    arrivalWaits[4].callback()
    eq(settled.getLock(),true,"neighbour protected until second cleanup die settles")
    cleanupB.resting=true
    eq(arrivalWaits[5].condition(),true,"last cleanup die settled")
    arrivalWaits[5].callback()
    eq(settled.getLock(),false,"cleanup releases neighbour")
    eq(manuallyLocked.getLock(),true,"cleanup preserves manual lock")
    local resetDie=cleanupDie("roundReset",false)
    arrivalEnv.manaSourceReturnDie(resetDie,{0,2,0},false)
    eq(#arrivalFrames,5,"round reset does not start protection")
    local combat=read("src/PlayingGame/Combat/Combat.lua")
    assert(combat:find("manaSourceReturnDie(die,",1,true),
        "end-turn cleanup must use protected Source return")
end

-- Preserve unrelated Object UI while removing only tracker-owned controls.
-- A thin-zone lift must never replace the whole XML table on the exit frame.
local playerBoard=read("src/PlayingGame/PlayerBoard/Events.lua")
local clearSource=extract(playerBoard,
    "local function playerBoardClearObjectUIIfPresent(obj)",
    "\n-- A card can be released above")
local clear=assert(load(clearSource..
    "\nreturn playerBoardClearObjectUIIfPresent","Object UI clearing"))()
local xml,clears,lastXml={},0,nil
local obj={UI={
    getXmlTable=function() return xml end,
    setXmlTable=function(newXml) clears=clears+1 lastXml=newXml end
}}
eq(clear(obj),false,"empty {} UI not replaced")
xml={{}}
eq(clear(obj),false,"empty {{}} UI not replaced")
eq(clears,0,"no writes for empty UI")
xml={{tag="Button",attributes={id="ExternalClaim"}}}
eq(clear(obj),false,"unrelated UI is preserved")
eq(clears,0,"no writes for unrelated UI")
xml={{tag="Button",attributes={id="ResourceCardChoice_test"}},
     {tag="Button",attributes={id="ExternalClaim"}}}
eq(clear(obj),true,"tracker-owned UI is removed")
eq(clears,1,"one write for owned controls")
eq(#lastXml,1,"unrelated UI is retained")
eq(lastXml[1].attributes.id,"ExternalClaim","claim button survives")
assert(playerBoard:find("playerBoardScheduleUICleanup(objGUID)",1,true),
    "exits must defer Object UI cleanup")
assert(playerBoard:find("function playerBoardObjectDropped(obj)",1,true),
    "drop callback must resume a held cleanup")
print("Optimization stage 2 settle and Object UI regressions passed")
