-- Related regressions share a runner and fixtures while each case retains local state.
-- Run from repository root: lua5.2 tools/test-resource-tracker-physical-objects.lua
package.path="src/?.lua;"..package.path

local function eq(actual,expected,label)
    assert(actual==expected,(label or "Mismatch")..": expected "..tostring(expected)..", got "..tostring(actual))
end

local failures={}
local function run(name,body)
    local ok,message=xpcall(body,debug.traceback)
    if not ok then
        failures[#failures+1]=name..": "..tostring(message)
    end
end

run("resource-tracker-geometry",function()
    -- Verify the actual extracted physical geometry, including boundary values.
    local physical=require("PlayingGame.PlayerBoard.ResourceTracker.Scanning.PhysicalObjects")
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
end)

run("resource-tracker-object-recognition",function()
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
end)

if #failures>0 then
    error(table.concat(failures,"\n\n"),0)
end
