-- Run from repository root: lua5.2 tools/test-terrain-modifiers.lua
package.path="src/?.lua;"..package.path
local terrain=require("PlayingGame.PlayerBoard.ResourceTracker.Cards.TerrainModifiers")
local normal={mode="reduce",amount=1,terrains={forest=true}}
local night={mode="set",cost=2,terrains={desert=true},dayRound=false}
local rule={terrainEffects={normal={normal},powered={night}}}
assert(terrain.side(rule,false)[1]==normal)
assert(terrain.side(rule,true)[1]==night)
assert(terrain.side({terrainEffects={normal={normal}}},true)==nil)
local record={resources={move=2}}
terrain.stage(record,terrain.side(rule,false),true,3)
assert(#record.pendingTerrainModifiers==3)
for _,effect in ipairs(record.pendingTerrainModifiers) do assert(effect==normal) end
terrain.stage(record,{night},true)
assert(#record.pendingTerrainModifiers==3)
terrain.stage(record,{night},false)
assert(record.pendingTerrainModifiers[4]==night)
local effects={}
terrain.passive(effects,{passiveTerrain={normal},passiveNightTerrain={night}},false)
assert(#effects==2 and effects[1]==normal and effects[2]==night)
effects={}
terrain.passive(effects,{passiveTerrain={normal},passiveNightTerrain={night}},true)
assert(#effects==1 and effects[1]==normal)
local day={mode="reduce",amount=2,dayRound=true}
terrain.passive(effects,{passiveDayTerrain={day}},true)
assert(effects[2]==day)
assert(terrain.movementEligible(record,"unit#2",function(guid) assert(guid=="unit#2") return "movement" end))
assert(not terrain.movementEligible(record,"unit#2",function() return "combat" end))
assert(not terrain.movementEligible({resources={attack=2}},"shifted",function() return "movement" end))
assert(terrain.movementEligible({independentTerrain=true},"amulet",function() error("not needed") end))
assert(terrain.selectedTerrainDiscounts.forest==terrain.selectedTerrainDiscounts.forest)
assert(terrain.selectedTerrainDiscounts.forest.minimum==2)
print("Shared terrain modifier policy passed")
