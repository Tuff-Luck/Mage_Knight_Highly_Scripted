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
    armyOffsetZ=5,armyTokenSpacingX=1.65,armyRowSpacingZ=2.25,armyTokensPerRow=5
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
local p1=scenarioDiscGridArmyPosition("DarkCrusader",1)
local p2=scenarioDiscGridArmyPosition("DarkCrusader",2)
local p5=scenarioDiscGridArmyPosition("DarkCrusader",5)
local p6=scenarioDiscGridArmyPosition("DarkCrusader",6)
local low=scenarioDiscGridArmyPosition("Elementalist",1)
assert(p1[1]==top[1] and p1[3]==top[3]+5,"top-row army must be above disc")
assert(low[1]==bottom[1] and low[3]==bottom[3]-5,"bottom-row army must be below disc")
assert(math.abs((p2[1]-p1[1])-1.65)<0.001,"tokens must spread horizontally")
assert(math.abs((p5[1]-p1[1])+3.30)<0.001,"army row remains within owner column")
assert(math.abs((p6[3]-p1[3])-2.25)<0.001,"sixth token moves to outward overflow row")
print("PASS army positioning and overflow")
print("Scenario disc grid regression tests passed.")
