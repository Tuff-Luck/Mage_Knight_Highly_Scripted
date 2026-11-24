-- Exercise actual physical recognition with isolated TTS object/data fixtures.
local imageDef={notes="Dark Crusader Reward",resources={attack=2}}
local fallback={notes="Dark Crusader Reward",resources={block=2}}
local env=setmetatable({
    skillTokens={skill=true},
    gameCards={starting={cardType="Starting"},regular={cardType="Regular Unit"},
        elite={cardType="Elite Unit"}},
    factionRewardResourceByImage={ABCD=imageDef},
    factionRewardResourceByGUID={["Dark Crusader Reward:reward"]=fallback},
    isManaTokenFigurine=function(obj) return obj.type=="Figurine" and obj.mana~=nil end,
    manaTokenColor=function(obj) return obj.mana end
},{__index=_G})
local physical=assert(loadfile("src/PlayingGame/PlayerBoard/ResourceTracker/Scanning/PhysicalObjects.lua","t",env))()
local function object(guid,kind,notes)
    local o={guid=guid,type=kind,notes=notes or "",resting=false}
    o.getGMNotes=function() return o.notes end
    o.getCustomObject=function() return {image=o.image} end
    o.isSmoothMoving=function() return o.moving==true end
    o.getRotationValue=function() return o.face end
    return o
end
local function kind(guid,typ,notes,expected)
    assert(physical.resourceObjectKind(object(guid,typ,notes))==expected,
        "Wrong object kind for "..guid)
end
kind("skill","Card","Puppet Master","skill")
kind("puppet","Custom_Token","Puppet Master","puppet")
kind("starting","Card","Quest","card")
kind("regular","Card","","unit")
kind("elite","Card","","unit")
kind("unknown","Card","","card")
kind("wound","Card","Wound","wound")
kind("quest","Card","Quest",nil)
kind("reward","Custom_Token","Dark Crusader Reward","factionReward")
kind("reward2","Custom_Token","Elementalist Reward","factionReward")
kind("reward3","Custom_Token","Apocalypse Cult Reward","factionReward")
kind("reward4","Custom_Token","Council of the Void Reward","factionReward")
kind("other","Custom_Token","",nil)
assert(physical.resourceObjectKind(nil)==nil)

local crystal=object("crystal","Figurine")
crystal.mana="Red"
assert(physical.manaColor(crystal)=="Red" and physical.resourceObjectKind(crystal)=="mana")
local die=object("die","Dice")
die.face="Green Mana"
assert(physical.manaColor(die)=="Green" and physical.resourceObjectKind(die)=="mana")
assert(physical.readyForXZ(die),"Released rocking dice are ready")
die.held_by_color="Blue"
assert(not physical.readyForXZ(die),"Held dice are not ready")
die.held_by_color=""
die.moving=true
assert(not physical.readyForXZ(die) and physical.manaColor(die)==nil)
die.moving=false
die.face="Unknown face"
assert(physical.readyForXZ(die) and physical.manaColor(die)==nil)
assert(physical.resourceObjectKind(die)==nil and not physical.readyForXZ(nil))

local reward=object("reward","Custom_Token","Dark Crusader Reward")
reward.image="https://example.invalid/abcd/"
assert(physical.factionRewardForObject(reward)==imageDef,"Art identity takes precedence")
reward.image="https://example.invalid/FFFF/"
assert(physical.factionRewardForObject(reward)==fallback,"Stable GUID fallback")
reward.image="https://example.invalid/abcd"
env.factionRewardResourceByImage.ABCD={notes="Elementalist Reward"}
assert(physical.factionRewardForObject(reward)==fallback,"Mismatched faction image must not win")
reward.notes="Unrecognized"
assert(physical.factionRewardForObject(reward)==nil)
assert(physical.factionRewardForObject(nil)==nil)
print("Resource Tracker object recognition, mana readiness and reward identity passed")
