-- Exploration Move deductions and explore-specific modifiers.
-- Run from repo root: lua5.2 tools/test-exploration-spending.lua
local function read(path)
    local file=assert(io.open(path,"r"))
    local result=file:read("*a")
    file:close()
    return result
end
local function section(source,first,last,tail,env)
    local a=assert(source:find(first,1,true),"Missing "..first)
    local b=assert(source:find(last,a+#first,true),"Missing "..last)
    return assert(load(source:sub(a,b-1).."\n"..(tail or ""),first,"t",env))()
end
local function eq(actual,expected,label)
    assert(actual==expected,label..": expected "..tostring(expected)
        ..", got "..tostring(actual))
end

local recognition=read("src/PlayingGame/PlayerBoard/CardRecognition.lua")
local ui=read("src/PlayingGame/Interface/UI.lua")
local map=read("src/PlayingGame/World/Map.lua")
local movement=read("src/PlayingGame/World/Movement.lua")
local xml=read("src/UI/ResourceTracker.xml")
local hawk="152a98"
local feral="c73c8c"
local owned={}
local skills={
    [hawk]={passiveNightTerrain={{mode="reduce",terrains={explore=true},amount=1,minimum=0}}},
    [feral]={passiveTerrain={{mode="reduce",terrains={explore=true},amount=1,minimum=0}}}
}
local trackerOpen=true
local updates=0
local env={
    gStates={turnNumber=1,dayRound=false,gameScenario="Conquest",
        moveCost={explore=2,plains=2},
        mageSkills={}},
    turnOrder={{seatPos=1,avatarLocation="plains"}},
    resourceCardScanBySeat={[1]={terrainModifiers={}}},
    skillResourceDefinitions=skills,
    trackerPrivate={passableTerrain={plains=true}},
    resourceCardsPanelOpen=function() return trackerOpen end,
    refreshResourceTrackerText=function() updates=updates+1 end,
    invalidateResourceTrackerDisplayCache=function() end
}
setmetatable(env,{__index=_G})
env.require=function(name)
    assert(name=="PlayingGame.PlayerBoard.ResourceTracker.Cards.MovementEffects")
    return assert(loadfile("src/PlayingGame/PlayerBoard/ResourceTracker/Cards/MovementEffects.lua","t",env))()
end
local cost=section(recognition,'trackerPrivate.movementEffects=require(',
    "local function clearHighlight(guid)",
    "return resourceCardsEffectiveExploreCost",env)
-- The real Skill-home geometry is used by the ownership check.
local homeX=1*40-109.5
local function enable(guid,enabled)
    env.gStates.mageSkills[guid]=enabled and {homeX,0,-31} or nil
end
local function scan()
    local modifiers={}
    for guid,rule in pairs(skills) do
        if owned[guid] then
            for _,effect in ipairs(rule.passiveTerrain or {}) do modifiers[#modifiers+1]=effect end
            if env.gStates.dayRound~=true then
                for _,effect in ipairs(rule.passiveNightTerrain or {}) do modifiers[#modifiers+1]=effect end
            end
        end
    end
    env.resourceCardScanBySeat[1]={terrainModifiers=modifiers}
end
local function setOwned(h,f)
    owned[hawk]=h owned[feral]=f
    enable(hawk,h) enable(feral,f)
    scan()
end
setOwned(false,false)
eq(cost(),2,"Base exploration costs 2")
setOwned(true,false)
eq(cost(),1,"Hawk Eyes night exploration discount")
env.gStates.dayRound=true scan()
eq(cost(),2,"Hawk Eyes is night-only")
setOwned(false,true)
eq(cost(),1,"Feral Allies always reduces exploration")
env.gStates.dayRound=false scan()
setOwned(true,true)
eq(cost(),0,"Two explicit reductions permit free exploration")
env.gStates.gameScenario="The Hidden Valley Blitz"
setOwned(true,false)
eq(cost(),3,"Hidden Valley triples AFTER the 1-point reduction")
setOwned(false,false)
eq(cost(),6,"Hidden Valley base exploration costs 6")
setOwned(true,true)
eq(cost(),0,"Zero modified cost stays free in Hidden Valley")
trackerOpen=false
setOwned(true,false)
eq(cost(),3,"Owned night Skill still applies while tracker is off")
setOwned(true,true)
eq(cost(),0,"Two owned Skill discounts still work while tracker is off")

local spend=section(ui,"function resourceCardsSpendExplore(cost,travelCost)",
    "function refreshResourceTrackerReputation()",
    "return resourceCardsSpendExplore",env)
env.gStates.resourceTracker={move={move=0,exploreSpent=0,travelSpent=0,exploreCount=0}}
trackerOpen=true
spend(2,3)
spend(0,0)
spend(1,2)
eq(env.gStates.resourceTracker.move.move,-8,"Exploration plus travel is a signed offset")
eq(env.gStates.resourceTracker.move.exploreSpent,3,"Cumulative Explore cost")
eq(env.gStates.resourceTracker.move.travelSpent,5,"Cumulative travel cost")
eq(env.gStates.resourceTracker.move.exploreCount,3,"Free exploration still counts")
eq(updates,3,"One tracker refresh per exploration")
-- A route query reuses the movement calculator without rendering the overlay.
local routeQuery=section(movement,"function moveDisplayCostToAvatar()",
    "function updateMoveDisplay(id)","return moveDisplayCostToAvatar",env)
env.moveDisplayCurrentAvatarPosition=function() return {4,1,5} end
env.renderMoveDisplay=function(id,position)
    eq(id,nil,"Travel query does not ask for a redraw")
    eq(position[1],4,"Travel query receives current avatar position")
    return 3
end
eq(routeQuery(),3,"Travel uses the movement map cost")
env.moveDisplayCurrentAvatarPosition=function() return nil end
eq(routeQuery(),0,"Unknown avatar position is not charged")
local reset=section(ui,"function resetResourceTrackerState()",
    "-- Record each accepted Explore plus the route already walked to the avatar.",
    "return resetResourceTrackerState",env)
reset()
eq(env.gStates.resourceTracker.move.move,0,"Turn boundary resets Move offset")
eq(env.gStates.resourceTracker.move.exploreSpent,0,"Turn boundary resets Explore spending")
eq(env.gStates.resourceTracker.move.travelSpent,0,"Turn boundary resets travel spending")
eq(env.gStates.resourceTracker.move.exploreCount,0,"Turn boundary resets Explore count")

assert(xml:find('id="MovemExploreRow"',1,true),"Explore row exists in XML")
assert(ui:find('showRow("MovemExplore",exploreCount>0)',1,true),
    "Explore row visibility follows the number of explorations")
assert(movement:find('destinationHex.hexType=="explore" and resourceCardsEffectiveExploreCost()',1,true),
    "Map routes use exploration-specific cost, not plain terrain pricing")
assert(map:find('resourceCardsSpendExplore(exploreCost,travelCost)',1,true),
    "Explore click deducts both its captured price and route")
assert(map:find('local travelCost=moveDisplayCostToAvatar()',1,true),
    "Explore queries travel before the map mutates")
assert(movement:find('local searchLimit=costOnly and 99 or 10',1,true),
    "Headless route queries work for costs beyond visible Move")
assert(movement:find('return renderMoveDisplay(nil,playerPos) or 0',1,true),
    "Explore travel uses the displayed path calculator")
assert(xml:find('id="MovemSpentRow"',1,true),
    "Separate Spent row exists in XML")
assert(ui:find('showRow("MovemSpent",travelSpent>0)',1,true),
    "Spent shows only when movement occurred")
assert(ui:find('{en}Spent : ',1,true),
    "Travel appears separately as Spent")
assert(ui:find('{en}Explore : ',1,true),
    "Explore cost remains independently visible")
assert(map:find('moveDisplayCaptureAvatarOrigin()',1,true),
    "Explore captures the avatar origin even at zero remaining Move")
print("Exploration spending regression checks passed")
