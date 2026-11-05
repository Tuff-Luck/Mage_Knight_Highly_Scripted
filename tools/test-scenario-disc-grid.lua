-- Regression test for the shared 4x2 Dragon / leader / Volkare staging grid.
-- Run from the repository root: lua5.2 tools/test-scenario-disc-grid.lua
local file=assert(io.open("src/Shared.lua","r"))
local shared=file:read("*a")
file:close()
local first=assert(shared:find("function scenarioDiscGridVolkareEnabled()",1,true))
local last=assert(shared:find("\n---@overload",first,true))
assert(load(shared:sub(first,last-1)))()

scenarioDiscGrid={
    topRight={-51.93,0.97,16.00},
    spacingX=9,spacingZ=9,controlSide="left",
    armyOffsetZ=5.3,armySpanX=5,armyRiseY=0.15,
    volkareCampStackY={hex=0.12,reminder=0.85,die=1.75}
}
local dragon=false
apocalypseDragonComponentsNeeded=function() return dragon end
local allNames={"Control","Death","Pestilence","Famine","War","DarkCrusader","Elementalist","Volkare"}
local function expectLayout(label,scenario,hasDragon,hasVolkare,expected)
    dragon=hasDragon
    gStates={gameScenario=scenario,removeShadesOfTezlaMonsters=false,
        removeLostLegionExpansion=false,volkareCampAsCity=hasVolkare}
    local occupied={}
    for _,name in ipairs(allNames) do
        local p=scenarioDiscGridPosition(name)
        local slot=expected[name]
        if slot==nil then
            assert(p==nil,label..": "..name.." should not deploy")
        else
            assert(p~=nil,label..": "..name.." missing")
            local x=scenarioDiscGrid.topRight[1]-(4-slot[1])*9
            local z=scenarioDiscGrid.topRight[3]-(slot[2]-1)*9
            assert(math.abs(p[1]-x)<0.001 and math.abs(p[3]-z)<0.001,
                label..": "..name.." wrong cell")
            local key=tostring(slot[1])..":"..tostring(slot[2])
            assert(not occupied[key],label..": overlapping "..name)
            occupied[key]=true
        end
    end
    print("PASS "..label)
end

expectLayout("Volkare only","Conquest",false,true,{
    Volkare={4,2}
})
expectLayout("leaders only","Life and Death",false,false,{
    DarkCrusader={3,1},Elementalist={4,1}
})
expectLayout("Dragon only","Conquest",true,false,{
    Control={2,1},Death={3,1},Pestilence={4,1},Famine={3,2},War={4,2}
})
expectLayout("Volkare and leaders","Life and Death",false,true,{
    DarkCrusader={4,1},Elementalist={4,2},Volkare={3,2}
})
expectLayout("Volkare and Dragon","Conquest",true,true,{
    Control={2,1},Death={3,1},Pestilence={4,1},Famine={3,2},War={4,2},Volkare={2,2}
})
expectLayout("leaders and Dragon","Life and Death",true,false,{
    Control={1,1},Death={2,1},Pestilence={3,1},Famine={2,2},War={3,2},
    DarkCrusader={4,1},Elementalist={4,2}
})
expectLayout("all three","Life and Death",true,true,{
    Control={1,1},Death={2,1},Pestilence={3,1},Famine={2,2},War={3,2},
    DarkCrusader={4,1},Elementalist={4,2},Volkare={1,2}
})
scenarioDiscGrid.controlSide="right"
expectLayout("Control-head mirrored","Life and Death",true,true,{
    Control={4,1},Death={2,1},Pestilence={3,1},Famine={2,2},War={3,2},
    DarkCrusader={1,1},Elementalist={1,2},Volkare={4,2}
})
scenarioDiscGrid.controlSide="left"
local top=scenarioDiscGridPosition("DarkCrusader")
local bottom=scenarioDiscGridPosition("Elementalist")
assert(top~=nil and bottom~=nil,"Both leader discs should be present")
local p1=scenarioDiscGridArmyPosition("DarkCrusader",1,1.5,6)
local p2=scenarioDiscGridArmyPosition("DarkCrusader",2,1.5,6)
local p6=scenarioDiscGridArmyPosition("DarkCrusader",6,1.5,6)
local low=scenarioDiscGridArmyPosition("Elementalist",1,1.5,6)
local lastLow=scenarioDiscGridArmyPosition("Elementalist",6,1.5,6)
assert(p1[1]==top[1]-2.5 and p1[3]==top[3]+5.3,"first top-row token is -2.5 and above its disc")
assert(low[1]==bottom[1]-2.5 and low[3]==bottom[3]-5.3,"first bottom-row token is -2.5 and below its disc")
assert(math.abs(p6[1]-(top[1]+2.5))<0.001,"last top-row token is +2.5")
assert(math.abs(lastLow[1]-(bottom[1]+2.5))<0.001,"last bottom-row token is +2.5")
assert(p2[3]==p1[3] and p6[3]==p1[3],"all enemies stay in one row")
assert(math.abs((p2[1]-p1[1])-1.0)<0.001,"six tokens divide the 5-unit span evenly")
assert(math.abs((p2[2]-p1[2])-0.15)<0.001,"successive tokens rise 0.15")
assert(math.abs((p6[2]-p1[2])-0.75)<0.001,"sixth token rises five steps")
local solo=scenarioDiscGridArmyPosition("DarkCrusader",1)
assert(solo[1]==p1[1] and solo[3]==p1[3],"leader-only staging already occupies the first slot")
local pairEnd=scenarioDiscGridArmyPosition("DarkCrusader",2,1.5,2)
assert(math.abs(pairEnd[1]-(top[1]+2.5))<0.001,"two tokens occupy both endpoints")
local manyLast=scenarioDiscGridArmyPosition("DarkCrusader",24,1.5,24)
assert(math.abs(manyLast[1]-(top[1]+2.5))<0.001 and manyLast[3]==p1[3],
    "large armies stay in a single row")
local zonePos,zoneScale=scenarioDiscGridZoneTransform("DarkCrusader")
assert(zonePos~=nil and zoneScale~=nil,"grid owners have an enlarged scripting zone")
assert(zonePos[3]>top[3] and zoneScale.z>=scenarioDiscGrid.armyOffsetZ+6,
    "top zone covers disc and army")
local lowZone=scenarioDiscGridZoneTransform("Elementalist")
assert(lowZone[3]<bottom[3],"bottom zone extends toward bottom-row army")
print("PASS single-row army spacing, rise, and zone coverage")
print("Scenario disc grid regression tests passed.")
