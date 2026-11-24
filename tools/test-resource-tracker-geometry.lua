-- Verify the actual extracted physical geometry, including boundary values.
-- Run from repository root: lua5.2 tools/test-resource-tracker-geometry.lua
package.path="src/?.lua;"..package.path
local physical=require("PlayingGame.PlayerBoard.ResourceTracker.PhysicalObjects")
local function eq(actual,expected,label)
    assert(actual==expected,(label or "Mismatch")..": expected "..tostring(expected)..
        ", got "..tostring(actual))
end
local function card(y)
    return {getRotation=function() return {0,y,0} end}
end
for _,case in ipairs({
    {0,"upright"},{24,"upright"},{25,"discard"},{45,"discard"},
    {70,"discard"},{71,"sideways"},{90,"sideways"},
    {110,"discard"},{156,"upright"},{180,"upright"},
    {225,"discard"},{270,"sideways"},{-90,"sideways"}
}) do
    eq(physical.cardPosture(card(case[1])),case[2],"Rotation "..case[1])
end

local obj={getPosition=function() return {5,100,8} end,
    getBounds=function() return {size={4,1,6}} end}
local area=physical.footprint(obj)
eq(area.x,5);eq(area.z,8);eq(area.halfX,2);eq(area.halfZ,3)
obj.getBounds=function() return nil end
area=physical.footprint(obj)
eq(area.halfX,1);eq(area.halfZ,1.5)
obj.getBounds=function() return {size={0.1,0,0.1}} end
area=physical.footprint(obj)
eq(area.halfX,0.4);eq(area.halfZ,0.5)

local a={x=0,z=0,halfX=1,halfZ=1}
local b={x=1,z=0,halfX=1,halfZ=1}
eq(physical.overlaps(a,b),true);eq(physical.overlapArea(a,b),2)
eq(physical.overlapArea(b,a),2,"Symmetric overlap")
b.x=1.84
eq(physical.overlaps(a,b),false,"Strict 92% threshold")
eq(physical.overlapArea(a,b),0)
b.x=1.83
eq(physical.overlaps(a,b),true)
b.z=2
eq(physical.overlaps(a,b),false,"Both axes must overlap")

local zone={getPosition=function() return {x=10,z=20} end,
    getScale=function() return {x=8,z=2} end,
    getRotation=function() return {y=90} end,
    getBounds=function() error("Scripting zone bounds must not be read") end}
local p={x=10,y=900,z=23}
obj.getPosition=function() return p end
eq(physical.zoneFootprintContainsXZ(obj,zone),true,"Rotated long axis ignores Y")
p.x=11.1
eq(physical.zoneFootprintContainsXZ(obj,zone),false,"Rotated short axis")
p.x,p.z=10,24.1
eq(physical.zoneFootprintContainsXZ(obj,zone),false,"Rotated long-axis exterior")
zone.getRotation=nil
p.x,p.z=13,20
eq(physical.zoneFootprintContainsXZ(obj,zone),true,"Default unrotated")
p.x=14
eq(physical.zoneFootprintContainsXZ(obj,zone),false,"Strict zone boundary")
zone.getScale=function() return {x=0,z=2} end
eq(physical.zoneFootprintContainsXZ(obj,zone),false,"Zero zone width")
eq(physical.zoneFootprintContainsXZ(nil,zone),false)
eq(physical.zoneFootprintContainsXZ(obj,nil),false)
print("Resource Tracker physical geometry and boundary regressions passed")
