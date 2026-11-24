-- Regression: a released mana die works like a crystal even if TTS keeps
-- resting=false; held/smooth-moving dice remain excluded from payments.
-- Paid Concentration must still link the correct stronger Swiftness effect.
-- Run from repository root: lua5.2 tools/test-concentration-mana-settle.lua
local function read(path)
    local f=assert(io.open(path,"r"))
    local text=f:read("*a")
    f:close()
    return text
end
local function section(source,first,last)
    local a=assert(source:find(first,1,true),"Missing "..first)
    local b=assert(source:find(last,a+#first,true),"Missing "..last)
    return source:sub(a,b-1)
end

local src=read("src/PlayingGame/PlayerBoard/CardRecognition.lua")
local data=read("src/Data.lua")
assert(data:find('["af9def"]={cardType="Starting", resourceKey="concentration"',1,true),
    "Krang's Concentration card definition is missing")
assert(data:find('["acdcb2"]={cardType="Starting", resourceKey="swiftness"',1,true),
    "Krang's Swiftness card definition is missing")
assert(data:find('swiftness={normal={move=2},powered={ranged=3}}',1,true),
    "Swiftness stronger effect changed")
assert(data:find('poweredLink={mode="stronger",bonus=2,',1,true),
    "Concentration powered Action link changed")

local manaCode=section(src,'local manaColor=require("PlayingGame.PlayerBoard.ResourceTracker.PhysicalObjects").manaColor',"-- Magic Talent's strong side")
local bonusCode=section(src,"local function applyLinkedResourceBonus(effects,link)",
    'local effectManaPossibilities=require("PlayingGame.PlayerBoard.ResourceTracker.ManaPayments").effectManaPossibilities')
local linksCode=section(src,"local function resolveActionLinks(cards,wounds,footprints,manaPowered,skillLinksByTarget)",
    "-- Generic Skill-card links")
local zoneCode=section(src,"local function resourceCardsRelevantZone(ctx)",
    "function resourceCardsZoneLeft(ctx)")
local dropCode=section(src,"function resourceCardsObjectMoved(obj,stabilized)",
    "-- Register the remaining readying and Artifact gameplay buttons through the")
local calls={}
local die={
    type="Dice",guid="die001",resting=false,smooth=false,
    isSmoothMoving=function() return false end,
    getRotationValue=function() return "Green Mana" end,
}
die.isSmoothMoving=function() return die.smooth end
local tracker={playCardMovements={}}
local cards={
    ["af9def"]={resourceKey="concentration",cardType="Starting"},
    ["acdcb2"]={resourceKey="swiftness",cardType="Starting"},
}
local rules={
    concentration={poweredLink={mode="stronger",bonus=2,
        bonusFor={move=true,influence=true,block=true,attack=true,ranged=true,siege=true}}},
    swiftness={normal={move=2},powered={ranged=3}},
}
local env={
    gStates={turnNumber=1,resourceCardPlayOrder={},resourceCardPlaySerial=0},
    turnOrder={{seatPos=2,mage="Krang"}},
    trackerPrivate=tracker,
    gameCards=cards,cardResourceDefinitions=rules,
    skillTokens={},factionRewardNotes={},
    isManaTokenFigurine=function() return false end,
    scriptObjectId=function(obj) return obj==die and "Mana Dice" or nil end,
    resourceCardsPanelOpen=function() return true end,
    resourceObjectKind=function() error("Moving Mana die must be routed by identity") end,
    combatEnemyData=function() return nil end,
    queueSeat=function(seat,guid) calls[#calls+1]={seat=seat,guid=guid} end,
    cardPosture=function() return "upright" end,
    overlapArea=function(a,b)
        if math.abs(a.x-b.x)<1.5 and math.abs(a.z-b.z)<1.5 then return 1 end
        return 0
    end,
}
setmetatable(env,{__index=_G})
env.require=function(name)
    assert(name=="PlayingGame.PlayerBoard.ResourceTracker.PhysicalObjects", "Unexpected recognition dependency")
    return assert(loadfile("src/PlayingGame/PlayerBoard/ResourceTracker/PhysicalObjects.lua","t",env))()
end
local compiled=assert(load(table.concat({manaCode,bonusCode,linksCode,zoneCode,dropCode,
    "return manaColor,trackerPrivate.readyForXZ,applyLinkedResourceBonus,resolveActionLinks,resourceCardsZoneEntered,resourceCardsObjectMoved"},"\n"),
    "Concentration mana settle","t",env))
local manaColor,readyForXZ,applyBonus,resolveLinks,zoneEntered,objectMoved=compiled()
assert(manaColor(die)=="Green","Released, slightly rocking die should expose its face")
assert(readyForXZ(die),"Released die is ready despite resting=false")
die.smooth=true
assert(manaColor(die)==nil and not readyForXZ(die),
    "Smooth-moving die must not count as a mana payment")
die.smooth=false
die.held_by_color="Blue"
assert(not readyForXZ(die),"Held die must not count as a mana payment")
die.held_by_color=nil
zoneEntered({obj=die,objGUID=die.guid,objType="Dice",
    zoneInfo={kind="play",seatPos=2}})
assert(#calls==1 and calls[1].seat==2 and calls[1].guid==die.guid,
    "Released die entering play should queue a resource scan")
objectMoved(die)
assert(#calls==2 and calls[2].guid==die.guid,
    "Die drop must queue a resource scan even if it leaves the zone")
assert(manaColor(die)=="Green" and not die.resting,
    "Non-resting but released mana die should still report Green")

local concentration={guid="af9def",is_face_down=false}
local swiftness={guid="acdcb2",is_face_down=false}
local footprints={
    ["af9def"]={x=0,z=0},["acdcb2"]={x=0.5,z=0.5},
}
local links,boostBy=resolveLinks({concentration,swiftness},{},footprints,
    {["af9def"]=true},{})
assert(links["af9def"][1]=="acdcb2" and links["acdcb2"][1]=="af9def",
    "Paid Concentration should link overlapping Swiftness")
assert(boostBy["acdcb2"]==rules.concentration.poweredLink,
    "Swiftness should receive Concentration's stronger-side bonus")
assert(applyBonus(rules.swiftness.powered,boostBy["acdcb2"]).ranged==5,
    "Paid Concentration + Swiftness must yield Ranged Attack 5")
print("Concentration / Swiftness released die regression passed")
