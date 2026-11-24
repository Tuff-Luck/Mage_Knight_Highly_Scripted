-- Regression for scripting zones with zero-sized getBounds() but valid
-- transform dimensions. Recreates the two card locations from the user's
-- relocation report, including absent zone.getObjects() while falling.
-- Run: lua5.2 tools/test-card-zone-transform-footprint.lua
package.path="src/?.lua;"..package.path
local function read(path)
    local file=assert(io.open(path,"r"))
    local text=file:read("*a")
    file:close()
    return text
end
local source=read("src/PlayingGame/PlayerBoard/CardRecognition.lua")
local a=assert(source:find("trackerPrivate.zoneFootprintContainsXZ=require(",1,true))
local b=assert(source:find("local function scheduleChoiceResetAfterPlay(guid,seatPos)",a,true))
local matCode=source:sub(a,b-1)
local position={x=-20.08,y=2,z=-42.19}
local zonePos={x=-15,y=1,z=-42}
local zoneScale={x=24,y=1,z=10}
local zoneRotation={x=0,y=0,z=0}
local card={guid="rage",held_by_color=nil,
    isSmoothMoving=function() return false end,
    isDestroyed=function() return false end,
    getPosition=function() return position end}
local zone={
    getObjects=function() return {} end,
    getBounds=function() return {center=zonePos,size={x=0,y=0,z=0}} end,
    getPosition=function() return zonePos end,
    getScale=function() return zoneScale end,
    getRotation=function() return zoneRotation end
}
local trackerPrivate={}
local env={
    trackerPrivate=trackerPrivate,
    playerPlayAreas={[1]="zone"},
    getObjectFromGUID=function(guid)
        if guid=="zone" then return zone end
        if guid=="rage" then return card end
    end
}
setmetatable(env,{__index=_G})
local onMat=assert(load(matCode.."\nreturn cardInSeatPlayArea",
    "Scripting-zone transform footprint","t",env))()
assert(onMat("rage",1),"Pickup location must be within play footprint")
position.x,position.z=-9.82,-41.95
assert(onMat("rage",1),"Drop location must remain within play footprint")
assert(trackerPrivate.cardOverPlayMat(card,1),
    "XZ must not use zero-sized ScriptingTrigger getBounds()")
position.x=-35
assert(not onMat("rage",1),"Actual departure from play must be detected")

-- Rotation must affect the footprint: a long thin zone rotated 90 degrees
-- extends along world X, not along world Z.
zonePos.x,zonePos.z=0,0
zoneScale.x,zoneScale.z=4,20
zoneRotation.y=90
position.x,position.z=6,0
assert(onMat("rage",1),"Rotated-zone long axis must count as in play")
position.x,position.z=0,6
assert(not onMat("rage",1),"Rotated-zone short axis must exclude outside cards")

card.held_by_color="White"
assert(not trackerPrivate.cardOverPlayMat(card,1),
    "Held objects cannot be included in a scan by geometry alone")
print("Scripting-zone transform footprint regressions passed")
