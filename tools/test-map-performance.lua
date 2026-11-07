-- Deterministic spatial-index and local reconciliation tests against production Lua.
-- Run from repository root: lua5.2 tools/test-map-performance.lua
local function source(path)
    local f=assert(io.open(path,"r"))
    local s=f:read("*a") f:close()
    return s
end
local function extract(path,startMarker,endMarker,prefix,suffix)
    local s=source(path)
    local a=assert(s:find(startMarker,1,true),"Missing "..startMarker)
    local b=assert(s:find(endMarker,a,true),"Missing "..endMarker)
    return assert(load((prefix or "")..s:sub(a,b-1)..(suffix or "")))
end

-- Parked-City checks follow actual terrain positions, not a fixed scenario
-- grid. A new tile or a legal nonstandard spot must reactivate an outside City.
local mapCode=source("src/PlayingGame/Map.lua")
local helperStart=assert(mapCode:find("function terrainExploreMayReachCityCard(",1,true))
local helperEnd=assert(mapCode:find("function clearTerrainExploreOptions(",helperStart,true))
local mayReach=assert(load(mapCode:sub(helperStart,helperEnd-1)..
    "\nreturn terrainExploreMayReachCityCard"))()
terrainTiles={tileA={},tileB={}}
terrainExploreOptions=function() return {} end
local currentMap={{guid="tileA",position={0,1.09,0}},
    {guid="tileB",position={6,1.09,0}}}
