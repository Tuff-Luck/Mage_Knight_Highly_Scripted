-- Regression checks for Volkare's wound die, offer timing, and red-card targets.
-- Run at repository root: lua5.2 tools/test-volkare.lua
local function eq(actual,expected,label)
    if actual~=expected then
        error((label or "Mismatch")..": expected "..tostring(expected)
            ..", got "..tostring(actual),2)
    end
end
local function source(path)
    local file=assert(io.open(path,"r"))
    local value=file:read("*a")
    file:close()
    return value
end
local function contains(value,fragment,label)
    assert(value:find(fragment,1,true),label or ("missing: "..fragment))
end
local function upvalue(fn,name)
    for i=1,100 do
        local key,value=debug.getupvalue(fn,i)
        if key==nil then break end
        if key==name then return value end
    end
    error("Missing function upvalue: "..name,2)
end

publishPublicUICallbacks=function() end
dofile("src/PlayingGame/AI/Volkare.lua")
local dieColor=upvalue(volkareTurn,"volkareDieColor")
for _,color in ipairs({"Red","Blue","Green","White","Gold","Black"}) do
    eq(dieColor(color.." Mana"),color,color.." die face")
    eq(dieColor(color),color,color.." bare value")
end
eq(dieColor("???"),nil,"Unknown die face is not a valid crystal key")
eq(dieColor(nil),nil,"Missing die face is not a valid crystal key")

local sortTargets=upvalue(volkareTurn,"volkareSortRedTargets")
local targets={
    {mage="Near",distance=0.5,fame=3,turn=1},
    {mage="High",distance=2.4,fame=8,turn=4},
    {mage="Middle",distance=1.0,fame=5,turn=2}}
sortTargets(targets)
eq(targets[1].mage,"High","Red card ignores distance for priority")
local tied={
    {mage="Later",distance=0.5,fame=7,turn=4},
    {mage="Earlier",distance=2.3,fame=7,turn=1}}
sortTargets(tied)
eq(tied[1].mage,"Earlier","Red card Fame tie follows Round order")

local volkare=source("src/PlayingGame/AI/Volkare.lua")
local offers=source("src/PlayingGame/Offers.lua")
contains(volkare,"if volkareDice==nil then","Missing die is handled before randomize")
contains(volkare,"local color=volkareDieColor(die.getRotationValue())",
    "Physical die result uses normalized colour")
contains(volkare,"gStates.volkareUnitCrystals[color] or nil",
    "Normalized colour is used for crystal lookup")
contains(volkare,"unitOfferSettledForVolkare()","Volkare waits for the physical offer")
contains(volkare,"local unitCard=unitOfferCardAtSlot(crystalData.slot)",
    "Crystal's permanent slot is used, without collapsing gaps")
contains(offers,"unitOfferInFlight[expectedGUID]=true",
    "Round deal tracks Units before they enter the offer")
contains(offers,"unitOfferUnknownDraws=unitOfferUnknownDraws+1",
    "Extra Unit draw tracks in-flight cards")
contains(offers,"unitOfferLockAfterArrival(guid)",
    "Offer reflow waits for arriving cards")
assert(not volkare:find("volkareUnitCrystals[volkareDice.getRotationValue()]",1,true),
    "Raw die face must not be used to index crystal colors")

GUID={zone={unitOffer="testoffer"}}
local zoneCards={}
local zone={getObjects=function() return zoneCards end}
getObjectFromGUID=function(guid)
    if guid=="testoffer" then return zone end
    return nil
end
gameCardType=function() return "Regular Unit" end
dofile("src/PlayingGame/Offers.lua")
local card={guid="a1b2c3",type="Card",resting=true,
    isSmoothMoving=function() return false end,
    getPosition=function() return {36,0.98,-4.2} end}
zoneCards[1]=card
eq(unitOfferSettledForVolkare(),true,"Stationary offer is ready")
card.resting=false
eq(unitOfferSettledForVolkare(),false,"Falling card blocks false empty-slot result")
card.resting=true
card.isSmoothMoving=function() return true end
eq(unitOfferSettledForVolkare(),false,"Smooth-moving card blocks false empty-slot result")
print("Volkare regression checks passed")
