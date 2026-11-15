-- Regression: a rolling mana die must not read its face before settling,
-- and a paid Concentration must link the correct stronger Swiftness effect.
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

local manaCode=section(src,"local function manaColor(obj)","-- Reuse the same stable identifiers")
local bonusCode=section(src,"local function applyLinkedResourceBonus(effects,link)",
    "-- Resolve independent mana roles")
local linksCode=section(src,"local function resolveActionLinks(cards,wounds,footprints,manaPowered,skillLinksByTarget)",
    "-- Generic Skill-card links")
local zoneCode=section(src,"local function resourceCardsRelevantZone(ctx)",
    "function resourceCardsZoneLeft(ctx)")
local dropCode=section(src,"function resourceCardsObjectMoved(obj)",
    "-- Register all Artifact and readying Object UI callbacks")

local calls={}
local die={
    type="Dice",guid="die001",resting=false,
    isSmoothMoving=function() return false end,
    getRotationValue=function() error("Unsettled die face must not be read") end,
}
local tracker={unitManaCandidatesBySeat={}}
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
local compiled=assert(load(table.concat({manaCode,bonusCode,linksCode,zoneCode,dropCode,
    "return manaColor,applyLinkedResourceBonus,resolveActionLinks,resourceCardsZoneEntered,resourceCardsObjectMoved"},"\n"),
    "Concentration mana settle","t",env))
local manaColor,applyBonus,resolveLinks,zoneEntered,objectMoved=compiled()
assert(manaColor(die)==nil,"Rolling die should not expose a mana colour")
zoneEntered({obj=die,objGUID=die.guid,objType="Dice",
    zoneInfo={kind="play",seatPos=2}})
assert(#calls==1 and calls[1].seat==2 and calls[1].guid==die.guid,
    "Rolling die entering play should queue a settled scan")
assert(tracker.unitManaCandidatesBySeat[2][die.guid]==true,
    "Rolling die candidate was not recorded")
objectMoved(die)
assert(#calls==2 and calls[2].guid==die.guid,
    "Die dropped above the thin scripting zone should queue a settled scan")
die.resting=true
die.getRotationValue=function() return "Green Mana" end
assert(manaColor(die)=="Green","Settled mana die should report Green")

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
print("Concentration / Swiftness rolling die regression passed")
