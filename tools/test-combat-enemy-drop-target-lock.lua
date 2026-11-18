-- Regression: an existing enemy's target arrows survive a drop while the
-- shallow combat zones have not yet registered the token's new Y position.
-- Run from repository root: lua5.2 tools/test-combat-enemy-drop-target-lock.lua
local function read(path)
    local f=assert(io.open(path,"r"))
    local text=f:read("*a")
    f:close()
    return text
end
local function section(src,first,last)
    local a=assert(src:find(first,1,true),"Missing "..first)
    local b=assert(src:find(last,a+#first,true),"Missing "..last)
    return src:sub(a,b-1)
end
local recognition=read("src/PlayingGame/PlayerBoard/CardRecognition.lua")
local assignments=read("src/PlayingGame/AttackAssignments.lua")
local footprint=section(recognition,"trackerPrivate.zoneFootprintContainsXZ=function(obj,zone)",
    "local function scheduleChoiceResetAfterPlay(guid,seatPos)")
local enemies=section(recognition,"local combatTrackedSeat=nil",
    "local function combatPlayMonsters()")
local prune=section(assignments,"function attackAssignmentsPruneTargets(eligible)",
    "function attackAssignmentsIsTargeting(sourceGUID)")

local position={x=0,y=2,z=0}
local enemy={guid="808631",held_by_color=nil,resting=true,
    is_face_down=false,isSmoothMoving=function() return false end,
    isDestroyed=function() return false end,
    getPosition=function() return position end}
local function zone(x,depth)
    return {getObjects=function() return {} end,
        getBounds=function() return {center={x=x,z=0},size={x=0,z=0}} end,
        getPosition=function() return {x=x,z=0} end,
        getScale=function() return {x=12,z=depth or 10} end,
        getRotation=function() return {y=0} end}
end
local play=zone(0)
local unit=zone(24)
local registry={one={sourceGUID="rage",targetGUID=enemy.guid,kind="armour"}}
local saved=0
local trackerPrivate={}
local env={
    trackerPrivate=trackerPrivate,
    playerPlayAreas={[1]="play"},playerUnitAreas={[1]="unit"},
    assignmentRegistry=registry,
    getObjectFromGUID=function(guid)
        if guid=="play" then return play end
        if guid=="unit" then return unit end
        if guid==enemy.guid then return enemy end
        return nil
    end,
    combatCommittedSource=function() return false end,
    persistAssignments=function() saved=saved+1 end,
    refreshRenderedLines=function() end
}
setmetatable(env,{__index=_G})
local keep=assert(load(footprint.."\n"..enemies..
    "\nreturn combatKeepHeldEnemies","Enemy transit recovery","t",env))()
assert(load(prune,"Prune dropped enemy targets","t",env))()
local function pruneFor(monsters)
    local eligible={}
    for guid,obj in pairs(monsters) do
        if obj.is_face_down~=true then eligible[guid]=true end
    end
    env.attackAssignmentsPruneTargets(eligible)
end

-- First the enemy has actually been observed in the play zone.
local monsters={[enemy.guid]=enemy}
local playMonsters={[enemy.guid]=enemy}
keep(1,monsters,playMonsters)
-- A lifted enemy temporarily leaves the thin zone, but its target remains.
enemy.held_by_color="White"
position.x,position.y=17,8
monsters,playMonsters={},{}
keep(1,monsters,playMonsters)
assert(monsters[enemy.guid]==enemy,
    "A held enemy must not disappear while it is being relocated")
pruneFor(monsters)
assert(registry.one~=nil,"Holding a target cannot prune its saved arrow")

-- TTS can report resting=true and held=nil on Drop BEFORE getObjects() finds
-- the token. The old code discarded it here and retargeted to a farther enemy.
enemy.held_by_color=nil
enemy.resting=true
position.x,position.y=4,8
monsters,playMonsters={},{}
keep(1,monsters,playMonsters)
assert(monsters[enemy.guid]==enemy and playMonsters[enemy.guid]==enemy,
    "Released enemy above shallow play zone must remain an active target")
pruneFor(monsters)
assert(registry.one~=nil and saved==0,
    "A valid saved arrow must survive the first post-drop calculator pass")

-- Crossing into the Unit Area is still combat, even if both zone lists lag.
position.x,position.y=24,8
monsters,playMonsters={},{}
keep(1,monsters,playMonsters)
assert(monsters[enemy.guid]==enemy and playMonsters[enemy.guid]==nil,
    "Unit-area enemy must survive the drop without becoming a play-only target")
pruneFor(monsters)
assert(registry.one~=nil,"Repositioning within combat must retain the arrow")

-- A real departure clears the target after release, rather than holding
-- enemies indefinitely at a former combat position.
position.x,position.y=50,2
monsters,playMonsters={},{}
keep(1,monsters,playMonsters)
assert(monsters[enemy.guid]==nil,"Enemy really outside combat must be removed")
pruneFor(monsters)
assert(registry.one==nil and saved==1,
    "Moving the enemy out of combat must retire its obsolete arrow")

-- Only previously observed enemies may use above-zone recovery.
position.x=0
monsters,playMonsters={},{}
keep(1,monsters,playMonsters)
assert(monsters[enemy.guid]==nil,
    "Do not invent a new combat enemy from physical proximity alone")
print("Enemy dropped-target retention and actual departure regressions passed")
