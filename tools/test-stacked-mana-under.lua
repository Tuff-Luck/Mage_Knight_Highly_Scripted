-- Overlapping mana payments prefer the highest eligible played card, and
-- native U/Place Under resamples mana in the live play zone.
-- Run from repository root: lua5.2 tools/test-stacked-mana-under.lua
package.path="src/?.lua;"..package.path
local function read(path)
    local file=assert(io.open(path,"r"))
    local source=file:read("*a")
    file:close()
    return source
end
local function section(source,first,last)
    local a=assert(source:find(first,1,true),"Missing "..first)
    local b=assert(source:find(last,a+#first,true),"Missing "..last)
    return source:sub(a,b-1)
end
local source=read("src/PlayingGame/PlayerBoard/CardRecognition.lua")
local zoneCode=section(source,"trackerPrivate.zoneFootprintContainsXZ=require(",
    "-- A dropped play source")
local underCode=section(source,"function resourceCardsUnderAction(targets)",
    "\nfunction resourceCardsZoneEntered(ctx)")
local function position(x,y,z)
    return {x=x,y=y,z=z,[1]=x,[2]=y,[3]=z}
end
local green={guid="green",type="Card",is_face_down=false,position=position(1.1,2.8,0)}
local blue={guid="blue",type="Card",is_face_down=false,position=position(0,2.3,0)}
local otherBlue={guid="blue2",type="Card",is_face_down=false,position=position(1.3,1.5,0)}
for _,obj in ipairs({green,blue,otherBlue}) do
    obj.getPosition=function() return obj.position end
end
local gold={guid="gold",type="Dice",position=position(0.1,3.3,0),resting=false}
gold.getPosition=function() return gold.position end
local blueDie={guid="blueMana",type="Dice",position=position(1.2,3.3,0),resting=true}
blueDie.getPosition=function() return blueDie.position end
local candidates={green,blue,otherBlue}
local footprints={
    green={x=1.1,z=0,halfX=1.5,halfZ=1.5},
    blue={x=0,z=0,halfX=1.5,halfZ=1.5},
    blue2={x=1.3,z=0,halfX=1.5,halfZ=1.5}
}
local tracker={}
local select=require("PlayingGame.PlayerBoard.ResourceTracker.Scanning.ManaPayments").bestManaCard
local function colorMatches(card,color)
    return color=="Gold" or (color=="Blue" and card.guid~="green")
        or (color=="Green" and card.guid=="green")
end
assert(select(gold,candidates,footprints,function(card)
    return colorMatches(card,"Gold")
end)==green,"Gold must power the highest card, not the nearest X/Z centre")
assert(select(blueDie,candidates,footprints,function(card)
    return colorMatches(card,"Blue")
end)==blue,"Blue mana must power the highest matching blue card beneath green")
assert(select(blueDie,candidates,footprints,function(card)
    return colorMatches(card,"Red")
end)==nil,"Unmatched coloured mana must not power a card")
green.position.y,green.position[2]=2.31,2.31
assert(select(gold,candidates,footprints,function(card)
    return colorMatches(card,"Gold")
end)==green,"Even a thin 0.01 stack offset must outrank X/Z proximity")
green.position.y,green.position[2]=2.3,2.3
assert(select(gold,candidates,footprints,function(card)
    return colorMatches(card,"Gold")
end)==blue,"Equal-height ties use the closest X/Z centre")
green.position.y,green.position[2]=2.8,2.8
-- A crystal/die wedged between the cards is still a valid payment for
-- the lower card, even though the higher card is physically above the mana.
gold.position.y,gold.position[2]=2.55,2.55
assert(select(gold,candidates,footprints,function(card)
    return colorMatches(card,"Gold")
end)==blue,"Between-card mana must not be lost or power a card above itself")
gold.position.y,gold.position[2]=3.3,3.3

local zoneObjects={}
local zone={
    getPosition=function() return position(0,1,0) end,
    getScale=function() return position(10,0.1,10) end,
    getRotation=function() return {y=0} end,
    getObjects=function() return zoneObjects end
}
local objects={play=zone,green=green,blue=blue,blue2=otherBlue,gold=gold}
local frames,queued,changed,moved,picked={},{},0,0,0
tracker.trackerSession=1
tracker.playCandidateKind=function(kind) return kind=="card" end
tracker.traceEnabled=false
local env={
    trackerPrivate=tracker,gStates={turnNumber=1},
    turnOrder={{seatPos=1}},playerPlayAreas={[1]="play"},
    getObjectFromGUID=function(guid) return objects[guid] end,
    getAllObjects=function() error("Under must not scan the whole table") end,
    resourceCardsPanelOpen=function() return true end,
    resourceObjectKind=function(obj) return obj.type=="Card" and "card" or nil end,
    scriptObjectId=function(obj) return obj==gold and "Mana Dice" or nil end,
    resourceCardsObjectPickedUp=function(obj)
        assert(obj==blue)
        picked=picked+1
    end,
    resourceCardsObjectMoved=function(obj)
        assert(obj==blue)
        moved=moved+1
    end,
    resourceCardsSourceChanged=function() changed=changed+1 end,
    queueSeat=function(seat,guid)
        queued[#queued+1]={seat=seat,guid=guid}
    end,
    safeWaitFrames=function(_owner,callback,delay)
        frames[#frames+1]={callback=callback,delay=delay}
    end
}
setmetatable(env,{__index=_G})
env.trackerPrivate=env.trackerPrivate or {}
env.trackerPrivate.objectEvents=assert(loadfile("src/PlayingGame/PlayerBoard/ResourceTracker/Core/ObjectEvents.lua","t",env))()
local under=assert(load(zoneCode.."\n"..underCode
    .."\nreturn resourceCardsUnderAction","Under mana recovery","t",env))()
under({blue})
assert(picked==1 and #frames==1 and frames[1].delay==2,
    "Under must capture the played source before TTS restacks it")
frames[1].callback()
assert(moved==1 and #queued==0,
    "Die outside the zone must not be queued as a payment")
assert(#frames==2 and frames[2].delay==22,
    "Under must schedule a second check for delayed physics")
zoneObjects={gold}
gold.resting=true
frames[2].callback()
assert(#queued==1 and queued[1].guid=="gold" and changed==2,
    "Die returning into the zone triggers recalculation")
print("Stacked mana and U action regressions passed")
