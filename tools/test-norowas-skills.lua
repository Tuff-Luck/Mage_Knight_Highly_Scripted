-- Regression checks for Norowas' Weather skills, Bonds of Loyalty and site Unit limits.
-- Run from the repository root: lua5.2 tools/test-norowas-skills.lua
local function eq(actual,expected,label)
    if actual~=expected then
        error((label or "Mismatch")..": expected "..tostring(expected)..
            ", got "..tostring(actual),2)
    end
end

local function source(path)
    local file=assert(io.open(path,"r"))
    local data=file:read("*a")
    file:close()
    return data
end

local function section(text,first,last,returns)
    local a=assert(text:find(first,1,true),first.." not found")
    local b=assert(text:find(last,a+#first,true),last.." not found")
    return assert(load(text:sub(a,b-1).."\nreturn "..returns))()
end

local data=source("src/Data.lua")
local recognition=source("src/PlayingGame/PlayerBoard/CardRecognition.lua")
eq(data:find('["e45fdf"]={untracked=true}',1,true)~=nil,true,
    "Whisper in the Treetops has explicit blue/untracked tracker definition")
eq(data:find('attackPhaseFallback=true',1,true)~=nil,true,
    "Leadership has an Attack phase conversion option")
eq(recognition:find('replacement="attack"..field:sub',1,true)~=nil,true,
    "Leadership converts printed Siege/Ranged into ordinary Attack")

-- Check Leadership's production phase-selection logic on elemental attacks.
-- A Unit already supplying normal Attack keeps it; a Siege/Ranged-only
-- Unit changes category only if the +2 regular-Attack choice was selected.
local leadershipStart=assert(recognition:find(
    "local field=resourceFieldForFamily(record.resources,family)\n                        local replacement=nil",
    1,true))
local leadershipEnd=assert(recognition:find(
    "                        if field~=nil then",leadershipStart,true))
resourceFieldForFamily=function(resources,family)
    local found=nil
    for key,value in pairs(resources) do
        if type(value)=="number" and value>0
            and (key==family or key:sub(1,#family)==family) then
            if found~=nil then return nil end
            found=key
        end
    end
    return found
end
local leadershipChoice=assert(load("return function(record,family,rule)\n"..
    recognition:sub(leadershipStart,leadershipEnd-1)..
    "\nreturn field,replacement end"))()
local field,replacement=leadershipChoice({resources={siegeFire=3}},
    "attack",{attackPhaseFallback=true})
eq(field,"siegeFire","Leadership accepts printed Siege Attack")
eq(replacement,"attackFire","Leadership changes element-preserving Siege phase")
field,replacement=leadershipChoice({resources={ranged=4}},
    "attack",{attackPhaseFallback=true})
eq(field,"ranged","Leadership accepts printed Ranged Attack")
eq(replacement,"attack","Leadership converts to ordinary Attack")
field,replacement=leadershipChoice({resources={attack=2}},
    "attack",{attackPhaseFallback=true})
eq(field,"attack","Leadership retains already ordinary Attack")
eq(replacement,nil,"Ordinary Attack does not need replacement")
field,replacement=leadershipChoice({resources={siege=3}},
    "ranged",{attackPhaseFallback=true})
eq(field,"siege","Ranged/Siege-phase choice boosts Siege-only Units")
eq(replacement,nil,"Ranged/Siege choice does not convert Siege into Attack")

-- Execute the production terrain-effect functions, not a reimplementation.
skillResourceDefinitions={
    ["55e5e5"]={weatherTerrain={owner=-2,recipient=-1}},
    ["676856"]={weatherTerrain={owner=-2,others=1}}
}
resourceCardsPanelOpen=function() return true end
gStates={turnNumber=1,currentRound=9,doingTheRounds={},
    moveCost={plains=2,forest=5,city=2,lake=999,explore=2},
    coopCompSkillActivation={}}
turnOrder={{seatPos=1,avatarLocation="plains"},{seatPos=2,avatarLocation="plains"}}
resourceCardScanBySeat={}
local weatherEffects=section(recognition,"local passableTerrain=",
    "local function clearHighlight(guid)","resourceCardsWeatherTerrainEffects")
local function terrainFor(player)
    gStates.turnNumber=player
    resourceCardScanBySeat[turnOrder[player].seatPos]={
        terrainModifiers=weatherEffects(turnOrder[player].seatPos)}
end

gStates.coopCompSkillActivation["55e5e5"]={player=1,round=9}
terrainFor(1)
eq(resourceCardsEffectiveTerrainCost("forest"),3,"Calming owner: -2 Forest")
eq(resourceCardsEffectiveTerrainCost("plains"),1,"Calming minimum 1")
eq(resourceCardsEffectiveTerrainCost("city"),1,"Calming affects City entry")
eq(resourceCardsEffectiveTerrainCost("lake"),999,"Calming cannot cross Lake")
eq(resourceCardsEffectiveTerrainCost("explore"),2,"Explore cost unaffected")
gStates.doingTheRounds["55e5e5"]=1
terrainFor(2)
eq(resourceCardsEffectiveTerrainCost("forest"),5,
    "Calming does not give the recipient -1 without accepting it")
gStates.coopCompSkillActivation["55e5e5"]=nil
gStates.weatherBenefitThisTurn={player=2,round=9}
terrainFor(2)
eq(resourceCardsEffectiveTerrainCost("forest"),4,
    "Claimed Calming benefit lasts the recipient's turn")
gStates.weatherBenefitThisTurn=nil

gStates.doingTheRounds={}
gStates.coopCompSkillActivation["676856"]={player=1,round=9}
terrainFor(1)
eq(resourceCardsEffectiveTerrainCost("forest"),3,"Prayer owner: -2")
terrainFor(2)
eq(resourceCardsEffectiveTerrainCost("plains"),3,"Prayer opponent: +1")
eq(resourceCardsEffectiveTerrainCost("forest"),5,"Prayer opponent: maximum 5")
eq(resourceCardsEffectiveTerrainCost("city"),3,"Prayer affects City entry")
eq(resourceCardsEffectiveTerrainCost("lake"),999,"Prayer cannot open Lake")

-- Load the production site admission and damage Unit filtering functions.
gStates={turnNumber=1,currentRound=9,monsterPerks={enemy={noUnits=true}}}
turnOrder={{seatPos=1,avatarLocation="dungeon"}}
gameCards={
    bond={armour=3,level=2,name={"Bonds Unit"}},
    other={armour=2,level=1,name={"Ordinary Unit"}}
}
resourceCardScanBySeat={[1]={unitState={
    units={{guid="bond",unwounded=true},{guid="other",unwounded=true}},
    bondsUnitGUID="bond",nativeCommandCount=3}}}
combatPlayMonsters=function()
    return {enemy={guid="enemy",is_face_down=false}}
end
combatConfig={}
local damageUnits=section(recognition,"combatConfig.COMBAT_UNIT_RESIST_KEYS=",
    "-- Cold Fire only counts as resisted","combatDamageUnits")
local function available()
    local units,native=damageUnits(1)
    eq(native,3,"Native Command count excludes Bonds")
    return units
end
local units=available()
eq(units.bond~=nil,true,"Dungeon Bonds Unit exempt from no-Units rule")
eq(units.other,nil,"Dungeon other Unit cannot receive damage")
turnOrder[1].avatarLocation="tomb"
units=available()
eq(units.bond~=nil,true,"Tomb Bonds Unit exemption")
turnOrder[1].avatarLocation="monastery"
units=available()
eq(units.other,nil,"Burning Monastery blocks ordinary Units")
gStates.monsterPerks.enemy={oneUnit=true}
turnOrder[1].avatarLocation="maze"
units=available()
eq(units.bond~=nil and units.other~=nil,true,
    "Before Maze companion choice, either Unit may be selected")
eq(resourceCardsCombatSelectOneUnit("other"),true,
    "Maze accepts one explicit companion choice")
units=available()
eq(units.bond,nil,"Maze does not grant a second Bonds companion")
eq(units.other~=nil,true,"Maze selected companion may receive damage")
resourceCardsCombatClearOneUnit(1)
gStates.monsterPerks.enemy={noUnits=true}
turnOrder[1].avatarLocation="ziggurat"
units=available()
eq(next(units),nil,"Ziggurat cannot use even the Bonds companion")

-- The physical Bonds slot, not the Unit's title or recruitment origin,
-- determines the exceptional Unit.
GUID={skill={bondsOfLoyalty="bondCommand"}}
local unit={guid="bond",getBounds=function()
    return {size={x=2,z=3},center={x=5,z=1}} end}
local command={guid="nativeCommand",isCommand=true,
    getGMNotes=function() return "Command Token" end,
    getPosition=function() return {x=1,z=1} end}
local bonds={guid="bondCommand",isCommand=true,
    getGMNotes=function() return "Bonds of Loyalty" end,
    getPosition=function() return {x=5,z=1} end}
local unitInBondsSlot=true
unitLayoutSnapshot=function()
    return {objects={command,bonds,unit},commands={command,bonds},
        units={unit},unitBySlot=unitInBondsSlot and {[2]=unit} or {}}
end
unitLayoutIsCommand=function(obj) return obj.isCommand==true end
unitLayoutIsWound=function() return false end
local layout=source("src/PlayingGame/PlayerBoard/UnitLayout.lua")
section(layout,"function unitLayoutResourceState(seatPos)",
    "function unitLayoutFirstFreeCommand(seatPos)","unitLayoutResourceState")
eq(unitLayoutResourceState(1).bondsUnitGUID,"bond",
    "Unit assigned to Bonds Command slot is identified physically")
unitInBondsSlot=false
eq(unitLayoutResourceState(1).bondsUnitGUID,nil,
    "Vacated Bonds Command slot confers no exemption")

print("Norowas skill regression tests passed")
