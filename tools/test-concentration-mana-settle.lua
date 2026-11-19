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

local manaCode=section(src,"local function manaColor(obj)","-- Reuse the same stable identifiers")
local bonusCode=section(src,"local function applyLinkedResourceBonus(effects,link)",
    "-- Resolve independent mana roles")
local linksCode=section(src,"local function resolveActionLinks(cards,wounds,footprints,manaPowered,skillLinksByTarget)",
    "-- Generic Skill-card links")
local zoneCode=section(src,"local function resourceCardsRelevantZone(ctx)",
    "function resourceCardsZoneLeft(ctx)")
local dropCode=section(src,"function resourceCardsObjectMoved(obj,stabilized)",
    "-- Register the remaining readying and Artifact gameplay buttons through the")
local recoverCode=section(src,"    -- Mana dropped ON a played Action",
    "    -- A resting active Unit can be lifted above the thin Zone")

local calls={}
local die={
    type="Dice",guid="die001",resting=false,smooth=false,
    isSmoothMoving=function(self) return self.smooth end,
    getRotationValue=function() return "Green Mana" end,
}
local tracker={unitManaCandidatesBySeat={},playCardMovements={}}
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
assert(tracker.unitManaCandidatesBySeat[2][die.guid]==true,
    "Released die candidate was not recorded")
objectMoved(die)
assert(#calls==2 and calls[2].guid==die.guid,
    "Die dropped above the thin scripting zone should queue a resource scan")
assert(manaColor(die)=="Green" and not die.resting,
    "Non-resting but released mana die should still report Green")

-- The die can settle above the thin scripting zone, outside getObjects().
-- It still powers Concentration if and only if it physically covers the card.
local diePosition={0.1,2.0,0.1}
local concentrationPosition={0,1.0,0}
die.getPosition=function() return diePosition end
env.getObjectFromGUID=function(guid) return guid==die.guid and die or nil end
env.manaColor=manaColor
env.trackerPrivate.readyForXZ=readyForXZ
env.footprint=function(card)
    local pos=card.getPosition()
    return {x=pos[1],z=pos[3],halfX=1,halfZ=1}
end
local recovered=assert(load("return function(seatPos,objects,placements,objectKinds)\n"
    ..recoverCode.."\nend","Recover mana on Action card","t",env))()
local function recover()
    local objects={
        ["af9def"]={guid="af9def",getPosition=function() return concentrationPosition end}
    }
    local placements={["af9def"]="play"}
    local kinds={["af9def"]="card"}
    recovered(2,objects,placements,kinds)
    return objects,placements,kinds
end
local recoveredObjects,recoveredPlacement,recoveredKinds=recover()
assert(recoveredObjects[die.guid]==die and recoveredPlacement[die.guid]=="play"
    and recoveredKinds[die.guid]=="mana",
    "Released Source die physically on Concentration must be included in play scan")
diePosition={10,2.0,10}
local _,farPlacement=recover()
assert(farPlacement[die.guid]==nil,
    "Source die away from Action cards must not be counted as payment")
diePosition={0.1,2.0,0.1}
die.smooth=true
local _,movingPlacement=recover()
assert(movingPlacement[die.guid]==nil,"Smooth-moving die must not be treated as a paid Action")
die.smooth=false
die.held_by_color="Blue"
local _,heldPlacement=recover()
assert(heldPlacement[die.guid]==nil,"Held die must not be treated as a paid Action")
die.held_by_color=nil

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
