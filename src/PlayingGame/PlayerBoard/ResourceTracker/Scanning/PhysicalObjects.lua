-- Physical geometry and object recognition shared by Resource Tracker scans and linking.
-- These are geometric observations only: the coordinator owns actual zone
-- membership, eligibility, relocation and mana-payment decisions.

-- Separate the three physical orientations. A tilted card is paid as a
-- discard (typically 45 degrees); a fully sideways card gives any basic 1.
-- Reducing modulo 180 handles the face-up cards' normal Y=180 orientation.
local function cardRotationOffset(card)
    local y=card.getRotation()[2]%180
    return math.min(y,180-y)
end

local function cardPosture(card)
    local tilt=cardRotationOffset(card)
    if tilt<25 then return "upright" end
    if tilt<=70 then return "discard" end
    return "sideways"
end

-- Read a scripting zone's transform, not its (potentially zero-sized)
-- collider bounds. Sharing this X/Z test keeps Card, Skill, Reward and enemy
-- recovery consistent, including rotated play and unit zones.
local function zoneFootprintContainsXZ(obj,zone)
    if obj==nil or zone==nil then return false end
    local center,size=zone.getPosition(),zone.getScale()
    if center==nil or size==nil then return false end
    local pos=obj.getPosition()
    local x,z=pos.x or pos[1],pos.z or pos[3]
    local cx,cz=center.x or center[1],center.z or center[3]
    local width,depth=size.x or size[1],size.z or size[3]
    if x==nil or z==nil or cx==nil or cz==nil
        or width==nil or depth==nil or width<=0 or depth<=0 then return false end
    local rotation=zone.getRotation~=nil and zone.getRotation() or nil
    local yaw=math.rad(rotation~=nil and (rotation.y or rotation[2]) or 0)
    local cosYaw,sinYaw=math.cos(yaw),math.sin(yaw)
    local dx,dz=x-cx,z-cz
    local localX=dx*cosYaw-dz*sinYaw
    local localZ=dx*sinYaw+dz*cosYaw
    return math.abs(localX)<width*0.5 and math.abs(localZ)<depth*0.5
end

local function footprint(obj)
    local position=obj.getPosition()
    local bounds=obj.getBounds()
    local size=bounds~=nil and bounds.size or nil
    local x=size~=nil and size[1] or 2
    local z=size~=nil and size[3] or 3
    return {x=position[1],z=position[3],halfX=math.max(0.4,x*0.5),halfZ=math.max(0.5,z*0.5)}
end

local function overlaps(a,b)
    -- Strict overlap, not merely touching edges. Each card can link several others.
    return math.abs(a.x-b.x)<(a.halfX+b.halfX)*0.92
       and math.abs(a.z-b.z)<(a.halfZ+b.halfZ)*0.92
end

local function overlapArea(a,b)
    if not overlaps(a,b) then return 0 end
    local width=math.max(0,math.min(a.x+a.halfX,b.x+b.halfX)-math.max(a.x-a.halfX,b.x-b.halfX))
    local depth=math.max(0,math.min(a.z+a.halfZ,b.z+b.halfZ)-math.max(a.z-a.halfZ,b.z-b.halfZ))
    return width*depth
end

local function manaColor(obj)
    if isManaTokenFigurine(obj) then return manaTokenColor(obj) end
    if obj.type=="Dice" then
        -- Treat released dice like crystals: a slight physical wobble can
        -- leave resting=false indefinitely, even when the visible face is stable.
        -- Still exclude scripted smooth movement while reading the face.
        if obj.isSmoothMoving() then return nil end
        local face=obj.getRotationValue()
        if type(face)=="string" then return face:match("^([%a]+) Mana$") end
    end
    return nil
end

-- Placement and resource links use X/Z, so vertical falling or a slightly
-- rocking die does not delay an otherwise released object.
local function readyForXZ(obj)
    return obj~=nil and (obj.held_by_color==nil or obj.held_by_color=="")
        and not obj.isSmoothMoving()
end

-- Reuse the same stable identifiers as Skills and Combat's faction reward cleanup.
-- No name/description guessing for Skills, Units or Faction Rewards.
local factionRewardNotes={
    ["Dark Crusader Reward"]="Dark",
    ["Elementalist Reward"]="Elem",
    ["Apocalypse Cult Reward"]="Apoc",
    ["Council of the Void Reward"]="Coun"
}

-- Original container GUIDs collide across factions in the pushed JSON.
-- Front-art image hashes are independent of translated names and survive
-- regenerated GUIDs when a token is extracted from a bag.
local function factionRewardForObject(obj)
    if obj==nil or factionRewardNotes[obj.getGMNotes()]==nil then return nil end
    local custom=obj.getCustomObject()
    local image=custom~=nil and custom.image or nil
    local hash=type(image)=="string" and image:match("([0-9A-Fa-f]+)/?$") or nil
    local definition=hash~=nil and factionRewardResourceByImage[hash:upper()] or nil
    if definition~=nil and definition.notes==obj.getGMNotes() then return definition end
    return factionRewardResourceByGUID[obj.getGMNotes()..":"..obj.guid]
end

local function resourceObjectKind(obj)
    if obj==nil then return nil end
    if skillTokens[obj.guid]~=nil then return "skill" end
    if obj.getGMNotes()=="Puppet Master" then return "puppet" end
    if obj.type=="Card" then
        local data=gameCards[obj.guid]
        if data~=nil then
            if data.cardType=="Regular Unit" or data.cardType=="Elite Unit" then return "unit" end
            return "card"
        end
        -- Wounds/Quests are not unknown resource cards.
        local notes=obj.getGMNotes()
        if notes=="Wound" then return "wound" end
        if notes=="Quest" then return nil end
        return "card"
    end
    if manaColor(obj)~=nil then return "mana" end
    if factionRewardNotes[obj.getGMNotes()]~=nil then return "factionReward" end
    return nil
end

return {
    cardPosture=cardPosture,
    zoneFootprintContainsXZ=zoneFootprintContainsXZ,
    footprint=footprint,
    overlaps=overlaps,
    overlapArea=overlapArea,
    manaColor=manaColor,
    readyForXZ=readyForXZ,
    factionRewardForObject=factionRewardForObject,
    resourceObjectKind=resourceObjectKind
}
