-- Permanent, focused regression checks for critical table-state invariants.
-- Run from the repository root: lua5.2 tools/test-core-invariants.lua
local function equal(actual,expected,message)
    if actual~=expected then error((message or "Mismatch")..": expected "..tostring(expected)..", got "..tostring(actual),2) end
end

-- City conquest scoring must only count a known, positive City level.
cityModel={red="red",blue="blue",green="green",white="white"}
volkare={terrainHex="volkare",discZone="volkareZone"}
darkCrusader={terrainHex="dark",discZone="darkZone"}
elementalist={terrainHex="elem",discZone="elemZone"}
monsterPiles=setmetatable({},{__index=function(_,key) return key end})
cityScriptZones={cityZone={cityGUID=cityModel.red}}
publishPublicUICallbacks=function() end
factionLeaderRegisterConquered=function() error("A regular City was mistaken for a faction leader") end
dofile("src/PlayingGame/City.lua")

local function cityCase(level,options)
    options=options or {}
    local defenders={extra={megapolisPair=options.pair},enemy=options.alive and "alive" or "dead"}
    gStates={
        gameScenario="Conquest",
        cityMonsterQty={[cityModel.red]=defenders},
        cityDeployOrder=level~=nil and {[cityModel.red]=1} or {},
        cityLevels=level~=nil and {level} or {},
        friendlyCity=options.friendly and {[cityModel.red]=true} or {},
        cityRevealed={}
    }
    if options.pair~=nil then
        gStates.cityMonsterQty[options.pair]=defenders
        cityScriptZones.pairZone={cityGUID=options.pair}
    else
        cityScriptZones.pairZone=nil
    end
    refreshCityDefeatState()
    return gStates.defeatedCities
end

equal(cityCase(nil).amount,0,"Missing City deployment level")
equal(cityCase(0).amount,0,"Non-combat City level zero")
equal(cityCase(-1).amount,0,"Invalid negative City level")
equal(cityCase(3).amount,1,"Defeated City with a valid level")
equal(cityCase(3,{alive=true}).amount,0,"City with surviving garrison")
equal(cityCase(3,{friendly=true}).amount,0,"Friendly City")
local paired=cityCase(3,{pair=cityModel.blue})
equal(paired.amount,1,"Megapolis counted twice")
equal(paired[cityModel.blue],true,"Megapolis paired City defeat flag")

-- A destroyed LuaGameObjectScript may still supply a GUID but throw for methods.
mapArea="map"
turnOrderArea="turn"
dummyBoard="dummy"
GUID={bag={spareDice="spare"},zone={}}
tacticCard={}
tacticZones={}
playerBoard={}
colorBand={}
playerPlayAreas={}
playerUnitAreas={}
playerCrystalAreas={}
deedDeckZones={}
deedDeckDiscardZones={}
handZones={}
gStates={firstStarted=false,mageSkills={},puppetMasterPuppets={},monsterPerks={},volkarePursuitShields={}}
turnOrder={}
attackAssignmentsClearForObject=function() end
runtimeMapContainsGUID=function() return false end
mapTokenNeedsArrangement=function() return false end
apocalypseQuestScoreMarkerPlayerIndex=function() return nil end
volkarePursuitShieldRegistered=function(obj)
    return obj.getGMNotes()=="Volkare Pursuit"
end
puppetMasterPickup={}
puppetMasterUndoFreshClaim=function() return true end
avatarButtonXmlState={}
isShieldObject=function() return false end
scriptObjectId=function(obj) return obj.getName() end
getObjectFromGUID=function() return nil end
safeWaitFrames=function() end
log=function() end
dofile("src/PlayingGame/Events.lua")
local expired={
    guid="expired",
    getName=function() error("destroyed TTS userdata") end,
    getGMNotes=function() error("destroyed TTS userdata") end
}
gStates.volkarePursuitShields[expired.guid]=true
assert(pcall(__onObjectDestroy_raw,expired),"Destroyed-object cleanup accessed expired methods")
equal(gStates.volkarePursuitShields[expired.guid],nil,"Expired Pursuit shield registration was not cleared")

-- Event loops waiting for physics must terminate or take their bounded fallback.
local pending
safeWaitCondition=function(_,onSuccess,isReady,timeout,onTimeout)
    pending={success=onSuccess,ready=isReady,timeout=timeout,fail=onTimeout}
end
local moving={guid="moving",resting=false,isSmoothMoving=function() return true end}
getObjectFromGUID=function(guid) return guid=="moving" and moving or nil end
dofile("src/PlayingGame/MapTokens.lua")
local called=0
mapTokenAfterArrivalComplete("moving",function() called=called+1 end)
equal(pending.timeout,15,"Map arrival settle timeout")
assert(type(pending.fail)=="function","Map arrival has no timeout callback")
pending.fail()
equal(called,0,"Map callback ran while token was still travelling")
moving.isSmoothMoving=function() return false end
pending.fail()
equal(called,1,"Stationary map token was not released by timeout")
pending.success()
equal(called,1,"Map completion callback ran twice")
-- Vampiric Armor is added only after Damage; Unit Poison Wounds count once,
-- Hero Poison discard Wounds do not count, and Arcane traits are respected.
dofile("src/PlayingGame/PlayerBoard/CombatEffects.lua")
equal(combatVampiricArmourGain(nil),0,"Vampiric no-damage state")
equal(combatVampiricArmourGain({
    heroWounds=2,discard=2,units={
        {wounded=true,wounds=2,unit={}},
        {wounded=false,unit={}},
        {wounded=true,unit={arcaneImmunity=true}},
        {wounded=false,unit={arcaneVulnerability=true}}
    }
}),4,"Vampiric counts hero hand Wounds and affected Units once")
equal(combatVampiricArmourGain({
    heroWounds=0,units={{wounded=true,unit={}}}
}),1,"Vampiric Unit wound")

print("Core runtime invariants passed")
