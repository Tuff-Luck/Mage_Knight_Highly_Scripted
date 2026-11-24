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
local clearedDestroyedAssignments={}
attackAssignmentsClearForObject=function(guid)
    assert(type(guid)=="string","Destroyed assignment cleanup must receive a GUID, not expired userdata")
    clearedDestroyedAssignments[#clearedDestroyedAssignments+1]=guid
end
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
local permanentAnchors={map={guid="map"},["519f96"]={guid="519f96"},turn={guid="turn"}}
getObjectFromGUID=function(guid) return permanentAnchors[guid] end
local teardownStops=0
Wait={stopAll=function() teardownStops=teardownStops+1 end}
local deferredDestroyWork={}
safeWaitFrames=function(_,callback)
    deferredDestroyWork[#deferredDestroyWork+1]=callback
end
log=function() end
dofile("src/PlayingGame/Events.lua")
local expired={
    guid="expired",
    getName=function() error("destroyed TTS userdata") end,
    getGMNotes=function() error("destroyed TTS userdata") end
}
-- Loading can race the first destruction callback: the card catalog is optional.
gameCards=nil
gStates.volkarePursuitShields[expired.guid]=true
local destroyedOK,destroyedError=pcall(__onObjectDestroy_raw,expired)
assert(destroyedOK,"Destroyed-object cleanup failed: "..tostring(destroyedError))
equal(gStates.volkarePursuitShields[expired.guid],nil,"Expired Pursuit shield registration was not cleared")

-- Destruction may also arrive on a brand-new table or after onLoad failed before
-- restoring the saved Skill registry. Cleanup must not index the missing table.
local initializedState=gStates
gStates={}
local startupOK,startupError=pcall(__onObjectDestroy_raw,{
    guid="startup",getName=function() return "" end,getGMNotes=function() return "" end
})
assert(startupOK,"Destroy during incomplete load failed: "..tostring(startupError))
gStates=initializedState

-- Known destroyed Units still retire their activation/Ready history by GUID,
-- without requiring any methods on an already-expired object.
local retiredUnit
gameCards={spent_unit={cardType="Regular Unit"}}
resourceUnitsRetireUnit=function(guid) retiredUnit=guid end
local spentUnit={
    guid="spent_unit",
    getName=function() error("destroyed TTS userdata") end,
    getGMNotes=function() error("destroyed TTS userdata") end
}
local unitOK,unitError=pcall(__onObjectDestroy_raw,spentUnit)
assert(unitOK,"Destroyed Unit cleanup failed: "..tostring(unitError))
equal(retiredUnit,"spent_unit","Destroyed Unit activation history was not retired")

-- Target UI must not re-scan the scene until after the native destruction callback.
equal(#clearedDestroyedAssignments,0,"Destroy event refreshed combat UI before TTS finished deleting objects")
for _,callback in ipairs(deferredDestroyWork) do callback() end
equal(clearedDestroyedAssignments[1],"expired","Expired object's combat links were not cleared by GUID")
equal(clearedDestroyedAssignments[2],"startup","Startup object's combat links were not cleared by GUID")
equal(clearedDestroyedAssignments[3],"spent_unit","Destroyed Unit's combat links were not cleared by GUID")

-- A completely expired object may not even expose its GUID; still don't crash.
local missingGUID=setmetatable({},{
    __index=function(_,key)
        if key=="guid" then error("Unity object reference unavailable") end
    end
})
assert(pcall(__onObjectDestroy_raw,missingGUID),"Unreadable GUID caused a destruction crash")

-- Failed native marker classification should not interrupt other destruction bookkeeping.
mapTokenNeedsArrangement=function() error("Unity object reference unavailable") end
assert(pcall(__onObjectDestroy_raw,{guid="bad_marker",getName=function() return "" end,
    getGMNotes=function() return "" end}),"Destroyed marker classification aborted cleanup")
mapTokenNeedsArrangement=function() return false end

-- Zone exits must ignore expired native userdata without suppressing real setup events.
local zoneLeaveRefreshes=0
playerZoneLookup={test_zone={kind="play"}}
refreshHigherLevelSetupUI=function() zoneLeaveRefreshes=zoneLeaveRefreshes+1 end
gStates.mageKnightLevels=true
local liveTestZone={guid="test_zone",isDestroyed=function() return false end}
local liveTestCard={guid="live_card",type="Card",isDestroyed=function() return false end}
assert(pcall(__onObjectLeaveZone_raw,liveTestZone,liveTestCard),"Valid setup-zone departure errored")
equal(zoneLeaveRefreshes,1,"Valid zone departure was incorrectly suppressed")
local expiredTestCard=setmetatable({guid="expired_card"},{
    __index=function(_,key)
        if key=="type" then error("Object reference not set to an instance of an object") end
    end
})
assert(pcall(__onObjectLeaveZone_raw,liveTestZone,expiredTestCard),"Expired zone-exit object errored")
assert(pcall(__onObjectLeaveZone_raw,liveTestZone,
    {guid="retiring",type="Card",isDestroyed=function() return true end}),
    "Destroyed object passed through zone exit")
assert(pcall(__onObjectLeaveZone_raw,
    {guid="test_zone",isDestroyed=function() return true end},liveTestCard),
    "Destroyed scripting zone passed through zone exit")
equal(zoneLeaveRefreshes,1,"Expired/destroyed zone events reached gameplay handlers")
gStates.mageKnightLevels=nil

-- Losing only one fixture must not suppress real in-game destruction cleanup.
local previousWork=#deferredDestroyWork
permanentAnchors.map=nil
assert(pcall(__onObjectDestroy_raw,{guid="single_missing_anchor"}))
equal(teardownStops,0,"Single missing protected anchor triggered shutdown")
equal(#deferredDestroyWork,previousWork+1,"Live destruction cleanup was incorrectly skipped")

-- Once two of the three permanent fixtures are gone, stop queued work and skip teardown callbacks.
permanentAnchors["519f96"]=nil
previousWork=#deferredDestroyWork
assert(pcall(__onObjectDestroy_raw,{guid="exit_object"}))
assert(pcall(__onObjectDestroy_raw,{guid="exit_object_again"}))
equal(teardownStops,1,"Shutdown must cancel pending waits only once")
equal(#deferredDestroyWork,previousWork,"Exit destruction scheduled more cleanup")
assert(pcall(__onObjectLeaveZone_raw,liveTestZone,liveTestCard),
    "Zone exit raised after shutdown confirmation")
equal(zoneLeaveRefreshes,1,"Confirmed teardown ran normal zone gameplay logic")

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