assert(mayReach({6,1.09,0},currentMap),"Existing terrain activates City compaction")
assert(mayReach({17,1.09,0},currentMap),"One-tile expansion margin activates City compaction")
assert(not mayReach({35,1.09,0},currentMap),"Distant City can skip compaction regardless of map shape")
assert(mayReach({35,1.09,0},{}),"No terrain cannot justify skipping City placement")
currentMap[#currentMap+1]={guid="tileC",position={30,1.09,0}}
terrainTiles.tileC={}
assert(mayReach({35,1.09,0},currentMap),"Expanding the physical map reactivates parked City")
table.remove(currentMap)
terrainExploreOptions=function()
    return {{attributes={tilePosX="35",tilePosZ="0"}}}
end
assert(mayReach({35,1.09,0},currentMap),"Nonstandard EXPLORE slot reactivates parked City")
terrainExploreOptions=function() return {} end
print("PASS scenario-independent parked-City frontier and reactivation")

-- The production terrain builder must preserve exactly the original
-- distance-based neighbour graph without comparing every hex pair.
local mapObjects={}
terrainTiles={}
for i=1,50 do
    local guid="tile"..i
    local x=-50.4+(i-1)*2.4
    local obj={guid=guid,is_face_down=false}
    obj.getPosition=function() return {x,1.3,0} end
    obj.getRotation=function() return {0,180,0} end
    mapObjects[#mapObjects+1]=obj
    terrainTiles[guid]={tileType="country",hexType={center="plains"},hexFeature={center=""}}
end
runtimeMapObjectSnapshot=function() return {objects=mapObjects} end
angleToXY=function(_,bearing,position)
    assert(bearing=="center")
    return {position[1],position[3]}
end
runtimeMapHexKey=function(a,b)
    if type(a)=="table" then return a.terrainGUID.."|"..a.bearing end
    return a.."|"..b
end
local comparisons=0
runtimeMapHexesAdjacent=function(a,b)
    comparisons=comparisons+1
    local dx=a.position[1]-b.position[1]
    local dz=a.position[3]-b.position[3]
    local d=dx*dx+dz*dz
    return d>4.2 and d<7.4
end
-- The production terrain snapshot also records optional profiling samples.
-- Stub that instrumentation before invoking the extracted builder.
mapPerformanceStart=function() return nil end
mapPerformanceRecord=function() end
local builder=extract("src/Shared.lua",
    "local function runtimeMapTerrainSnapshot()",
    "\nfunction runtimeMapSnapshot()",
    "local runtimeMapTerrainCache=nil\nlocal runtimeMapPreviousTerrainCache=nil\n",
    "\nreturn {build=runtimeMapTerrainSnapshot,reset=function(previous)\n"..
    "runtimeMapTerrainCache=nil runtimeMapPreviousTerrainCache=previous end}\n")()
local topology=builder.build()
assert(#topology.hexes==50,"All revealed hexes are indexed")
for i=1,50 do
    local key="tile"..i.."|center"
    local adjacent=assert(topology.neighbors[key],"Missing neighbours for "..key)
    assert(#adjacent==((i==1 or i==50) and 1 or 2),"Incorrect neighbour count for "..key)
    if i>1 then assert(adjacent[1].terrainGUID=="tile"..(i-1),"Adjacency order changed") end
    if i<50 then assert(adjacent[#adjacent].terrainGUID=="tile"..(i+1),"Missing next hex") end
end
assert(comparisons<250,"Spatial graph made too many pair comparisons: "..comparisons)
print("PASS terrain spatial adjacency and original neighbour order")

-- Add one tile, remove an interior tile, move one tile and change a printed
-- feature. Each incremental rebuild must match the original physical geometry
-- without retesting all unchanged neighbouring pairs.
local newest={guid="tile51",is_face_down=false}
newest.getPosition=function() return {69.6,1.3,0} end
newest.getRotation=function() return {0,180,0} end
mapObjects[#mapObjects+1]=newest
terrainTiles.tile51={tileType="country",hexType={center="plains"},hexFeature={center=""}}
builder.reset(topology)
comparisons=0
local expanded=builder.build()
assert(#expanded.hexes==51,"Appended terrain has a hex")
assert(#expanded.neighbors["tile50|center"]==2 and #expanded.neighbors["tile51|center"]==1,
    "Appended terrain connects to its old neighbours")
assert(comparisons<30,"Appending terrain unexpectedly rebuilt the full graph: "..comparisons)

table.remove(mapObjects,25)
builder.reset(expanded)
comparisons=0
local reduced=builder.build()
assert(#reduced.hexes==50,"Removed terrain is absent")
assert(#reduced.neighbors["tile24|center"]==1 and #reduced.neighbors["tile26|center"]==1,
    "Removing terrain clears the edges to the missing tile")
assert(comparisons<30,"Removing terrain unexpectedly rebuilt the full graph: "..comparisons)

for _,obj in ipairs(mapObjects) do
    if obj.guid=="tile26" then
        obj.getPosition=function() return {300,1.3,0} end
        break
    end
end
builder.reset(reduced)
comparisons=0
local moved=builder.build()
assert(#moved.neighbors["tile26|center"]==0 and #moved.neighbors["tile27|center"]==1,
    "Moving a terrain tile updates both old and new neighbour relationships")
assert(comparisons<40,"Moving terrain unexpectedly rebuilt the full graph: "..comparisons)

terrainTiles.tile24.hexFeature.center="keep"
builder.reset(moved)
comparisons=0
local altered=builder.build()
assert(altered.hexByKey["tile24|center"].feature=="keep",
    "Printed feature mutation must reach the new hex snapshot")
assert(comparisons==0,"Feature-only changes must reuse unchanged neighbour geometry")
print("PASS incremental terrain reveal, removal, movement, and feature changes")

-- The production reconciler must ignore distant map enemies while honouring
-- moving tokens on the new tile. The physical-hex lookup is stubbed, but the
-- envelope filtering and readiness/grouping code are loaded from MapTokens.lua.
local newHex={terrainGUID="new",bearing="center",position={0,1.3,0}}
local oldHex={terrainGUID="old",bearing="center",position={100,1.3,0}}
local tokens={}
local function enemy(guid,x,moving)
    local o={guid=guid,pos={x,1.1,0},moving=moving,resting=not moving,kind="enemy"}
    o.getPosition=function() return o.pos end
    o.isSmoothMoving=function() return o.moving end
    tokens[#tokens+1]=o
    return o
end
enemy("nearA",0,false)
local pending=enemy("nearB",0.3,true)
for i=1,200 do enemy("distant"..i,100,false) end
local checks=0
mapTokenNeedsArrangement=function(obj)
    checks=checks+1
    return obj.kind=="enemy"
end
mapTokenPhysicalHexForPosition=function(_,pos)
    if math.abs(pos[1])<3 then return newHex end
    if math.abs(pos[1]-100)<3 then return oldHex end
end
runtimeMapHexesAndObjects=function() return {newHex,oldHex},tokens end
local arrangements={}
mapTokenArrangeHex=function(hex,_,_,_,candidates)
    arrangements[#arrangements+1]={hex=hex,candidates=candidates}
    return true
end
local reconciler=extract("src/PlayingGame/MapTokens.lua",
    "local function mapTokenTerrainReconcileBounds(",
    "local function mapTokenQueueTerrainReconcileCallback(",
    "local mapTokenArrivalPending={}\n",
    "\nreturn {ready=mapTokenTerrainReadyForReconcile,arrange=mapTokenArrangeAllOccupiedHexesNow}\n")()
assert(reconciler.ready("new")==false,"Moving local token must defer reconciliation")
assert(checks<=2,"Unrelated distant enemies were inspected")
checks=0
pending.moving=false pending.resting=true
assert(reconciler.ready("new")==true,"Local resting tokens must be ready")
assert(checks==2,"Both local enemies must be checked")
checks=0
assert(reconciler.arrange("new")==true,"Local arrangement should complete")
assert(checks==2,"Only local enemies should be considered for layout")
assert(#arrangements==1 and arrangements[1].hex==newHex and
    #arrangements[1].candidates==2,"Only the new hex should be rearranged")
print("PASS local token reconciliation with 200 distant enemies")
