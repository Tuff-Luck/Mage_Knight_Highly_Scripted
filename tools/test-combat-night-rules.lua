-- Regression for combat Night rules from Dungeon/Tomb and marked enemy tokens.
-- Run from repo root: lua5.2 tools/test-combat-night-rules.lua
local file=assert(io.open("src/PlayingGame/PlayerBoard/CardRecognition.lua","r"))
local source=file:read("*a")
file:close()

local first=assert(source:find("-- A NightRules token represents",1,true))
local last=assert(source:find("\n-- These are separate permissions.",first,true))
local implementation=source:sub(first,last-1)
    .."\nreturn resourceCardsUsesDayMana, resourceCardsCombatNightFromEnemies"

local enemy={guid="nightMonster",is_face_down=false,
    getDecals=function() return {} end,
    isDestroyed=function() return false end}
local enemies={}
local scans=0
local env={
    gStates={dayRound=true,turnNumber=1,monsterPerks={}},
    turnOrder={{seatPos=1,avatarLocation="plains"}},
    trackerPrivate={},
    playerPlayAreas={"playZone"},
    playerUnitAreas={"unitZone"},
    getObjectFromGUID=function() return nil end,
    combatPlayMonsters=function()
        scans=scans+1
        return enemies
    end,
    combatConfig={amuletMana={gold=false,black=false}},
}
setmetatable(env,{__index=_G})
local dayMana,markedNight=assert(load(implementation,"Night combat rule check","t",env))()
env.resourceCardsUsesDayMana=dayMana

local manaStart=assert(source:find("function resourceCardsGoldAllowed()",1,true))
local manaFinish=assert(source:find("\nlocal function matchesCardMana(",manaStart,true))
local manaCode=source:sub(manaStart,manaFinish-1)
    .."\nreturn resourceCardsGoldAllowed, resourceCardsBlackAllowed"
local goldAllowed,blackAllowed=assert(load(manaCode,"Combat mana permissions","t",env))()

local skillStart=assert(source:find("local function skillUsesDayStrength()",1,true))
local skillFinish=assert(source:find("\n-- Puppet Master tokens",skillStart,true))
local skillStrength=assert(load(source:sub(skillStart,skillFinish-1)
    .."\nreturn skillUsesDayStrength","Night skill strength","t",env))()
env.skillResourceDefinitions={nightSkill={day={attack=2},night={block=3}}}
local calculateSkill=assert(loadfile("src/PlayingGame/PlayerBoard/ResourceTracker/SkillEffects.lua","t",env))()({
    skillChoicesForCurrentTurn=function(rule) return rule.choices end,
    chosenEffect=function(guid,powered,choices) return nil end,
    skillUsesDayStrength=skillStrength,
    effectHasTrackedResource=function(effects) return effects~=nil end
})

local function verify(expectedDay,label)
    assert(dayMana()==expectedDay,label..": day/night check")
    assert(skillStrength()==expectedDay,label..": day/night Skill strength")
    local resources=calculateSkill({guid="nightSkill"},nil,nil,{}).resources
    assert(resources~=nil and (expectedDay and resources.attack==2 or not expectedDay and resources.block==3),
        label..": actual Skill resource must follow combat Night rules")
    assert(goldAllowed()==expectedDay,label..": Gold legality")
    assert(blackAllowed()~=expectedDay,label..": Black legality")
end

verify(true,"Day combat with no marked enemies")
enemies.nightMonster=enemy
env.gStates.monsterPerks.nightMonster={nightRules=true}
verify(false,"Day combat against NightRules perk")
assert(markedNight(enemies)==true)
-- A saved token may have the physical decal without the metadata entry.
env.gStates.monsterPerks.nightMonster=nil
enemy.getDecals=function() return {{name="NightRules"}} end
verify(false,"Day combat against a NightRules decal")
enemy.getDecals=function() return {{name="Unrelated"}} end
verify(true,"Unrelated decal does not make combat Night")
enemy.is_face_down=true
env.gStates.monsterPerks.nightMonster={nightRules=true}
verify(true,"Face-down defeated NightRules enemy does not count")
enemy.is_face_down=false
-- Older saves may have erroneously marked an un-decaled summoned monster
-- as nightRules. Only the physical decal establishes Night for that summon.
env.gStates.summonStates={nightMonster="summoned"}
enemy.getDecals=function() return {} end
verify(true,"Legacy summoned monster with stale perk is not Night")
enemy.getDecals=function() return {{name="NightRules"}} end
verify(false,"Actually Night-marked summoned monster still counts")
env.gStates.summonStates=nil
enemies={}
verify(true,"Removing last marked enemy restores Day")
env.turnOrder[1].avatarLocation="dungeon"
verify(false,"Dungeon always uses Night")
env.turnOrder[1].avatarLocation="tomb"
verify(false,"Tomb always uses Night")
env.turnOrder[1].avatarLocation="plains"
env.gStates.dayRound=false
verify(false,"Night round regardless of markers")

