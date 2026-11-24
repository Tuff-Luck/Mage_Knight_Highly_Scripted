-- Regressions for the play-area entry optimization pass.
-- Run from repository root: lua5.2 tools/test-play-area-entry-optimizations.lua
local function read(path)
    local file=assert(io.open(path,"r"))
    local data=file:read("*a")
    file:close()
    return data
end
local function extract(source,first,last)
    local a=assert(source:find(first,1,true),first)
    local b=assert(source:find(last,a+#first,true),last)
    return source:sub(a,b-1)
end
local function eq(actual,expected,label)
    assert(actual==expected,(label or "Mismatch")..": expected "..
        tostring(expected)..", got "..tostring(actual))
end

-- Default scaling must be a true no-op; changed scales must still reconcile.
local scale=read("src/PlayingGame/PlayerBoard/Scale.lua")
local scaleSource=extract(scale,"function schedulePlayAreaScale(seat)",
    "\n-- Object-attached XML UI")
local scaleFrames,scaleStops={},0
local scaleSettings={step=20}
local scaleEnv={
    gStates={playAreaScaledObjects={}},
    playAreaScaleWait={},
    playAreaScaleSettings=function() return scaleSettings end,
    safeWaitFrames=function(_,callback)
        scaleFrames[#scaleFrames+1]=callback
        return #scaleFrames
    end,
    Wait={stop=function() scaleStops=scaleStops+1 end}
}
setmetatable(scaleEnv,{__index=_G})
local scheduleScale=assert(load(scaleSource..
    "\nreturn schedulePlayAreaScale","Play area scaling","t",scaleEnv))()
scheduleScale(1)
eq(#scaleFrames,0,"100 percent requires no area scan")
scaleEnv.gStates.playAreaScaledObjects.card={seat=1}
scheduleScale(1)
eq(#scaleFrames,1,"existing scaled objects still reconcile")
scaleSettings.step=18
scaleEnv.gStates.playAreaScaledObjects={}
scheduleScale(1)
eq(#scaleFrames,2,"90 percent schedules a refresh")
eq(scaleStops,1,"only one outstanding scale refresh")

-- Two held objects create two watchers, but only one per seat
-- render is scheduled for each frame. One held crystal cannot starve a card.
local cards=read("src/PlayingGame/PlayerBoard/CardRecognition.lua")
local queueSource=extract(cards,"local function scheduleSeatRender(seatPos)",
    "\nfunction resourceCardsSourceChanged()")
local readySource=extract(cards,"trackerPrivate.readyForXZ=function(obj)",
    "-- Magic Talent's strong side")
local objects={
    a={guid="a",held_by_color="Blue",resting=false},
    b={guid="b",held_by_color="Blue",resting=false},
    c={guid="c",held_by_color="Blue",resting=false},
    falling={guid="falling",held_by_color=nil,resting=false},
    die={guid="die",type="Dice",held_by_color=nil,resting=false}
}
for _,obj in pairs(objects) do obj.isSmoothMoving=function() return false end end
local cardFrames,cardWaits,renderCount={}, {}, 0
local panelOpen=true
local tracker={generation={},pendingSeatSettles={},pendingSeatRender={}}
local cardEnv={
    trackerPrivate=tracker,
    resourceCardsPanelOpen=function() return panelOpen end,
    getObjectFromGUID=function(guid) return objects[guid] end,
    renderSeat=function() renderCount=renderCount+1 end,
    safeWaitFrames=function(_,callback)
        cardFrames[#cardFrames+1]=callback
        return #cardFrames
    end,
    safeWaitCondition=function(_,callback,condition,timeout,onTimeout)
        cardWaits[#cardWaits+1]={callback=callback,condition=condition,
            timeout=timeout,onTimeout=onTimeout}
    end
}
setmetatable(cardEnv,{__index=_G})
local queue=assert(load(readySource.."\n"..queueSource.."\nreturn queueSeat",
    "Per seat render scheduler","t",cardEnv))()
local function fireCardFrames()
    local pending=cardFrames
    cardFrames={}
    for _,callback in ipairs(pending) do callback() end
end
queue(1,"a")
queue(1,"a")
eq(#cardWaits,1,"duplicate entry and drop share one watcher")
queue(1,"b")
eq(#cardWaits,2,"unrelated moving object has own watcher")
eq(cardWaits[1].timeout,8,"settling remains bounded")
queue(1,nil)
queue(1,nil)
eq(#cardFrames,1,"same frame gets only one render request")
fireCardFrames()
eq(renderCount,1,"unrelated source updates despite held objects")
objects.a.held_by_color=nil
objects.a.resting=true
eq(cardWaits[1].condition(),true,"first object has settled")
eq(cardWaits[2].condition(),false,"second object is still held")
cardWaits[1].callback()
fireCardFrames()
eq(renderCount,2,"settled object triggers its own redraw")
cardWaits[2].onTimeout()
objects.b.held_by_color=nil
objects.b.resting=true
queue(1,"b")
fireCardFrames()
eq(renderCount,3,"late drop recovers a timed-out object")
queue(1,"c")
eq(#cardWaits,3,"third object has its own watcher")
queue(1,"falling")
eq(#cardWaits,3,"released falling card does not wait for Y")
fireCardFrames()
eq(renderCount,4,"released falling card refreshes immediately")
queue(1,"die")
eq(#cardWaits,3,"released die does not wait for resting")
fireCardFrames()
eq(renderCount,5,"released die refreshes despite resting=false")
objects.die.isSmoothMoving=function() return true end
queue(1,"die")
eq(#cardWaits,4,"smooth-moving die still waits")
objects.die.isSmoothMoving=function() return false end
eq(cardWaits[4].condition(),true,"die is ready after smooth movement ends")
cardWaits[4].callback()
fireCardFrames()
eq(renderCount,6,"smooth-movement completion refreshes die")
panelOpen=false
tracker.generation[1]=1
tracker.pendingSeatSettles={}
tracker.pendingSeatRender={}
eq(cardWaits[3].condition(),true,"closing invalidates queued watcher")
cardWaits[3].callback()
eq(#cardFrames,0,"closed tracker does not reschedule render")

-- Ordinary cards and mana do not require a separate 10-second player-board
-- entry watcher; monsters, Banner states and Unit work still do.
local events=read("src/PlayingGame/Events.lua")
local filterSource=extract(events,"local function playerBoardSettledEntryNeeded(ctx)",
    "\nlocal function handlePlayerBoardZoneEnter(ctx)")
local filterEnv={
    gameCards={basic={cardType="Action"},banner={half="halfBanner"}},
    monsterPugs={enemy={}},
    mageKnightAvatarGUIDs={},
    gStates={ruinMonsters={}},
    GUID={card={bannerOfCommandToken="commandBanner"},
        skill={masterOfChaos="chaos"}},
    unitLayoutIsCommand=function(obj) return obj.command==true end,
    unitLayoutIsWound=function() return false end,
    scriptObjectId=function(obj) return obj.name end
}
setmetatable(filterEnv,{__index=_G})
local shouldSettle=assert(load(filterSource.."\nreturn playerBoardSettledEntryNeeded",
    "Player board settle filter","t",filterEnv))()
local function entry(guid,kind,objType,name)
    return {objGUID=guid,objType=objType or "Card",
        obj={guid=guid,name=name or "",command=false},
        zoneInfo={kind=kind}}
end
eq(shouldSettle(entry("basic","play")),false,"basic card has immediate path")
eq(shouldSettle(entry("enemy","play","Token")),true,"enemy keeps settled entry")
eq(shouldSettle(entry("banner","play")),true,"Banner preserves state change")
eq(shouldSettle(entry("die","crystal","Dice")),false,"crystal die skips settle")
eq(shouldSettle(entry("potion","crystal","Token","Mana Potion")),true,
    "potion records settled position")
eq(shouldSettle(entry("command","unit","Token")),false,
    "unrelated token does not need Unit settled work")
local cmd=entry("command","unit","Token")
cmd.obj.command=true
eq(shouldSettle(cmd),true,"Command token keeps Unit settled work")
assert(events:find("playerBoardObjectDropped(dropped_object)",1,true),
    "drop resumes transient UI cleanup")
assert(cards:find("local relevantZones",1,true),
    "drop fallback narrows zone scanning by resource type")
local board=read("src/PlayingGame/PlayerBoard/Events.lua")
assert(board:find("if affectsMainUI then",1,true),
    "play-area main UI updates must be filtered")
-- Mana eligibility must come from current zone membership, not a historical
-- drop registry or recovery based only on X/Z.
assert(not cards:find("unitManaCandidatesBySeat",1,true),
    "Obsolete above-zone mana candidate registry must be removed")
assert(not cards:find("highestCardY",1,true),
    "Above-zone mana must not be reinserted into play")

print("Play-area entry optimizations regression passed")
