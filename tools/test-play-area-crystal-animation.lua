-- Regression: play-area crystal visuals must not wait for physics to rest.
-- Run from repository root: lua5.2 tools/test-play-area-crystal-animation.lua
local function eq(actual,expected,label)
    if actual~=expected then
        error((label or "Mismatch")..": "..tostring(actual).." ~= "..tostring(expected),2)
    end
end

local timers, nextTimer={},0
Wait={stop=function(id) timers[id]=nil end}
safeWaitTime=function(_,callback,seconds)
    nextTimer=nextTimer+1
    timers[nextTimer]={callback=callback,seconds=seconds}
    return nextTimer
end
local function fireTimers(seconds)
    local ids={}
    for id,timer in pairs(timers) do
        if timer.seconds<=seconds then ids[#ids+1]=id end
    end
    table.sort(ids)
    for _,id in ipairs(ids) do
        local timer=timers[id]
        if timer~=nil then
            timers[id]=nil
            timer.callback()
        end
    end
end

local objects,inside={},{}
local zone={getObjects=function()
    local result={}
    for guid,inZone in pairs(inside) do
        if inZone then result[#result+1]=objects[guid] end
    end
    return result
end}
getObjectFromGUID=function(guid)
    if guid=="play-zone" then return zone end
    return objects[guid]
end
playerPlayAreas={"play-zone"}
isManaTokenFigurine=function(obj)
    return obj~=nil and obj.type=="Figurine"
end
local function crystal(guid)
    local effects={}
    local obj={guid=guid,type="Figurine",resting=false,held_by_color=nil}
    obj.AssetBundle={
        playTriggerEffect=function(index) effects[#effects+1]="burst"..tostring(index) end,
        playLoopingEffect=function(index) effects[#effects+1]="loop"..tostring(index) end
    }
    objects[guid]=obj
    return obj,effects
end
local function entry(obj)
    playerBoardCrystalEnteredPlayArea({obj=obj,objGUID=obj.guid,
        zoneInfo={kind="play",seatPos=1}})
end
local function departure(obj)
    playerBoardCrystalLeftPlayArea({obj=obj,objGUID=obj.guid,
        zoneInfo={kind="play",seatPos=1}})
end

dofile("src/PlayingGame/PlayerBoard/Events.lua")

-- A falling (not resting) crystal bursts immediately on zone entry.
local a,aeffects=crystal("crystalA")
inside[a.guid]=true
entry(a)
eq(aeffects[1],"burst0","Immediate effect")
eq(#aeffects,1,"No early looping")
fireTimers(1)
eq(aeffects[2],"loop1","Loop starts after burst")
inside[a.guid]=false
departure(a)
fireTimers(0.22)
eq(aeffects[3],"loop0","Leaving genuinely stops the loop")

-- A held crystal passing through the zone does not burst until dropped.
local b,beffects=crystal("crystalB")
b.held_by_color="Blue"
inside[b.guid]=true
entry(b)
fireTimers(1)
eq(#beffects,0,"Held crystal should not burst")
b.held_by_color=nil
playerBoardCrystalDropped(b)
eq(beffects[1],"burst0","Drop starts burst without resting")
fireTimers(1)
eq(beffects[2],"loop1","Loop after drop")

-- A shallow-zone exit during rearrangement must not turn off a newer entry.
b.held_by_color="Blue"
inside[b.guid]=false
departure(b)
inside[b.guid]=true
entry(b)
b.held_by_color=nil
playerBoardCrystalDropped(b)
eq(beffects[3],"burst0","New placement")
fireTimers(1)
eq(beffects[4],"loop1","Stale stop is canceled")
eq(#beffects,4,"No stale looping callback")

-- A lifted crystal remains visually active while held, but stops on drop outside.
b.held_by_color="Blue"
inside[b.guid]=false
departure(b)
fireTimers(0.22)
eq(#beffects,4,"No off during a temporary lift")
b.held_by_color=nil
playerBoardCrystalDropped(b)
eq(beffects[5],"loop0","Drop outside disables glow")

-- Dropping outside after crossing the zone never starts a false burst.
local c,ceffects=crystal("crystalC")
c.held_by_color="Blue"
inside[c.guid]=true
entry(c)
inside[c.guid]=false
departure(c)
c.held_by_color=nil
playerBoardCrystalDropped(c)
eq(#ceffects,1,"No burst after crossing without placement")
eq(ceffects[1],"loop0","Outside cleanup")

print("Play-area crystal animation regression passed")
