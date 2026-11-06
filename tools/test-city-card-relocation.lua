-- Reproduce concurrent City placement and protect locked reference tiles from City relocation.
-- Run with: lua5.2 tools/test-city-card-relocation.lua
local f=assert(io.open("src/PlayingGame/City.lua","r"))
local src=f:read("*a") f:close()
local initA=assert(src:find("function cityInitialCardPosition(",1,true))
local initB=assert(src:find("\ncityRegisterDeployOrder=",initA,true))
local engineA=assert(src:find("local cityCardPendingMoves=",initB,true))
local engineB=assert(src:find("--Used immediately before a chosen EXPLORE tile is placed.",engineA,true))
local code="local cityCardReserveDestination,cityCardPendingDestination\n"..src:sub(initA,initB-1).."\n"..src:sub(engineA,engineB-1)

local objects={}
local function obj(guid,x,y,z,options)
    local o={guid=guid,pos={x,y,z},locked=options and options.locked or false,
        type=options and options.kind or "Generic",smooth=false,moves=0}
    o.getPosition=function() return {o.pos[1],o.pos[2],o.pos[3]} end
    o.setPositionSmooth=function(destination)
        o.moves=o.moves+1
        o.target={destination[1],destination[2],destination[3]}
        o.smooth=true -- TTS will arrive at this position later, not synchronously
    end
    o.isSmoothMoving=function() return o.smooth end
    o.getLock=function() return o.locked end
    o.setPosition=function(p) o.pos={p[1],p[2],p[3]} end
    objects[guid]=o
    return o
end
local cityA=obj("cardA",-60,1,0)
local cityB=obj("cardB",-40,1,0)
local modelA=obj("modelA",0,1,0)
local modelB=obj("modelB",10,1,0)
local defenderA=obj("troopA",-55,1.5,0) -- fanned out five units from City A
local manualA=obj("manualA",-57,1.5,2) -- player manually added this defender
local defenderB=obj("troopB",-39,1.5,0)
local reference=obj("lockedRef",-56,1,1,{locked=true,kind="Custom_Tile"})
local distantRef=obj("farLocked",-50,1,1,{locked=true,kind="Custom_Tile"})
local zoneA=obj("zoneA",-60,1.4,0)
local zoneB=obj("zoneB",-40,1.4,0)
zoneA.getObjects=function() return {cityA,defenderA,defenderB,reference,distantRef} end
zoneB.getObjects=function() return {cityB,defenderA,reference} end
local map=obj("map",-10,1,0)
map.getObjects=function() return {} end -- e.g. the City cards are off-map/in transit
getObjectFromGUID=function(guid) return objects[guid] end
getAllObjects=function() return {cityA,cityB,modelA,modelB,defenderA,manualA,defenderB,reference,distantRef,zoneA,zoneB} end
mapArea="map"
terrainTiles={}
monsterPugs={troopA={pugType="red"},manualA={pugType="tan"},troopB={pugType="purple"}}
CITY_GARRISON_PUG_TYPES={red=true,tan=true,purple=true}
CITY_GARRISON_MANUAL_RADIUS=6
CITY_GARRISON_KNOWN_RADIUS=9
CITY_GARRISON_MIN_Y=0.75
CITY_GARRISON_MAX_Y=3.6
cityModel={blue="modelA",red="modelB",green="other1",white="other2"}
GUID={zone={blueCity="zoneA",redCity="zoneB",greenCity="zoneC",whiteCity="zoneD"}}
cityScriptZones={zoneA={cityGUID="modelA"},zoneB={cityGUID="modelB"}}
gStates={cityCard={modelA="cardA",modelB="cardB"},
    cityMonsterQty={modelA={extra={},troopA="alive"},modelB={extra={},troopB="alive"}},
    monsterPlayLocation={troopA={-55,1.5,0},troopB={-39,1.5,0}}}
mageKnights={}
cityGarrisonCardOwners=function()
    return {{guid="modelA",position=cityA.getPosition()},{guid="modelB",position=cityB.getPosition()}}
