-- Movement effects: exercise the real public bindings and live cost calculations.
local f=assert(io.open("src/PlayingGame/PlayerBoard/CardRecognition.lua","r"))
local source=f:read("*a") f:close()
local start=assert(source:find("trackerPrivate.movementEffects=require(",1,true))
local finish=assert(source:find("local function clearHighlight(guid)",start,true))
local open=true
local env=setmetatable({
    trackerPrivate={},skillResourceDefinitions={},
    gStates={turnNumber=1,dayRound=true,moveCost={lake=999,forest=5,plains=2,city=2,explore=2}},
    turnOrder={{seatPos=1}},
    resourceCardScanBySeat={[1]={terrainModifiers={}}},
    resourceCardsPanelOpen=function() return open end
},{__index=_G})
env.require=function(name)
    if name=="PlayingGame.PlayerBoard.ResourceTracker.Cards.TerrainModifiers" then
        return assert(loadfile("src/PlayingGame/PlayerBoard/ResourceTracker/Cards/TerrainModifiers.lua","t",env))()
    end
    assert(name=="PlayingGame.PlayerBoard.ResourceTracker.Cards.MovementEffects")
    return assert(loadfile("src/PlayingGame/PlayerBoard/ResourceTracker/Cards/MovementEffects.lua","t",env))()
end
assert(load(source:sub(start,finish-1),"Movement effect wiring","t",env))()
local function eq(actual,expected,label)
    assert(actual==expected,label..": expected "..tostring(expected)..", got "..tostring(actual))
end
local cost=env.resourceCardsEffectiveTerrainCost
local function effects(list)
    env.resourceCardScanBySeat[1]={terrainModifiers=list}
end
local reduce={mode="reduce",terrains="passable",minimum=2,amount=2}
local cap={mode="cap",terrains={forest=true},cost=3}
local lakeSet={mode="set",terrains={lake=true},cost=4}
local cheaperLake={mode="set",terrains={lake=true},cost=3}
local weather={mode="weather",terrains="weather",amount=-2}
eq(cost("lake"),999,"Impassable base terrain")
eq(cost("unknown"),999,"Unknown terrain")
effects({reduce,weather})
eq(cost("lake"),999,"Discounts alone cannot open a lake")
effects({reduce,lakeSet,cheaperLake})
eq(cost("lake"),2,"Grant lowest traversal cost before applying discounts")
effects({cheaperLake,lakeSet,reduce})
eq(cost("lake"),2,"Lowest set cost is independent of order")
effects({cap,weather})
eq(cost("forest"),1,"Weather applies after cap")
eq(cost("city"),1,"Weather includes cities")
eq(cost("explore"),2,"Weather excludes exploration")
effects({{mode="reduce",terrains="passable",minimum=4,amount=1}})
eq(cost("plains"),2,"Minimum floor cannot raise cost")
effects({{mode="weather",terrains="weather",amount=3}})
eq(cost("forest"),5,"Weather increase capped at five")
open=false
eq(cost("forest"),5,"Closed tracker ignores played modifiers")
eq(cost("plains"),2,"Closed tracker uses live base cost")
env.gStates.moveCost.plains=3
eq(cost("plains"),3,"Live base cost is not cached")
local movement=env.trackerPrivate.movementEffects
local normal={{mode="reduce",dayRound=true}}
local rule={terrainEffects={normal=normal}}
eq(movement.cardTerrainEffects(rule,false),normal,"Normal terrain effect retains identity")
eq(movement.cardTerrainEffects(rule,true),nil,"No powered fallback")
eq(movement.terrainEffectActive(normal[1]),true,"Day condition")
env.gStates.dayRound=false
eq(movement.terrainEffectActive(normal[1]),false,"Day condition not active at night")
print("Resource Tracker terrain precedence, traversal and live state passed")