-- During a render, the combat zones have already been scanned: use its
-- single snapshot instead of repeatedly querying zones for mana and Skills.
env.gStates.dayRound=true
env.trackerPrivate.renderCombatNight=true
local before=scans
verify(false,"Cached combat Night context")
assert(scans==before,"Render must not rescan enemies for every lookup")
env.trackerPrivate.renderCombatNight=false
verify(true,"Cached combat Day context")
assert(scans==before)
env.trackerPrivate.renderCombatNight=nil

-- One with the Land's powered Fire/Ice Block must use the same combat
-- Night context; physical terrain movement costs must retain actual Day/Night.
local cardFile=assert(io.open("src/PlayingGame/PlayerBoard/ResourceTracker/CardEffects.lua","r"))
local cardSource=cardFile:read("*a")
cardFile:close()
assert(cardSource:find("chosen=resourceCardsUsesDayMana() and {blockFire=value} or {blockIce=value}",1,true),
    "One with the Land must follow NightRules enemy combat")
local movementFile=assert(io.open("src/PlayingGame/PlayerBoard/ResourceTracker/MovementEffects.lua","r"))
local movementSource=movementFile:read("*a")
movementFile:close()
assert(movementSource:find("return effect.dayRound==nil or effect.dayRound==(gStates.dayRound==true)",1,true),
    "Terrain movement must use actual Day/Night, not the combat Night context")
local observationFile=assert(io.open("src/PlayingGame/PlayerBoard/ResourceTracker/ScanObservation.lua","r"))
local observationSource=observationFile:read("*a")
observationFile:close()
assert(observationSource:find("trackerPrivate.renderCombatNight=resourceCardsCombatNightFromEnemies(combatMonsters)",1,true),
    "Active combat must build one shared Night snapshot")
local publicationFile=assert(io.open("src/PlayingGame/PlayerBoard/ResourceTracker/ScanPublication.lua","r"))
local publicationSource=publicationFile:read("*a")
publicationFile:close()
assert(publicationSource:find("trackerPrivate.renderCombatNight=nil\n    if trackerPrivate.traceEnabled then trackerPrivate.traceEvent(\"render.done\",seatPos) end\nend",1,true),
    "Night context must be cleared after rendering")

-- A normal Summoner must not accidentally mark every summon as Night.
-- Test the same conditional block that adds the visible NightRules decal.
local combatFile=assert(io.open("src/PlayingGame/Combat.lua","r"))
local combatSource=combatFile:read("*a")
combatFile:close()
local spawnStart=assert(combatSource:find(
    "local summonedNightRules=id==darkCrusader.token",1,true))
local spawnFinish=assert(combatSource:find(
    "\n\t\t\t\tgStates.summonStates[summonedMonster.guid]",spawnStart,true))
local spawnCode=combatSource:sub(spawnStart,spawnFinish-1)
assert(combatSource:find("if resourceCardsSourceChanged~=nil then resourceCardsSourceChanged() end",1,true),
    "Delayed NightRules decals must trigger a fresh tracker scan")
local function testSummon(summonerGUID,faction,place,expected)
    local decals={}
    local states={turnNumber=1,monsterPerks={}}
    local e={
        id=summonerGUID,darkCrusader={token="darkLeader"},
        summonerFaction=faction,turnOrder={{avatarLocation=place}},
        gStates=states,nightRulesDecal="test-night-icon",
        summonedMonster={guid="summon",addDecal=function(decal) decals[#decals+1]=decal end}
    }
    setmetatable(e,{__index=_G})
    assert(load(spawnCode,"Summon NightRules","t",e))()
    assert((#decals>0)==expected,"Summon Night decal mismatch")
    assert((states.monsterPerks.summon~=nil and states.monsterPerks.summon.nightRules==true)==expected,
        "Summon Night perk must agree with its decal")
end
testSummon("ordinary","Other","plains",false)
testSummon("darkLeader","Other","plains",true)
testSummon("ordinary","Dark","graveyard",true)
print("Combat NightRules regression passed")