end
cityGarrisonNearestOwner=function(p,owners)
    local nearest,dist
    for _,o in ipairs(owners) do
        local d=(p[1]-o.position[1])^2+(p[3]-o.position[3])^2
        if dist==nil or d<dist then nearest=o.guid dist=d end
    end
    return nearest,dist
end
cityGarrisonRegisteredElsewhere=function(guid,data)
    for _,roster in pairs(gStates.cityMonsterQty) do
        if roster~=data and roster[guid]=="alive" then return true end
    end
    return false
end
standardCityGarrisonOwner=function(guid) return guid end
isShieldObject=function() return false end
terrainExploreOptions=function() return {} end
cityCardExploreOffsets={{6,1.09,0},{0,1.09,6},{-6,1.09,0}}
local loader,err=load(code)
assert(loader,err)
loader()
local groupA=assert(cityCardExploreGroup("zoneA"))
assert(groupA.movingGUIDs.cardA,"Own City card must move")
assert(groupA.movingGUIDs.troopA,"Registered, fanned-out defender must move")
assert(groupA.movingGUIDs.manualA,"Manually rearranged unregistered defender must move")
assert(not groupA.movingGUIDs.troopB,"Other City's defender must stay")
assert(not groupA.movingGUIDs.lockedRef and not groupA.movingGUIDs.farLocked,"Locked reference tiles must stay")
-- A dense map should be indexed once per City-position search. Changing an
-- owner's position must invalidate that index before the next City is placed.
local cachedMap=cityCardMapSnapshot()
assert(cityCardExploreSpaceFree(cachedMap,{100,1.09,0},{},nil,nil),"Empty distant spot is free")
assert(cachedMap._cityExploreBlockers~=nil,"City blockers are spatially indexed")
local ok=moveCityCardExploreGroup(groupA,{-54,1.09,0},{},cachedMap)
assert(ok,"Move group A")
assert(cachedMap._cityExploreBlockers==nil,"Moving a City invalidates blocker buckets")
assert(cityA.target[1]==-54 and defenderA.target[1]==-49 and manualA.target[1]==-51,
    "City card and loose army retain their relative positions")
assert(not defenderB.target and not reference.target and not distantRef.target,
    "Unrelated armies and reference tiles must never move")
assert(gStates.monsterPlayLocation.troopA[1]==-49 and
    gStates.monsterPlayLocation.troopB[1]==-39,
    "Only the owner's saved garrison return location changes")
assert(not cityCardExploreSpaceFree({}, {-54,1.09,0},{cardB=true},nil,nil),
    "Other City's reserved target is blocked even when it is not in map-zone snapshot")
assert(not cityCardExploreSpaceFree({}, {-60,1.09,0},{cardB=true},nil,nil),
    "Other City's current physical position is blocked")
-- New City's initial deployment also reserves its chosen position against a concurrent City refresh.
cityB.setPosition({-40,1,0})
modelB.setPosition({-20,1,0})
local initial=assert(cityInitialCardPosition("modelB",modelB))
assert(initial[1]==-14 and cityB.target[1]==-14,"New City chose first legal ring position")
assert(not cityCardExploreSpaceFree({}, {-14,1.09,0},{cardA=true},nil,nil),
    "A pending initial City target cannot be double-booked")
local groupB=assert(cityCardExploreGroup("zoneB"))
assert(not positionCityCardForExplore("zoneB",nil,{},nil,{}),
    "Compaction must not redirect the in-flight newly deployed card")
local obstacles={{guid="near",position={101.5,1.09,0}},
                 {guid="far",position={350,1.09,0}}}
assert(not cityCardExploreSpaceFree(obstacles,{100,1.09,0},{},nil,nil),
    "Nearby enemy blocks an EXPLORE City offset even on a crowded board")
assert(cityCardExploreSpaceFree(obstacles,{100,1.09,0},{near=true},nil,nil),
    "Owner's moving enemy is not an obstacle")
local crossCell={{guid="boundary",position={-4.1,1.09,0}}}
assert(not cityCardExploreSpaceFree(crossCell,{-1.1,1.09,0},{},nil,nil),
    "Negative spatial cell boundary does not hide nearby blockers")
print("PASS City relocation ownership and concurrent destination reservations")
